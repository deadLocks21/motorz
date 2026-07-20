import 'dart:async';

import 'package:motorz/core/application/session_state.dart';
import 'package:motorz/core/domain/exceptions/auth_exception.dart';
import 'package:motorz/core/domain/model/phone_number.dart';
import 'package:motorz/core/domain/model/session.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/logger_providers.dart';
import 'package:motorz/infrastructure/seed/demo_seed.dart';
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
      await _authenticate(session);
    } on AuthException catch (e) {
      ref.read(loggerProvider).warn('auth.otp.verify_failed', attrs: {'auth.code': e.code.name});
      rethrow;
    }
  }

  Future<void> _authenticate(Session session) async {
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
    } else {
      // Au login serveur, on repart de la vérité serveur : on vide l'état local
      // (store + file + curseur) avant de tout rapatrier.
      unawaited(sync.resetToRemote());
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
  ref.read(loggerProvider).info('app.bootstrap.completed', attrs: {'authenticated': authenticated});
}
