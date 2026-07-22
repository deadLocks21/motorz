import 'dart:async';

import 'package:motorz/core/application/session_state.dart';
import 'package:motorz/core/application/sync/sync_conflict.dart';
import 'package:motorz/core/domain/exceptions/auth_exception.dart';
import 'package:motorz/core/domain/model/phone_number.dart';
import 'package:motorz/core/domain/model/session.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/logger_providers.dart';
import 'package:motorz/infrastructure/seed/demo_seed.dart';
import 'package:motorz/infrastructure/sync/sync_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_providers.g.dart';

/// Pilote la machine d'états [SessionState] (cf. redirect go_router).
@Riverpod(keepAlive: true)
class SessionController extends _$SessionController {
  @override
  SessionState build() => const Anonymous();

  /// Demande un OTP. Lève [AuthException] en cas d'échec (dont `accountNotFound`
  /// si le numéro n'a pas de compte — l'inscription n'existe pas côté app).
  Future<void> requestOtp(String rawPhone, {OtpReason reason = OtpReason.login}) async {
    final logger = ref.read(loggerProvider);
    final PhoneNumber phone;
    try {
      phone = PhoneNumber.parse(rawPhone);
    } on FormatException {
      logger.warn('auth.otp.invalid_phone');
      throw const AuthException(AuthErrorCode.invalidPhone);
    }
    try {
      final expiresAt = await ref.read(authRepositoryProvider).requestOtp(phone);
      state = OtpRequested(phone: phone, expiresAt: expiresAt, reason: reason);
      logger.info('auth.otp.requested', attrs: {'auth.reason': reason.name});
    } on AuthException catch (e) {
      logger.warn('auth.otp.request_failed', attrs: {'auth.code': e.code.name});
      rethrow;
    }
  }

  /// Le serveur a refusé le token (401 `invalid_token`) : on lâche la session et
  /// on renvoie un SMS au numéro du compte, pour que l'utilisateur n'ait plus
  /// qu'à saisir le code.
  ///
  /// Contrairement à [logout], **aucune purge locale** : l'utilisateur n'a pas
  /// demandé à partir, ses écritures encore en file doivent survivre à
  /// l'expiration.
  ///
  /// Le passage immédiat hors de [Authenticated] fait office de garde de
  /// ré-entrance : les requêtes concurrentes qui prennent aussi un 401 retombent
  /// ici sans redéclencher d'envoi de SMS (le quota serveur est de 3 / 15 min).
  Future<void> expire() async {
    final current = state;
    if (current is! Authenticated) return;
    final logger = ref.read(loggerProvider);
    logger.warn('auth.session.expired');

    final PhoneNumber phone;
    try {
      phone = PhoneNumber.parse(current.session.user.phoneNumber);
    } on FormatException {
      // Numéro illisible : on ne peut pas pré-remplir, retour à la saisie.
      await ref.read(sessionRepositoryProvider).clear();
      state = const Anonymous();
      return;
    }

    // D'abord l'état : `currentSession` repasse à null, l'interceptor cesse
    // d'attacher le token mort aux requêtes en vol.
    state = SessionExpired(phone);
    await ref.read(sessionRepositoryProvider).clear();
    try {
      await requestOtp(phone.e164, reason: OtpReason.sessionExpired);
    } on AuthException catch (e) {
      // Renvoi impossible (quota, réseau, compte supprimé) : on reste sur
      // l'écran OTP avec l'erreur et un bouton « Réessayer ».
      if (state is SessionExpired) state = SessionExpired(phone, error: e.code);
    }
  }

  /// Relance l'envoi du SMS après un échec de [expire].
  Future<void> retryExpiredOtp() async {
    final current = state;
    if (current is! SessionExpired) return;
    state = SessionExpired(current.phone);
    try {
      await requestOtp(current.phone.e164, reason: OtpReason.sessionExpired);
    } on AuthException catch (e) {
      if (state is SessionExpired) state = SessionExpired(current.phone, error: e.code);
    }
  }

  /// Vérifie l'OTP et authentifie le compte associé. Lève [AuthException] sinon.
  Future<void> verifyOtp(String code) async {
    final current = state;
    if (current is! OtpRequested) return;
    final device = await ref.read(sessionRepositoryProvider).readOrCreateDevice();
    try {
      final session = await ref.read(authRepositoryProvider).verifyOtp(
            phone: current.phone,
            code: code,
            device: device,
          );
      await _authenticate(session, reason: current.reason);
    } on AuthException catch (e) {
      ref.read(loggerProvider).warn('auth.otp.verify_failed', attrs: {'auth.code': e.code.name});
      rethrow;
    }
  }

