import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';

/// Une mutation en attente de push : la ligne JWT « wire » complète à envoyer.
class PendingOp {
  final String resource;
  final String entityId;
  final Map<String, dynamic> data;
  const PendingOp({required this.resource, required this.entityId, required this.data});
}

/// File FIFO persistante des écritures à rejouer. **Last-write-wins par
/// `(resource, id)`** : ré-enfiler une même entité remplace l'op précédente.
abstract interface class PendingQueue {
  Future<void> enqueue(String resource, String entityId, Map<String, dynamic> data);
  Future<List<PendingOp>> readAll();
  Future<void> remove(String resource, String entityId);
  Future<void> clear();
}

class InMemoryPendingQueue implements PendingQueue {
  final List<PendingOp> _ops = [];

  @override
  Future<void> enqueue(String resource, String entityId, Map<String, dynamic> data) async {
    _ops.removeWhere((o) => o.resource == resource && o.entityId == entityId);
    _ops.add(PendingOp(resource: resource, entityId: entityId, data: data));
  }

  @override
  Future<List<PendingOp>> readAll() async => List.unmodifiable(_ops);

  @override
  Future<void> remove(String resource, String entityId) async {
    _ops.removeWhere((o) => o.resource == resource && o.entityId == entityId);
  }

  @override
  Future<void> clear() async => _ops.clear();
}

class SqflitePendingQueue implements PendingQueue {
  final Database _db;
  final Lock _lock = Lock();

  SqflitePendingQueue(this._db);

  static const table = 'pending_ops';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        seq        INTEGER PRIMARY KEY AUTOINCREMENT,
        resource   TEXT NOT NULL,
        entity_id  TEXT NOT NULL,
        data       TEXT NOT NULL,
        UNIQUE (resource, entity_id) ON CONFLICT REPLACE
      )
    ''');
  }

  @override
  Future<void> enqueue(String resource, String entityId, Map<String, dynamic> data) async {
    await _lock.synchronized(() async {
      // ON CONFLICT REPLACE : nouvelle seq → l'op repasse en fin de file (LWW).
      await _db.insert(table, {
        'resource': resource,
        'entity_id': entityId,
        'data': jsonEncode(data),
      });
    });
  }

  @override
  Future<List<PendingOp>> readAll() async {
    final rows = await _db.query(table, orderBy: 'seq ASC');
    return rows
        .map((r) => PendingOp(
              resource: r['resource'] as String,
              entityId: r['entity_id'] as String,
              data: jsonDecode(r['data'] as String) as Map<String, dynamic>,
            ))
        .toList(growable: false);
  }

  @override
  Future<void> remove(String resource, String entityId) async {
    await _lock.synchronized(() async {
      await _db.delete(table, where: 'resource = ? AND entity_id = ?', whereArgs: [resource, entityId]);
    });
  }

  @override
  Future<void> clear() async {
    await _lock.synchronized(() async => _db.delete(table));
  }
}
