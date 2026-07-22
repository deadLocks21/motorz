import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/services/logger_application.service.dart';
import 'package:motorz/core/domain/model/log_level.dart';
import 'package:motorz/infrastructure/http/http_log.interceptor.dart';
import 'package:motorz/infrastructure/logger/in_memory.logger.service.dart';

/// Adaptateur de transport bouchonné : la requête ne sort jamais de la machine,
/// mais toute la chaîne Dio (transformeur, interceptors, typage des erreurs)
/// s'exécute pour de vrai.
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
  late InMemoryLoggerService sink;
  late Dio dio;

  Dio makeDio(Future<ResponseBody> Function(RequestOptions) respond) {
    final d = Dio(BaseOptions(baseUrl: 'https://motorz.dtfh.fr/api'))
      ..httpClientAdapter = _FakeAdapter(respond);
    d.interceptors.add(HttpLogInterceptor(logger: LoggerApplicationService(sink)));
    return d;
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

  LoggedRecord recordNamed(String message) =>
      sink.records.singleWhere((r) => r.message == message);

  setUp(() => sink = InMemoryLoggerService());

  test('un échange réussi trace le départ et l\'arrivée avec l\'URL complète', () async {
    dio = makeDio((_) async => json('{"ok":true}', 200));

    await dio.get<Map<String, dynamic>>('/sync/changes');

    final request = recordNamed('http.request');
    expect(request.level, LogLevel.debug);
    expect(request.attributes['http.request.method'], 'GET');
    expect(request.attributes['url.full'], 'https://motorz.dtfh.fr/api/sync/changes');

    final response = recordNamed('http.response');
    expect(response.level, LogLevel.debug);
    expect(response.attributes['http.response.status_code'], 200);
    expect(response.attributes['http.duration_ms'], isA<int>());
    // Corps JSON = donnée métier : jamais recopié.
    expect(response.attributes.containsKey('http.response.body_preview'), isFalse);
  });

  test('une réponse HTML est reprise en extrait — c\'est le symptôme d\'une URL '
      'qui ne vise pas l\'API', () async {
    dio = makeDio((_) async => html(
          '<html>\n<head><title>405 Not Allowed</title></head>\n<body>…</body>\n</html>',
          405,
        ));

    await expectLater(
      dio.post<Map<String, dynamic>>('/auth/request-otp', data: {'phone_number': '+33612345678'}),
      throwsA(isA<DioException>()),
    );

    final failure = recordNamed('http.failed');
    // 4xx = refus, pas panne : `warn`, pour ne pas crier au feu sur un OTP raté.
    expect(failure.level, LogLevel.warn);
    expect(failure.attributes['http.response.status_code'], 405);
    expect(failure.attributes['http.response.content_type'], 'text/html');
    expect(failure.attributes['http.response.body_preview'], contains('405 Not Allowed'));
    expect(failure.attributes['error.type'], 'badResponse');
  });

  test('un catch-all qui sert la SPA en 200 est visible malgré son succès HTTP',
      () async {
    dio = makeDio((_) async => html('<!DOCTYPE html><html><body><flutter-view>', 200));

    await dio.get<dynamic>('/sync/changes');

    final response = recordNamed('http.response');
    expect(response.attributes['http.response.status_code'], 200);
    expect(response.attributes['http.response.body_preview'], contains('DOCTYPE html'));
  });

  test('un échec de transport est loggué en erreur, avec sa cause système', () async {
    dio = makeDio((options) async => throw DioException.connectionError(
          requestOptions: options,
          reason: 'Failed host lookup',
          error: const SocketExceptionStub(),
        ));

    await expectLater(
      dio.get<dynamic>('/sync/changes'),
      throwsA(isA<DioException>()),
    );

    final failure = recordNamed('http.failed');
    expect(failure.level, LogLevel.error);
    expect(failure.attributes['error.type'], 'connectionError');
    expect(failure.attributes['error.cause'], 'SocketExceptionStub');
    expect(failure.attributes['http.response.status_code'], isNull);
    expect(failure.error, isNotNull);
  });

  test('le corps de requête ne fuite dans aucun log (code OTP, données métier)',
      () async {
    dio = makeDio((_) async => json('{"error":{"code":"invalid_otp"}}', 401));

    await expectLater(
      dio.post<dynamic>('/auth/verify-otp', data: {'code': '424242'}),
      throwsA(isA<DioException>()),
    );

    final logged = sink.records
        .expand((r) => r.attributes.values)
        .map((v) => v.toString())
        .join(' ');
    expect(logged, isNot(contains('424242')));
  });

  test('isTransportFailure classe les types qui n\'ont jamais eu de réponse', () {
    expect(isTransportFailure(DioExceptionType.connectionError), isTrue);
    expect(isTransportFailure(DioExceptionType.connectionTimeout), isTrue);
    expect(isTransportFailure(DioExceptionType.receiveTimeout), isTrue);
    expect(isTransportFailure(DioExceptionType.badCertificate), isTrue);
    // Fourre-tout de Dio, et type d'un XMLHttpRequest bloqué sur web.
    expect(isTransportFailure(DioExceptionType.unknown), isTrue);
    expect(isTransportFailure(DioExceptionType.badResponse), isFalse);
    expect(isTransportFailure(DioExceptionType.cancel), isFalse);
  });
}

/// Tient lieu de `SocketException` sans dépendre de `dart:io` (le test doit
/// aussi passer sur une cible web).
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() => 'SocketException: Failed host lookup: motorz.dtfh.fr';
}
