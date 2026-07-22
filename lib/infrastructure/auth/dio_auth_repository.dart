import 'package:dio/dio.dart';
import 'package:motorz/core/domain/exceptions/auth_exception.dart';
import 'package:motorz/core/domain/model/device.dart';
import 'package:motorz/core/domain/model/phone_number.dart';
import 'package:motorz/core/domain/model/session.dart';
import 'package:motorz/core/domain/model/user.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/services/auth.repository.dart';
import 'package:motorz/infrastructure/http/auth_interceptor.dart';
import 'package:motorz/infrastructure/http/http_log.interceptor.dart';

class DioAuthRepository implements AuthRepository {
  final Dio _dio;
  DioAuthRepository(this._dio);

  @override
  Future<DateTime> requestOtp(PhoneNumber phone) async {
    try {
      final res = await _dio.post<dynamic>(
        '/auth/request-otp',
        data: {'phone_number': phone.e164},
      );
      return DateTime.parse(_requireJson(res)['expires_at'] as String);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<Session> verifyOtp({
    required PhoneNumber phone,
    required String code,
    required Device device,
  }) async {
    try {
      final data = <String, dynamic>{
        'phone_number': phone.e164,
        'code': code,
        'device_id': device.id,
      };
      if (device.name != null) data['device_name'] = device.name;
      final res = await _dio.post<dynamic>('/auth/verify-otp', data: data);
      return _sessionFromJson(_requireJson(res));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Corps d'une réponse **réussie**, à condition que ce soit bien du JSON.
  ///
  /// Un 2xx qui n'en est pas ne passe par aucun `catch` : un hôte qui sert une
  /// SPA en catch-all répond 200 avec du HTML, et la lecture des champs partait
  /// alors en `TypeError` — que l'écran de connexion, qui n'attrape que des
  /// [AuthException], laissait remonter en exception non gérée.
  ///
  /// C'est aussi pourquoi les appels demandent un `Response<dynamic>` et non un
  /// `Response<Map<String, dynamic>>` : sur un corps HTML, le cast de Dio échoue
  /// dans ses entrailles et ressort en `DioException(unknown)` **sans réponse
  /// attachée** — soit précisément la signature d'une panne réseau, alors que le
  /// serveur a parfaitement répondu. En prenant le corps tel quel, on garde de
  /// quoi dire la vérité.
  Map<String, dynamic> _requireJson(Response<dynamic> response) {
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const AuthException(AuthErrorCode.badServerUrl);
    }
    return data;
  }

  Session _sessionFromJson(Map<String, dynamic> json) {
    final u = json['user'] as Map<String, dynamic>;
    final d = json['device'] as Map<String, dynamic>;
    return Session(
      jwt: json['jwt'] as String,
      user: User(
        id: UuidValue.parse(u['id'] as String),
        firstName: u['first_name'] as String,
        lastName: u['last_name'] as String,
        phoneNumber: u['phone_number'] as String,
        isAdmin: (u['is_admin'] as bool?) ?? false,
      ),
      device: Device(id: d['id'] as String, name: d['name'] as String?),
    );
  }

  AuthException _mapError(DioException e) {
    // Un corps non-JSON prime sur le type d'exception, et se teste donc en
    // premier : il prouve à lui seul que le transport a fonctionné (quelqu'un a
    // répondu), mais que ce n'est pas l'API au bout de l'URL — page d'erreur
    // d'un reverse proxy, client web servi en catch-all… Dio étiquette certains
    // de ces cas `unknown`, qu'on lirait sinon comme une panne réseau.
    if (_isNotApiResponse(e.response)) {
      return const AuthException(AuthErrorCode.badServerUrl);
    }
    // Rien n'a répondu (DNS, TCP, TLS, délai dépassé, XHR bloqué) : réseau.
    // Ne couvrir que `connectionError`/`connectionTimeout` faisait passer les
    // autres pannes de transport — dont `unknown`, qui est le type d'une
    // requête web bloquée par le navigateur — pour un « Une erreur est
    // survenue » indistinct.
    if (isTransportFailure(e.type)) {
      return const AuthException(AuthErrorCode.network);
    }
    final code = readErrorCode(e.response);
    return switch (code) {
      'account_not_found' => const AuthException(AuthErrorCode.accountNotFound),
      'invalid_otp' => const AuthException(AuthErrorCode.invalidOtp),
      'otp_expired' => const AuthException(AuthErrorCode.otpExpired),
      'invalid_phone_format' => const AuthException(AuthErrorCode.invalidPhone),
      'rate_limited' => const AuthException(AuthErrorCode.rateLimited),
      'sms_failed' => const AuthException(AuthErrorCode.smsFailed),
      _ => const AuthException(AuthErrorCode.unknown),
    };
  }

  /// L'API répond toujours en JSON, erreurs comprises (`{error:{code}}`), et
  /// Dio le désérialise en `Map`. Un corps resté sous forme de `String` a donc
  /// un content-type non-JSON : HTML ou texte brut, personne d'autre que
  /// l'API. Un corps vide, lui, ne prouve rien — on ne conclut pas.
  bool _isNotApiResponse(Response<dynamic>? response) {
    final data = response?.data;
    return data is String && data.trim().isNotEmpty;
  }
}
