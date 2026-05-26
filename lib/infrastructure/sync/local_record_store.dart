import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';

/// Store local des enregistrements synchronisables — **source de vérité des
/// lectures** (offline-first). Chaque enregistrement est la ligne JSON « wire »
/// (telle que sérialisée par l'API), indexée par `(resource, id)` avec
/// `vehicle_id`, `updated_at`, `deleted_at` extraits pour le filtrage.
abstract interface class LocalRecordStore {
  /// Upsert d'un lot venant de `/sync/changes` (peut contenir des tombstones).
  Future<void> upsertAll(String resource, List<Map<String, dynamic>> rows);

  /// Écriture locale d'une ligne (optimiste).
  Future<void> put(String resource, Map<String, dynamic> row);

  /// Lignes d'une ressource. `vehicleId` filtre les sous-ressources ;
  /// `null` renvoie tout (ex. liste des véhicules).
  Future<List<Map<String, dynamic>>> query(
    String resource, {
    String? vehicleId,
    bool includeDeleted = false,
  });

  Future<Map<String, dynamic>?> getById(String resource, String id);

  /// Émet à chaque écriture — l'UI s'y abonne pour se rafraîchir.
  Stream<void> get changes;
}

String? _vehicleIdOf(Map<String, dynamic> row) => row['vehicle_id'] as String?;
String? _updatedAtOf(Map<String, dynamic> row) => row['updated_at'] as String?;
String? _deletedAtOf(Map<String, dynamic> row) => row['deleted_at'] as String?;

// ── Impl mémoire (tests, web) ───────────────────────────────────────────────

class InMemoryLocalRecordStore implements LocalRecordStore {
  final Map<String, Map<String, Map<String, dynamic>>> _data = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  Map<String, Map<String, dynamic>> _bucket(String resource) =>
      _data.putIfAbsent(resource, () => {});

  @override
  Future<void> upsertAll(String resource, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final bucket = _bucket(resource);
    for (final row in rows) {
      bucket[row['id'] as String] = row;
    }
    _changes.add(null);
  }

  @override
  Future<void> put(String resource, Map<String, dynamic> row) async {
    _bucket(resource)[row['id'] as String] = row;
    _changes.add(null);
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String resource, {
    String? vehicleId,
    bool includeDeleted = false,
  }) async {
    return _bucket(resource).values.where((row) {
      if (!includeDeleted && _deletedAtOf(row) != null) return false;
      if (vehicleId != null && _vehicleIdOf(row) != vehicleId) return false;
      return true;
    }).toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>?> getById(String resource, String id) async =>
      _bucket(resource)[id];
}

// ── Impl sqflite (mobile/desktop) ───────────────────────────────────────────

class SqfliteLocalRecordStore implements LocalRecordStore {
  final Database _db;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final Lock _lock = Lock();

  SqfliteLocalRecordStore(this._db);

  static const table = 'records';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        resource    TEXT NOT NULL,
        id          TEXT NOT NULL,
        vehicle_id  TEXT,
        updated_at  TEXT,
        deleted_at  TEXT,
        data        TEXT NOT NULL,
        PRIMARY KEY (resource, id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS records_resource_vehicle_idx ON $table (resource, vehicle_id)',
    );
  }

  @override
  Stream<void> get changes => _changes.stream;

  Future<void> _write(String resource, Iterable<Map<String, dynamic>> rows) async {
    await _lock.synchronized(() async {
      final batch = _db.batch();
      for (final row in rows) {
        batch.insert(
          table,
          {
            'resource': resource,
            'id': row['id'],
            'vehicle_id': _vehicleIdOf(row),
            'updated_at': _updatedAtOf(row),
            'deleted_at': _deletedAtOf(row),
            'data': jsonEncode(row),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
    _changes.add(null);
  }

  @override
  Future<void> upsertAll(String resource, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _write(resource, rows);
  }

  @override
  Future<void> put(String resource, Map<String, dynamic> row) => _write(resource, [row]);

  @override
  Future<List<Map<String, dynamic>>> query(
    String resource, {
    String? vehicleId,
    bool includeDeleted = false,
  }) async {
    final where = <String>['resource = ?'];
    final args = <Object?>[resource];
    if (!includeDeleted) where.add('deleted_at IS NULL');
    if (vehicleId != null) {
      where.add('vehicle_id = ?');
      args.add(vehicleId);
    }
    final rows = await _db.query(table, where: where.join(' AND '), whereArgs: args);
    return rows
        .map((r) => jsonDecode(r['data'] as String) as Map<String, dynamic>)
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>?> getById(String resource, String id) async {
    final rows = await _db.query(
      table,
      where: 'resource = ? AND id = ?',
      whereArgs: [resource, id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
  }
}
