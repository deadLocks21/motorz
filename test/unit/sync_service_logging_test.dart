import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/services/logger_application.service.dart';
import 'package:motorz/core/domain/model/log_level.dart';
import 'package:motorz/infrastructure/connectivity/connectivity_plus.service.dart';
import 'package:motorz/infrastructure/logger/in_memory.logger.service.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/infrastructure/sync/pending_queue.dart';
import 'package:motorz/infrastructure/sync/sync_api.dart';
import 'package:motorz/infrastructure/sync/sync_cursor.dart';
import 'package:motorz/infrastructure/sync/sync_service.dart';

/// Faux [SyncApi] : court-circuite le réseau (Dio jamais utilisé).
class _FakeSyncApi extends SyncApi {
  _FakeSyncApi({this.pullResult, this.throwOnPush = false}) : super(Dio());

  final PullResult? pullResult;
  final bool throwOnPush;

  @override
  Future<void> push(Map<String, List<Map<String, dynamic>>> changes) async {
    if (throwOnPush) {
      throw DioException(requestOptions: RequestOptions(path: '/sync/push'));
    }
  }

  @override
  Future<PullResult> pull(String? since) async =>
      pullResult ?? const PullResult(serverTime: 't', changes: {});
}

void main() {
  late InMemoryLoggerService sink;
  late LoggerApplicationService logger;
  late InMemoryPendingQueue queue;
  late InMemoryLocalRecordStore store;

  setUp(() {
    sink = InMemoryLoggerService();
    logger = LoggerApplicationService(sink);
    queue = InMemoryPendingQueue();
    store = InMemoryLocalRecordStore();
  });

  SyncService make(SyncApi api) => SyncService(
        api: api,
        store: store,
        queue: queue,
        connectivity: const AlwaysOnlineConnectivityService(),
        cursor: InMemorySyncCursorStore(),
        logger: logger,
        enabled: true,
      );

  test('sync.completed loggué avec compteurs quand push & pull font du travail', () async {
    await queue.enqueue('fuel_entries', 'id-1', {'id': 'id-1', 'updated_at': 'x'});
    final api = _FakeSyncApi(
      pullResult: PullResult(serverTime: 't', changes: {
        'vehicles': [
          {'id': 'v1'},
          {'id': 'v2'},
        ],
      }),
    );

    await make(api).syncNow();

    final rec = sink.records.singleWhere((r) => r.message == 'sync.completed');
    expect(rec.level, LogLevel.info);
    expect(rec.attributes['sync.pushed'], 1);
    expect(rec.attributes['sync.pulled'], 2);
    expect(rec.attributes['sync.duration_ms'], isA<int>());
  });

  test('rien loggué quand la synchro est à vide (pas de bruit)', () async {
    await make(_FakeSyncApi()).syncNow();
    expect(sink.records.where((r) => r.message == 'sync.completed'), isEmpty);
  });

  test('sync.failed loggué quand le push échoue', () async {
    await queue.enqueue('fuel_entries', 'id-1', {'id': 'id-1'});

    await make(_FakeSyncApi(throwOnPush: true)).syncNow();

    final rec = sink.records.singleWhere((r) => r.message == 'sync.failed');
    expect(rec.level, LogLevel.error);
    expect(rec.error, isNotNull);
  });
}
