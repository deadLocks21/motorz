import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/infrastructure/http/api_endpoint_probe.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._respond);

  final Future<ResponseBody> Function(RequestOptions options) _respond;

  /// URL sondées, dans l'ordre.
  final List<String> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls.add(options.uri.toString());
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _FakeAdapter adapter;

  ApiEndpointProbe probeThat(Future<ResponseBody> Function(RequestOptions) respond) {
    adapter = _FakeAdapter(respond);
    return ApiEndpointProbe(dio: Dio()..httpClientAdapter = adapter);
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

  test('l\'API reconnue à sa réponse de santé', () async {
    final probe = probeThat((_) async => json('{"status":"ok"}', 200));

    final resolution = await probe.resolve('https://motorz.dtfh.fr/api');

    expect(resolution.status, ApiEndpointStatus.reachable);
    expect(resolution.workingBaseUrl, 'https://motorz.dtfh.fr/api');
    expect(resolution.corrected, isFalse);
    expect(adapter.calls, ['https://motorz.dtfh.fr/api/health']);
  });

  test('un 200 en HTML ne passe pas pour l\'API — c\'est une SPA en catch-all',
      () async {
    // Le piège réel : l'hôte répond 200 à *n'importe quelle* URL. Seul le corps
    // distingue l'API du client web servi en fallback.
    final probe = probeThat((options) async =>
        options.uri.path.startsWith('/api')
            ? json('{"status":"ok"}', 200)
            : html('<!DOCTYPE html><html><body>', 200));

    final resolution = await probe.resolve('https://motorz.dtfh.fr');

    expect(resolution.status, ApiEndpointStatus.notApi);
    expect(resolution.workingBaseUrl, 'https://motorz.dtfh.fr/api');
    expect(resolution.corrected, isTrue);
    expect(adapter.calls, [
      'https://motorz.dtfh.fr/health',
      'https://motorz.dtfh.fr/api/health',
    ]);
  });

  test('un 405 de reverse proxy déclenche aussi la recherche sous /api', () async {
    final probe = probeThat((options) async => options.uri.path.startsWith('/api')
        ? json('{"status":"ok"}', 200)
        : html('<html><title>405 Not Allowed</title></html>', 405));

    final resolution = await probe.resolve('https://motorz.dtfh.fr');

    expect(resolution.workingBaseUrl, 'https://motorz.dtfh.fr/api');
  });

  test('un hôte injoignable ne déclenche pas de second essai — même échec, '
      'deuxième délai', () async {
    final probe = probeThat((options) async => throw DioException.connectionError(
          requestOptions: options,
          reason: 'Failed host lookup',
        ));

    final resolution = await probe.resolve('https://absent.example');

    expect(resolution.status, ApiEndpointStatus.unreachable);
    expect(resolution.workingBaseUrl, isNull);
    expect(adapter.calls, hasLength(1));
  });

  test('un hôte qui n\'est l\'API nulle part est abandonné', () async {
    final probe = probeThat((_) async => html('<html>rien ici</html>', 404));

    final resolution = await probe.resolve('https://example.com');

    expect(resolution.status, ApiEndpointStatus.notApi);
    expect(resolution.workingBaseUrl, isNull);
    expect(resolution.corrected, isFalse);
  });

  test('une base déjà en /api n\'essaie pas /api/api', () async {
    final probe = probeThat((_) async => html('<html>', 404));

    await probe.resolve('https://motorz.dtfh.fr/api');

    expect(adapter.calls, ['https://motorz.dtfh.fr/api/health']);
  });
}
