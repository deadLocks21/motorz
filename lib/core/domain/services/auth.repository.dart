import 'package:motorz/core/domain/model/device.dart';
import 'package:motorz/core/domain/model/phone_number.dart';
import 'package:motorz/core/domain/model/session.dart';

/// Port d'authentification OTP/SMS. Pas d'inscription : les comptes sont
/// provisionnés côté serveur. Les erreurs sont signalées via [AuthException]
/// (`accountNotFound` si le numéro n'a pas de compte).
abstract interface class AuthRepository {
  /// Demande un OTP pour un compte existant ; renvoie l'échéance du code.
  /// Lève `AuthException(accountNotFound)` si le numéro est inconnu.
  Future<DateTime> requestOtp(PhoneNumber phone);

  /// Vérifie l'OTP et ouvre une session pour le compte associé au numéro.
  Future<Session> verifyOtp({
    required PhoneNumber phone,
    required String code,
    required Device device,
  });
}
