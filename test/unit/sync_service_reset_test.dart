import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/infrastructure/connectivity/connectivity_plus.service.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/infrastructure/sync/pending_queue.dart';
import 'package:motorz/infrastructure/sync/sync_api.dart';
import 'package:motorz/infrastructure/sync/sync_cursor.dart';
import 'package:motorz/infrastructure/sync/sync_service.dart';

/// SyncApi fictif : enregistre le `since` du dernier pull et renvoie un état
/// serveur figé. `push` est un no-op qui compte les appels.
class _FakeSyncApi extends SyncApi {
  _FakeSyncApi(this.serverState) : super(Dio());

  final Map<String, List<Map<String, dynamic>>> serverState;
  final List<Map<String, List<Map<String, dynamic>>>> pushed = [];
  String? lastSince;
  bool sinceWasNullOnLastPull = false;

  @override
  Future<PullResult> pull(String? since) async {
    lastSince = since;
    sinceWasNullOnLastPull = since == null;
    return PullResult(serverTime: '2026-05-27T00:00:00Z', changes: serverState);
  }

  @override
  Future<void> push(Map<String, List<Map<String, dynamic>>> changes) async {
    pushed.add(changes);
  }
}

void main() {
  late InMemoryLocalRecordStore store;
  late InMemoryPendingQueue queue;
  late InMemorySyncCursorStore cursor;
  late _FakeSyncApi api;
  late SyncService sync;

  setUp(() {
    store = InMemoryLocalRecordStore();
    queue = InMemoryPendingQueue();
    cursor = InMemorySyncCursorStore();
    api = _FakeSyncApi({
      'vehicles': [
        {'id': 'remote-1', 'updated_at': '2026-05-27T00:00:00Z'},
      ],
    });
    sync = SyncService(
      api: api,
      store: store,
      queue: queue,
      connectivity: const AlwaysOnlineConnectivityService(),
      cursor: cursor,
    );
  });

  test('resetToRemote vide store + file + curseur puis rapatrie tout (pull complet)', () async {
    // État local hérité d'une session précédente.
    await store.put('vehicles', {'id': 'stale-local', 'updated_at': '2026-01-01T00:00:00Z'});
    await queue.enqueue('vehicles', 'stale-local', {'id': 'stale-local'});
    await cursor.write('2026-01-01T00:00:00Z');

    await sync.resetToRemote();

    // Le pull est reparti de zéro (since nul → vérité serveur complète).
    expect(api.sinceWasNullOnLastPull, isTrue);
    // La file vidée n'a rien à pousser.
    expect(api.pushed, isEmpty);
    // Le store ne contient plus que l'état serveur, l'entrée locale a disparu.
    final vehicles = await store.query('vehicles');
    expect(vehicles.map((v) => v['id']), ['remote-1']);
    // Le curseur reflète le server_time du dernier pull.
    expect(await cursor.read(), '2026-05-27T00:00:00Z');
    expect(await queue.readAll(), isEmpty);
  });

  test('resetToRemote est un no-op quand la synchro est désactivée (mode local-only)', () async {
    final disabled = SyncService(
      api: api,
      store: store,
      queue: queue,
      connectivity: const AlwaysOnlineConnectivityService(),
      cursor: cursor,
      enabled: false,
    );
    await store.put('vehicles', {'id': 'demo-seed', 'updated_at': '2026-01-01T00:00:00Z'});

    await disabled.resetToRemote();

    // Le garage de démo reste intact, aucun appel réseau.
    final vehicles = await store.query('vehicles');
    expect(vehicles.map((v) => v['id']), ['demo-seed']);
    expect(api.lastSince, isNull);
    expect(api.pushed, isEmpty);
  });
}
