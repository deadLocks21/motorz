import 'package:dio/dio.dart';
import 'package:motorz/core/domain/exceptions/auth_exception.dart';
import 'package:motorz/core/domain/model/device.dart';
import 'package:motorz/core/domain/model/phone_number.dart';
import 'package:motorz/core/domain/model/session.dart';
import 'package:motorz/core/domain/model/user.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/services/auth.repository.dart';
import 'package:motorz/infrastructure/http/auth_interceptor.dart';

class DioAuthRepository implements AuthRepository {
  final Dio _dio;
  DioAuthRepository(this._dio);

  @override
  Future<DateTime> requestOtp(PhoneNumber phone) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/request-otp',
        data: {'phone_number': phone.e164},
      );
      return DateTime.parse(res.data!['expires_at'] as String);
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
      final res = await _dio.post<Map<String, dynamic>>('/auth/verify-otp', data: data);
      return _sessionFromJson(res.data!);
    } on DioException catch (e) {
      throw _mapError(e);
    }
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
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
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
}
