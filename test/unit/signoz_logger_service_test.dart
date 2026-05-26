import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/services/logger_application.service.dart';
import 'package:motorz/core/domain/model/log_level.dart';
import 'package:motorz/infrastructure/logger/in_memory.logger.service.dart';
import 'package:motorz/infrastructure/logger/signoz.logger.service.dart';

/// Dio dont l'interceptor capture le corps des requêtes et court-circuite le
/// réseau (résout 200), ou échoue à la demande pour tester le best-effort.
Dio _fakeDio({required List<String> captured, bool fail = false}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        captured.add(options.data as String);
        if (fail) {
          handler.reject(
            DioException(requestOptions: options, error: 'boom'),
          );
        } else {
          handler.resolve(Response(requestOptions: options, statusCode: 200));
        }
      },
    ),
  );
  return dio;
}

void main() {
  group('SignozLoggerService — payload OTLP', () {
    test('encode un enregistrement dans la forme ExportLogsServiceRequest', () async {
      final captured = <String>[];
      final service = SignozLoggerService(
        endpoint: 'http://signoz.test/v1/logs',
        resourceAttributes: const {'service.name': 'motorz'},
        dio: _fakeDio(captured: captured),
      );

      await service.log(
        LogLevel.info,
        'sync.started',
        attributes: const {'vehicle.count': 3, 'manual': true},
      );
      await service.flush();

      expect(captured, hasLength(1));
      final body = jsonDecode(captured.single) as Map<String, dynamic>;

      final resourceLogs = body['resourceLogs'] as List;
      final resource = resourceLogs.single['resource'] as Map<String, dynamic>;
      expect(
        _attr(resource['attributes'] as List, 'service.name'),
        equals({'stringValue': 'motorz'}),
      );

      final scopeLogs = resourceLogs.single['scopeLogs'] as List;
      expect((scopeLogs.single['scope'] as Map)['name'], equals('motorz.app'));

      final record = (scopeLogs.single['logRecords'] as List).single
          as Map<String, dynamic>;
      expect(record['severityNumber'], equals(9));
      expect(record['severityText'], equals('INFO'));
      expect(record['body'], equals({'stringValue': 'sync.started'}));
      expect(record['timeUnixNano'], isA<String>());

      final attrs = record['attributes'] as List;
      // int et bool sont encodés dans leur slot OTLP typé.
      expect(_attr(attrs, 'vehicle.count'), equals({'intValue': '3'}));
      expect(_attr(attrs, 'manual'), equals({'boolValue': true}));

      await service.dispose();
    });

    test('attache exception.* quand error/stack sont fournis', () async {
      final captured = <String>[];
      final service = SignozLoggerService(
        endpoint: 'http://signoz.test/v1/logs',
        dio: _fakeDio(captured: captured),
      );

      await service.log(
        LogLevel.error,
        'sync.failed',
        error: const FormatException('nope'),
        stack: StackTrace.current,
      );
      await service.flush();

      final body = jsonDecode(captured.single) as Map<String, dynamic>;
      final record = ((((body['resourceLogs'] as List).single['scopeLogs']
              as List)
          .single['logRecords'] as List)
          .single) as Map<String, dynamic>;
      final attrs = record['attributes'] as List;
      expect(_attr(attrs, 'exception.type'),
          equals({'stringValue': 'FormatException'}));
      expect((_attr(attrs, 'exception.message')!['stringValue'] as String),
          contains('nope'));
      expect(_attr(attrs, 'exception.stacktrace'), isNotNull);

      await service.dispose();
    });

    test('best-effort : un échec réseau ne lève pas', () async {
      final captured = <String>[];
      final service = SignozLoggerService(
        endpoint: 'http://signoz.test/v1/logs',
        dio: _fakeDio(captured: captured, fail: true),
      );

      await service.log(LogLevel.warn, 'whatever');
      // Ne doit pas propager l'erreur réseau.
      await expectLater(service.flush(), completes);

      await service.dispose();
    });
  });

  group('LoggerApplicationService — fusion de contexte', () {
    test('priorité : dynamique < statique < site d\'appel', () async {
      final sink = InMemoryLoggerService();
      final logger = LoggerApplicationService(
        sink,
        resolveContext: () => {'k': 'dynamic', 'session.id': 's1'},
      ).withContext({'k': 'static'});

      await logger.info('evt', attrs: {'k': 'call'});

      final rec = sink.records.single;
      expect(rec.message, equals('evt'));
      expect(rec.attributes['k'], equals('call'));
      expect(rec.attributes['session.id'], equals('s1'));
    });
  });
}

/// Retourne la `value` OTLP de la clé [key] dans une liste `KeyValue[]`.
Map<String, dynamic>? _attr(List<dynamic> keyValues, String key) {
  for (final kv in keyValues.cast<Map<String, dynamic>>()) {
    if (kv['key'] == key) return kv['value'] as Map<String, dynamic>;
  }
  return null;
}
