import 'dart:async';

import 'package:motorz/core/application/session_state.dart';
import 'package:motorz/core/domain/exceptions/auth_exception.dart';
import 'package:motorz/core/domain/model/phone_number.dart';
import 'package:motorz/core/domain/model/session.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_providers.g.dart';

/// Pilote la machine d'états [SessionState] (cf. redirect go_router).
@Riverpod(keepAlive: true)
class SessionController extends _$SessionController {
  @override
  SessionState build() => const Anonymous();

  /// Demande un OTP. Lève [AuthException] en cas d'échec.
  Future<void> requestOtp(String rawPhone) async {
    final PhoneNumber phone;
    try {
      phone = PhoneNumber.parse(rawPhone);
    } on FormatException {
      throw const AuthException(AuthErrorCode.invalidPhone);
    }
    final result = await ref.read(authRepositoryProvider).requestOtp(phone);
    state = OtpRequested(phone: phone, expiresAt: result.expiresAt, isNewUser: result.isNewUser);
  }

  /// Vérifie l'OTP. Si le compte est inconnu, passe à [Registering]
  /// (collecte prénom/nom) ; sinon authentifie. Lève [AuthException] sinon.
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
      if (e.code == AuthErrorCode.registrationRequired) {
        state = Registering(phone: current.phone, code: code);
        return;
      }
      rethrow;
    }
  }

  /// Termine l'inscription avec prénom + nom.
  Future<void> completeRegistration(String firstName, String lastName) async {
    final current = state;
    if (current is! Registering) return;
    final device = await ref.read(sessionRepositoryProvider).readOrCreateDevice();
    final session = await ref.read(authRepositoryProvider).verifyOtp(
          phone: current.phone,
          code: current.code,
          device: device,
          firstName: firstName,
          lastName: lastName,
        );
    await _authenticate(session);
  }

  Future<void> _authenticate(Session session) async {
    await ref.read(sessionRepositoryProvider).write(session);
    state = Authenticated(session);
    final sync = ref.read(syncServiceProvider);
    sync.start();
    unawaited(sync.syncNow());
  }

  /// Restaure une session persistée au démarrage.
  Future<void> restore() async {
    final session = await ref.read(sessionRepositoryProvider).read();
    state = session != null ? Authenticated(session) : const Anonymous();
  }

  void cancel() => state = const Anonymous();

  Future<void> logout() async {
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
  await ref.read(sessionControllerProvider.notifier).restore();
  final sync = ref.read(syncServiceProvider);
  sync.start();
  if (ref.read(currentSessionProvider) != null) {
    unawaited(sync.syncNow());
  }
}
