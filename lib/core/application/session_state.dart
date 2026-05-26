import 'package:motorz/core/domain/model/phone_number.dart';
import 'package:motorz/core/domain/model/session.dart';

/// Machine d'états de session. Pilote la navigation `go_router` (redirect).
///
/// Transitions :
/// - Anonymous     → OtpRequested   (requestOtp)
/// - OtpRequested  → Authenticated  (verifyOtp, compte existant)
/// - OtpRequested  → Registering    (verifyOtp, compte inconnu → prénom/nom)
/// - Registering   → Authenticated  (completeRegistration)
/// - any           → Anonymous      (logout)
sealed class SessionState {
  const SessionState();
}

/// Aucun token : l'utilisateur saisit son numéro.
class Anonymous extends SessionState {
  const Anonymous();
}

/// Un OTP a été demandé. `isNewUser` indique un parcours d'inscription.
class OtpRequested extends SessionState {
  final PhoneNumber phone;
  final DateTime expiresAt;
  final bool isNewUser;

  const OtpRequested({required this.phone, required this.expiresAt, required this.isNewUser});
}

/// OTP validé mais compte à créer : on collecte prénom + nom.
class Registering extends SessionState {
  final PhoneNumber phone;
  final String code;

  const Registering({required this.phone, required this.code});
}

/// Session active.
class Authenticated extends SessionState {
  final Session session;

  const Authenticated(this.session);
}
