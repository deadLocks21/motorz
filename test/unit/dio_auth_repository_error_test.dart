import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/domain/exceptions/auth_exception.dart';
import 'package:motorz/core/domain/model/phone_number.dart';
import 'package:motorz/infrastructure/auth/dio_auth_repository.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._respond);

  final Future<ResponseBody> Function(RequestOptions options) _respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      _respond(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  DioAuthRepository repositoryThat(
    Future<ResponseBody> Function(RequestOptions) respond,
  ) {
    final dio = Dio(BaseOptions(baseUrl: 'https://motorz.dtfh.fr'))
      ..httpClientAdapter = _FakeAdapter(respond);
    return DioAuthRepository(dio);
  }

  ResponseBody json(String body, int status) => ResponseBody.fromString(
        body,
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  ResponseBody html(String body, int status) => ResponseBody.fromString(
        body,
        status,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        },
      );

  Future<AuthErrorCode> codeOf(DioAuthRepository repo) async {
    try {
      await repo.requestOtp(PhoneNumber.parse('0612345678'));
      fail('devait lever');
    } on AuthException catch (e) {
      return e.code;
    }
  }

  test('une page HTML derrière l\'URL configurée est signalée comme telle', () async {
    // Le cas réel : l'URL vise l'hôte mais pas le préfixe de l'API, la requête
    // atterrit sur le reverse proxy / le client web.
    final repo = repositoryThat(
      (_) async => html('<html><head><title>405 Not Allowed</title></head></html>', 405),
    );
    expect(await codeOf(repo), AuthErrorCode.badServerUrl);
  });

  test('un catch-all qui sert la SPA en 200 donne une erreur montrable, '
      'pas une exception non gérée', () async {
    final repo = repositoryThat((_) async => html('<!DOCTYPE html><html>', 200));
    // Un 2xx non-JSON ne passe par aucun `catch on DioException` naturel :
    // c'est la lecture des champs qui casse. L'écran de connexion n'attrape
    // que des AuthException — il faut donc que ça en soit une.
    expect(await codeOf(repo), AuthErrorCode.badServerUrl);
  });

  test('tous les échecs de transport donnent « réseau », pas « erreur inconnue »',
      () async {
    for (final type in [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.badCertificate,
      DioExceptionType.unknown,
    ]) {
      final repo = repositoryThat(
        (options) async => throw DioException(requestOptions: options, type: type),
      );
      expect(await codeOf(repo), AuthErrorCode.network, reason: type.name);
    }
  });

  test('les codes métier de l\'API restent traduits fidèlement', () async {
    final cases = {
      '{"error":{"code":"account_not_found"}}': AuthErrorCode.accountNotFound,
      '{"error":{"code":"rate_limited"}}': AuthErrorCode.rateLimited,
      '{"error":{"code":"sms_failed"}}': AuthErrorCode.smsFailed,
    };
    for (final entry in cases.entries) {
      final repo = repositoryThat((_) async => json(entry.key, 404));
      expect(await codeOf(repo), entry.value, reason: entry.key);
    }
  });

  test('une réponse d\'erreur sans corps reste « inconnue » — on ne conclut pas',
      () async {
    final repo = repositoryThat((_) async => json('', 500));
    expect(await codeOf(repo), AuthErrorCode.unknown);
  });
}
