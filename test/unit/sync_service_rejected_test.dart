import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/infrastructure/connectivity/connectivity_plus.service.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/infrastructure/sync/pending_queue.dart';
import 'package:motorz/infrastructure/sync/rejected_op_store.dart';
import 'package:motorz/infrastructure/sync/sync_api.dart';
import 'package:motorz/infrastructure/sync/sync_cursor.dart';
import 'package:motorz/infrastructure/sync/sync_service.dart';

/// Faux [SyncApi] : renvoie une liste de rejets fixée, et compte les pushs.
class _FakeSyncApi extends SyncApi {
  _FakeSyncApi({this.rejected = const []}) : super(Dio());

  List<RejectedRow> rejected;
  int pushCount = 0;

  @override
  Future<PushResult> push(Map<String, List<Map<String, dynamic>>> changes) async {
    pushCount++;
    return PushResult(rejected: rejected);
  }

  @override
  Future<PullResult> pull(String? since) async =>
      const PullResult(serverTime: 't', changes: {});
}

void main() {
  late InMemoryLocalRecordStore store;
  late InMemoryPendingQueue queue;
  late InMemoryRejectedOpStore rejectedStore;

  setUp(() {
    store = InMemoryLocalRecordStore();
    queue = InMemoryPendingQueue();
    rejectedStore = InMemoryRejectedOpStore();
  });

  SyncService make(_FakeSyncApi api) => SyncService(
        api: api,
        store: store,
        queue: queue,
        rejectedStore: rejectedStore,
        connectivity: const AlwaysOnlineConnectivityService(),
        cursor: InMemorySyncCursorStore(),
      );

  test('une ligne refusée sort de la file vers la dead-letter et nourrit le statut', () async {
    await queue.enqueue('vehicles', 'v1', {'id': 'v1', 'updated_at': 'x'});
    final api = _FakeSyncApi(
      rejected: const [RejectedRow(resource: 'vehicles', id: 'v1', reason: 'invalid')],
    );
    final sync = make(api);

    await sync.syncNow();

    // File drainée, rejet conservé en dead-letter (avec sa raison et ses data).
    expect(await queue.readAll(), isEmpty);
    final dead = await rejectedStore.readAll();
    expect(dead.map((o) => o.entityId), ['v1']);
    expect(dead.single.reason, 'invalid');
    expect(dead.single.data['id'], 'v1');

    // Statut : pas d'erreur réseau (push 2xx), mais un rejet à signaler.
    expect(sync.status.phase, SyncPhase.idle);
    expect(sync.status.pending, 0);
    expect(sync.status.rejected, 1);
    expect(sync.status.hasProblem, isTrue);
  });

  test('retryRejected réinjecte en file et resynchronise ; succès → dead-letter vidée', () async {
    await queue.enqueue('vehicles', 'v1', {'id': 'v1', 'updated_at': 'x'});
    final api = _FakeSyncApi(
      rejected: const [RejectedRow(resource: 'vehicles', id: 'v1', reason: 'invalid')],
    );
    final sync = make(api);
    await sync.syncNow();
    expect(sync.status.rejected, 1);

    // Le serveur n'a plus de raison de refuser (ex. bug corrigé).
    api.rejected = const [];
    await sync.retryRejected();

    expect(await rejectedStore.readAll(), isEmpty);
    expect(sync.status.rejected, 0);
    expect(sync.status.hasProblem, isFalse);
  });

  test('discardRejected vide la dead-letter sans rejouer', () async {
    await rejectedStore.addAll(const [
      RejectedOp(resource: 'vehicles', entityId: 'v1', data: {'id': 'v1'}, reason: 'forbidden'),
    ]);
    final sync = make(_FakeSyncApi());
    await sync.discardRejected();

    expect(await rejectedStore.count(), 0);
    expect(await queue.readAll(), isEmpty);
    expect(sync.status.rejected, 0);
  });

  test('une synchro mixte n\'envoie en dead-letter que les lignes refusées', () async {
    await queue.enqueue('vehicles', 'ok', {'id': 'ok', 'updated_at': 'x'});
    await queue.enqueue('fuel_entries', 'ko', {'id': 'ko', 'vehicle_id': 'ok', 'updated_at': 'x'});
    final api = _FakeSyncApi(
      rejected: const [RejectedRow(resource: 'fuel_entries', id: 'ko', reason: 'forbidden')],
    );
    final sync = make(api);

    await sync.syncNow();

    expect(await queue.readAll(), isEmpty);
    final dead = await rejectedStore.readAll();
    expect(dead.map((o) => o.entityId), ['ko']);
    expect(sync.status.rejected, 1);
  });
}
