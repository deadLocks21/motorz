import 'package:dio/dio.dart';
import 'package:motorz/core/domain/model/session.dart';

/// Injecte `Authorization: Bearer <jwt>` + `X-Device-Id` sur chaque requête,
/// sauf `/auth/*`. La session est lue paresseusement → l'interceptor survit
/// aux connexions/déconnexions.
class AuthInterceptor extends Interceptor {
  final Session? Function() _session;

  AuthInterceptor({required Session? Function() session}) : _session = session;

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
}

/// Lit le code d'erreur de l'enveloppe `{ error: { code } }`.
String? readErrorCode(Response<dynamic>? response) {
  final data = response?.data;
  if (data is Map && data['error'] is Map) {
    return (data['error'] as Map)['code'] as String?;
  }
  return null;
}
