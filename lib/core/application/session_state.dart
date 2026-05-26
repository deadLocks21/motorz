import 'package:motorz/core/domain/model/phone_number.dart';
import 'package:motorz/core/domain/model/session.dart';

/// Machine d'états de session. Pilote la navigation `go_router` (redirect).
///
/// Pas d'inscription self-service : les comptes sont provisionnés côté serveur
/// (cf. `user-create.ts`), l'app ne fait que connecter un compte existant.
///
/// Transitions :
/// - Anonymous     → OtpRequested   (requestOtp ; échoue si compte inconnu)
/// - OtpRequested  → Authenticated  (verifyOtp)
/// - any           → Anonymous      (logout / cancel)
sealed class SessionState {
  const SessionState();
}

/// Aucun token : l'utilisateur saisit son numéro.
class Anonymous extends SessionState {
  const Anonymous();
}

/// Un OTP a été demandé pour un compte existant.
class OtpRequested extends SessionState {
  final PhoneNumber phone;
  final DateTime expiresAt;

  const OtpRequested({required this.phone, required this.expiresAt});
}

/// Session active.
class Authenticated extends SessionState {
  final Session session;

  const Authenticated(this.session);
}
