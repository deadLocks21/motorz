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
  Future<void> requestOtp(String rawPhone) async {
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
      state = OtpRequested(phone: phone, expiresAt: expiresAt);
      logger.info('auth.otp.requested');
    } on AuthException catch (e) {
      logger.warn('auth.otp.request_failed', attrs: {'auth.code': e.code.name});
      rethrow;
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
    unawaited(sync.syncNow());
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
  // Mode démo (local-only) : garnit le garage d'un véhicule d'exemple au
  // premier lancement (idempotent), pour ne pas s'ouvrir sur un écran vide.
  if (isMemoryMode(ref.read(apiBaseUrlProvider))) {
    await DemoSeed(ref.read(localRecordStoreProvider)).ensureSeeded();
  }
  await ref.read(sessionControllerProvider.notifier).restore();
  final sync = ref.read(syncServiceProvider);
  sync.start();
  final authenticated = ref.read(currentSessionProvider) != null;
  if (authenticated) {
    unawaited(sync.syncNow());
  }
  ref.read(loggerProvider).info('app.bootstrap.completed', attrs: {'authenticated': authenticated});
}
