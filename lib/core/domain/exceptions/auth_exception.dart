enum AuthErrorCode {
  registrationRequired,
  invalidOtp,
  otpExpired,
  invalidPhone,
  rateLimited,
  smsFailed,
  network,
  unknown,
}

/// Erreur métier d'authentification, mappée depuis les codes HTTP de l'API.
class AuthException implements Exception {
  final AuthErrorCode code;
  const AuthException(this.code);

  @override
  String toString() => 'AuthException($code)';
}
