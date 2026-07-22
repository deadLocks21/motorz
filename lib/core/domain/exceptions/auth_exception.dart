enum AuthErrorCode {
  accountNotFound,
  invalidOtp,
  otpExpired,
  invalidPhone,
  rateLimited,
  smsFailed,
  network,

  /// Le serveur a répondu, mais pas comme l'API : réponse non-JSON (page
  /// d'erreur, SPA servie en catch-all…). Symptôme d'une URL de backend qui
  /// vise le bon hôte au mauvais chemin — distinct de [network], où rien n'a
  /// répondu du tout, et de [unknown], qui ne dit rien à personne.
  badServerUrl,
  unknown,
}

/// Erreur métier d'authentification, mappée depuis les codes HTTP de l'API.
class AuthException implements Exception {
  final AuthErrorCode code;
  const AuthException(this.code);

  @override
  String toString() => 'AuthException($code)';
}
