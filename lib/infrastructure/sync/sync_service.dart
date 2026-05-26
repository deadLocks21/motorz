import 'dart:async';
import 'dart:developer' as developer;

import 'package:motorz/core/domain/services/connectivity.service.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/infrastructure/sync/pending_queue.dart';
import 'package:motorz/infrastructure/sync/sync_api.dart';
import 'package:motorz/infrastructure/sync/sync_cursor.dart';
import 'package:synchronized/synchronized.dart';

/// Service de synchro offline-first : à chaque retour en ligne (et une fois au
/// démarrage si en ligne), pousse la file (FIFO) puis tire les changements
/// delta dans le store local. Sérialisé par un [Lock].
class SyncService {
  final SyncApi _api;
  final LocalRecordStore _store;
  final PendingQueue _queue;
  final ConnectivityService _connectivity;
  final SyncCursorStore _cursor;

  /// `false` en mode local-only (pas de backend configuré) : la synchro est
  /// neutralisée, le store local reste pleinement fonctionnel.
  final bool enabled;

  StreamSubscription<bool>? _subscription;
  final Lock _lock = Lock();
  bool _disposed = false;

  SyncService({
    required SyncApi api,
    required LocalRecordStore store,
    required PendingQueue queue,
    required ConnectivityService connectivity,
    required SyncCursorStore cursor,
    this.enabled = true,
  })  : _api = api,
        _store = store,
        _queue = queue,
        _connectivity = connectivity,
        _cursor = cursor;

  void start() {
    if (!enabled || _subscription != null || _disposed) return;
    _subscription = _connectivity.watch().listen((online) {
      if (online) unawaited(syncNow());
    });
  }

  /// Push (drain de la file) puis pull (delta). Best-effort : une erreur réseau
  /// laisse la file intacte et sera réessayée au prochain passage en ligne.
  Future<void> syncNow() async {
    if (!enabled || _disposed || !_connectivity.isOnline) return;
    await _lock.synchronized(() async {
      try {
        await _push();
        await _pull();
      } catch (e, st) {
        developer.log('sync failed — will retry', name: 'motorz.sync', level: 800, error: e, stackTrace: st);
      }
    });
  }

  Future<void> _push() async {
    final ops = await _queue.readAll();
    if (ops.isEmpty) return;
    final changes = <String, List<Map<String, dynamic>>>{};
    for (final op in ops) {
      changes.putIfAbsent(op.resource, () => []).add(op.data);
    }
    await _api.push(changes); // lève → file préservée
    for (final op in ops) {
      await _queue.remove(op.resource, op.entityId);
    }
  }

  Future<void> _pull() async {
    final since = await _cursor.read();
    final result = await _api.pull(since);
    for (final entry in result.changes.entries) {
      await _store.upsertAll(entry.key, entry.value);
    }
    await _cursor.write(result.serverTime);
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
  }
}
