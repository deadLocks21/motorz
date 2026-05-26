import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/session_state.dart';
import 'package:motorz/core/domain/exceptions/auth_exception.dart';
import 'package:motorz/infrastructure/connectivity/connectivity_plus.service.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/infrastructure/session/secure_storage_session_repository.dart';

void main() {
  ProviderContainer makeContainer() {
    final c = ProviderContainer(overrides: [
      connectivityServiceProvider.overrideWithValue(const AlwaysOnlineConnectivityService()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('Connexion OTP en mode memory', () {
    test('le code dev 000000 ouvre une session (câblage par défaut, sans keychain)', () async {
      // Câblage par défaut = ce qui tourne dans l'app en mode memory. Aucun
      // override : on vérifie que la session ne dépend plus de secure_storage
      // (sinon `verifyOtp` lèverait hors `AuthException` et l'écran resterait
      // bloqué sans message — le bug « je saisis 000000, je ne me connecte pas »).
      final c = makeContainer();
      expect(c.read(sessionRepositoryProvider), isA<InMemorySessionRepository>(),
          reason: 'mode memory = stockage de session en mémoire, pas de keychain natif');

      final ctrl = c.read(sessionControllerProvider.notifier);
      await ctrl.requestOtp('0612345678');
      expect(c.read(sessionControllerProvider), isA<OtpRequested>());

      await ctrl.verifyOtp('000000');
      expect(c.read(sessionControllerProvider), isA<Authenticated>(),
          reason: 'le code dev 000000 doit ouvrir une session');
    });

    test('un code erroné reste en OtpRequested et lève invalidOtp', () async {
      final c = makeContainer();
      final ctrl = c.read(sessionControllerProvider.notifier);
      await ctrl.requestOtp('0612345678');

      await expectLater(
        ctrl.verifyOtp('123456'),
        throwsA(isA<AuthException>().having((e) => e.code, 'code', AuthErrorCode.invalidOtp)),
      );
      expect(c.read(sessionControllerProvider), isA<OtpRequested>());
    });
  });
}
