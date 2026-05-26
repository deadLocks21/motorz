import 'package:motorz/core/domain/exceptions/auth_exception.dart';

String authErrorMessage(AuthErrorCode code) => switch (code) {
  AuthErrorCode.invalidPhone => 'Numéro de mobile invalide (ex. 06 12 34 56 78).',
  AuthErrorCode.invalidOtp => 'Code incorrect. Réessaie.',
  AuthErrorCode.otpExpired => 'Code expiré. Demande un nouveau code.',
  AuthErrorCode.rateLimited => 'Trop de tentatives. Patiente quelques minutes.',
  AuthErrorCode.smsFailed => 'Envoi du SMS impossible. Réessaie plus tard.',
  AuthErrorCode.network => 'Pas de connexion au serveur.',
  AuthErrorCode.accountNotFound => 'Aucun compte associé à ce numéro. Contacte l\'administrateur.',
  AuthErrorCode.unknown => 'Une erreur est survenue.',
};
