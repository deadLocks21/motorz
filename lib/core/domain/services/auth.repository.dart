import 'package:motorz/core/domain/model/device.dart';
import 'package:motorz/core/domain/model/phone_number.dart';
import 'package:motorz/core/domain/model/session.dart';

/// Résultat de `requestOtp` : échéance du code + si le téléphone est inconnu
/// (parcours d'inscription self-service).
class OtpRequestResult {
  final DateTime expiresAt;
  final bool isNewUser;
  const OtpRequestResult({required this.expiresAt, required this.isNewUser});
}

/// Port d'authentification OTP/SMS. Les erreurs sont signalées via
/// [AuthException].
abstract interface class AuthRepository {
  Future<OtpRequestResult> requestOtp(PhoneNumber phone);

  /// Vérifie l'OTP. Si le compte n'existe pas, `firstName`/`lastName` sont
  /// requis (sinon `AuthException(registrationRequired)`).
  Future<Session> verifyOtp({
    required PhoneNumber phone,
    required String code,
    required Device device,
    String? firstName,
    String? lastName,
  });
}
