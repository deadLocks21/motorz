import 'package:motorz/core/domain/exceptions/auth_exception.dart';
import 'package:motorz/core/domain/model/phone_number.dart';
import 'package:motorz/core/domain/model/session.dart';

/// Machine d'états de session. Pilote la navigation `go_router` (redirect).
///
/// Pas d'inscription self-service : les comptes sont provisionnés côté serveur
/// (cf. `user-create.ts`), l'app ne fait que connecter un compte existant.
///
/// Transitions :
/// - Anonymous      → OtpRequested   (requestOtp ; échoue si compte inconnu)
/// - OtpRequested   → Authenticated  (verifyOtp)
/// - Authenticated  → SessionExpired (expire, sur 401 `invalid_token`)
/// - SessionExpired → OtpRequested   (renvoi automatique du SMS)
/// - any            → Anonymous      (logout / cancel)
sealed class SessionState {
  const SessionState();
}

/// Aucun token : l'utilisateur saisit son numéro.
class Anonymous extends SessionState {
  const Anonymous();
}

/// Pourquoi un OTP a été demandé — l'écran de saisie adapte son message.
enum OtpReason { login, sessionExpired }

/// Un OTP a été demandé pour un compte existant.
class OtpRequested extends SessionState {
  final PhoneNumber phone;
  final DateTime expiresAt;
  final OtpReason reason;

  const OtpRequested({
    required this.phone,
    required this.expiresAt,
    this.reason = OtpReason.login,
  });
}

/// Le serveur a refusé le token (expiré, ou appareil révoqué). État transitoire :
/// le numéro étant connu, on redemande un SMS automatiquement sans repasser par
/// la saisie du numéro. [error] est non nul si cet envoi a échoué — l'écran OTP
/// propose alors de réessayer.
class SessionExpired extends SessionState {
  final PhoneNumber phone;
  final AuthErrorCode? error;

  const SessionExpired(this.phone, {this.error});
}

/// Session active.
class Authenticated extends SessionState {
  final Session session;

  const Authenticated(this.session);
}