  Future<void> _authenticate(Session session, {required OtpReason reason}) async {
    await ref.read(sessionRepositoryProvider).write(session);
    state = Authenticated(session);
    // `state` est désormais Authenticated → le résolveur de contexte attache
    // déjà `user.id` / `device.id` à cet événement.
    ref.read(loggerProvider).info('auth.login');
    final sync = ref.read(syncServiceProvider);
    sync.start();
    if (isMemoryMode(ref.read(apiBaseUrlProvider))) {
      // Mode local-only : garnit le garage d'un véhicule d'exemple rattaché au
      // compte démo connecté (idempotent). Le store ayant été purgé à la
      // déconnexion précédente, le seed rejoue à chaque nouvelle session de démo.
      await DemoSeed(ref.read(localRecordStoreProvider), session.user.id).ensureSeeded();
    } else if (reason == OtpReason.sessionExpired) {
      await _reconnect(sync);
    } else {
      // Vrai login : le compte peut avoir changé, l'état local hérité d'une
      // session précédente n'a plus de sens. On repart de la vérité serveur.
      unawaited(sync.resetToRemote());
    }
  }

  /// Reconnexion après expiration : c'est forcément le même compte (l'OTP a été
  /// demandé sur le numéro de la session expirée), donc la file locale est
  /// légitime — on ne la jette pas comme au login.
  ///
  /// On regarde d'abord ce qui a bougé des deux côtés : sans arbitrage, pousser
  /// ferait disparaître une des deux versions en silence (last-write-wins
  /// serveur).
  Future<void> _reconnect(SyncService sync) async {
    try {
      final conflicts = await sync.detectConflicts();
      if (conflicts.isEmpty) {
        unawaited(sync.syncNow());
        return;
      }
      ref.read(pendingConflictsProvider.notifier).replace(conflicts);
    } catch (e, st) {
      // Détection impossible (réseau, serveur) : on ne bloque pas la
      // reconnexion. La file reste intacte, la synchro réessaiera.
      ref.read(loggerProvider).error('sync.conflicts.detect_failed', error: e, stack: st);
      unawaited(sync.syncNow());
    }
  }

  /// Restaure une session persistée au démarrage.
  Future<void> restore() async {
    final session = await ref.read(sessionRepositoryProvider).read();
    state = session != null ? Authenticated(session) : const Anonymous();
    if (session != null) ref.read(loggerProvider).info('session.restored');
  }

  void cancel() => state = const Anonymous();

  Future<void> logout() async {
    // Avant `clear()` pour que `user.id` soit encore attaché à l'événement.
    ref.read(loggerProvider).info('auth.logout');
    await ref.read(sessionRepositoryProvider).clear();
    // Vie privée : ne rien laisser sur l'appareil après déconnexion — on purge le
    // store local, la file en attente, la dead-letter et le curseur de synchro.
    await ref.read(syncServiceProvider).purgeLocal();
    state = const Anonymous();
  }
}

/// Session courante (ou `null` si non authentifié).
@Riverpod(keepAlive: true)
Session? currentSession(Ref ref) {
  final state = ref.watch(sessionControllerProvider);
  return state is Authenticated ? state.session : null;
}

/// Conflits en attente d'arbitrage après une reconnexion. Non vide → le router
/// dérive vers l'écran de réconciliation, qui est le seul à pouvoir les vider.
@Riverpod(keepAlive: true)
class PendingConflicts extends _$PendingConflicts {
  @override
  List<SyncConflict> build() => const [];

  void replace(List<SyncConflict> conflicts) => state = List.unmodifiable(conflicts);

  void clear() => state = const [];
}

/// Amorce l'app : charge l'URL d'API, restaure la session, démarre la synchro.
@Riverpod(keepAlive: true)
Future<void> bootstrap(Ref ref) async {
  await ref.read(apiBaseUrlProvider.notifier).load();
  // En mode démo (local-only), le garage est garni au login (cf. `_authenticate`),
  // une fois l'identité du compte connue — pas ici.
  await ref.read(sessionControllerProvider.notifier).restore();
  final sync = ref.read(syncServiceProvider);
  sync.start();
  final authenticated = ref.read(currentSessionProvider) != null;
  if (authenticated) {
    unawaited(sync.syncNow());
  }
  // `api.base_url` est la première chose à vérifier devant un échec réseau
  // généralisé (auth *et* synchro) : c'est le seul réglage capable de tout
  // casser d'un coup. Il ne peut pas être loggué à la construction du client
  // Dio — résoudre le logger depuis ce provider y bouclerait sur la session.
  ref.read(loggerProvider).info('app.bootstrap.completed', attrs: {
    'authenticated': authenticated,
    'api.base_url': ref.read(apiBaseUrlProvider),
  });
}
