import 'dart:async';

import 'package:motorz/core/application/sync/sync_codec.dart';
import 'package:motorz/core/domain/services/connectivity.service.dart';
import 'package:motorz/core/domain/services/syncable.repository.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/infrastructure/sync/pending_queue.dart';
import 'package:motorz/infrastructure/sync/sync_service.dart';

/// Décorateur offline-first générique : lectures depuis le store local,
/// écritures locales optimistes + mise en file, puis push immédiat si en ligne.
class OfflineFirstRepository<T> implements SyncableRepository<T> {
  final SyncCodec<T> _codec;
  final LocalRecordStore _store;
  final PendingQueue _queue;
  final SyncService _sync;
  final ConnectivityService _connectivity;

  OfflineFirstRepository({
    required SyncCodec<T> codec,
    required LocalRecordStore store,
    required PendingQueue queue,
    required SyncService sync,
    required ConnectivityService connectivity,
  })  : _codec = codec,
        _store = store,
        _queue = queue,
        _sync = sync,
        _connectivity = connectivity;

  @override
  Future<List<T>> listAll() async {
    final rows = await _store.query(_codec.resource);
    return rows.map(_codec.fromJson).toList(growable: false);
  }

  @override
  Future<List<T>> listForVehicle(String vehicleId) async {
    final rows = await _store.query(_codec.resource, vehicleId: vehicleId);
    return rows.map(_codec.fromJson).toList(growable: false);
  }

  @override
  Future<T?> getById(String id) async {
    final row = await _store.getById(_codec.resource, id);
    return row == null ? null : _codec.fromJson(row);
  }

  @override
  Future<void> save(T entity) async {
    final json = _codec.toJson(entity);
    await _store.put(_codec.resource, json);
    await _queue.enqueue(_codec.resource, _codec.idOf(entity), json);
    _maybeSync();
  }

  @override
  Future<void> delete(T entity) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final json = {..._codec.toJson(entity), 'deleted_at': nowIso, 'updated_at': nowIso};
    await _store.put(_codec.resource, json);
    await _queue.enqueue(_codec.resource, _codec.idOf(entity), json);
    _maybeSync();
  }

  void _maybeSync() {
    if (_connectivity.isOnline) unawaited(_sync.syncNow());
  }
}
