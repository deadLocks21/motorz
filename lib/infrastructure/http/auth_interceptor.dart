import 'package:dio/dio.dart';
import 'package:motorz/core/domain/model/session.dart';

/// Injecte `Authorization: Bearer <jwt>` + `X-Device-Id` sur chaque requête,
/// sauf `/auth/*`. La session est lue paresseusement → l'interceptor survit
/// aux connexions/déconnexions.
///
/// Signale par ailleurs à l'app tout `401 invalid_token` (JWT expiré, ou ligne
/// `devices` supprimée = session révoquée côté serveur) via [onUnauthorized],
/// pour déclencher une ré-authentification plutôt que de laisser l'utilisateur
/// avec un token mort.
class AuthInterceptor extends Interceptor {
  final Session? Function() _session;
  final void Function()? _onUnauthorized;

  AuthInterceptor({
    required Session? Function() session,
    void Function()? onUnauthorized,
  })  : _session = session,
        _onUnauthorized = onUnauthorized;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path.startsWith('/auth/')) {
      return handler.next(options);
    }
    final session = _session();
    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.jwt}';
      options.headers['X-Device-Id'] = session.device.id;
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // `/auth/*` est exclu : `verify-otp` répond aussi 401 (`invalid_otp`), et
    // c'est une erreur de saisie, pas une session morte.
    if (!err.requestOptions.path.startsWith('/auth/') &&
        err.response?.statusCode == 401 &&
        readErrorCode(err.response) == 'invalid_token') {
      _onUnauthorized?.call();
    }
    handler.next(err);
  }
}

/// Lit le code d'erreur de l'enveloppe `{ error: { code } }`.
String? readErrorCode(Response<dynamic>? response) {
  final data = response?.data;
  if (data is Map && data['error'] is Map) {
    return (data['error'] as Map)['code'] as String?;
  }
  return null;
}
