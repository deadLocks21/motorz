import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';

/// Une mutation **définitivement refusée** par le serveur au push
/// (`forbidden` : cible non autorisée ; `invalid` : payload invalide). Sortie
/// de la file active pour ne pas boucler indéfiniment, et conservée ici pour
/// que l'utilisateur sache qu'une saisie n'est jamais remontée.
class RejectedOp {
  final String resource;
  final String entityId;
  final Map<String, dynamic> data;
  final String reason; // forbidden | invalid
  const RejectedOp({
    required this.resource,
    required this.entityId,
    required this.data,
    required this.reason,
  });
}

/// « Dead-letter » des écritures refusées en push. Persistante : le constat
/// d'un rejet doit survivre au redémarrage. Dé-doublonnée par `(resource, id)`
/// — re-rejouer puis re-rejeter une même entité remplace l'entrée précédente.
abstract interface class RejectedOpStore {
  Future<void> addAll(List<RejectedOp> ops);
  Future<List<RejectedOp>> readAll();
  Future<int> count();
  Future<void> clear();
}

class InMemoryRejectedOpStore implements RejectedOpStore {
  final Map<String, RejectedOp> _ops = {};

  String _key(String resource, String entityId) => '$resource/$entityId';

  @override
  Future<void> addAll(List<RejectedOp> ops) async {
    for (final op in ops) {
      _ops[_key(op.resource, op.entityId)] = op;
    }
  }

  @override
  Future<List<RejectedOp>> readAll() async => List.unmodifiable(_ops.values);

  @override
  Future<int> count() async => _ops.length;

  @override
  Future<void> clear() async => _ops.clear();
}

class SqfliteRejectedOpStore implements RejectedOpStore {
  final Database _db;
  final Lock _lock = Lock();

  SqfliteRejectedOpStore(this._db);

  static const table = 'rejected_ops';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        resource     TEXT NOT NULL,
        entity_id    TEXT NOT NULL,
        data         TEXT NOT NULL,
        reason       TEXT NOT NULL,
        rejected_at  TEXT NOT NULL,
        PRIMARY KEY (resource, entity_id) ON CONFLICT REPLACE
      )
    ''');
  }

  @override
  Future<void> addAll(List<RejectedOp> ops) async {
    if (ops.isEmpty) return;
    await _lock.synchronized(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      final batch = _db.batch();
      for (final op in ops) {
        batch.insert(table, {
          'resource': op.resource,
          'entity_id': op.entityId,
          'data': jsonEncode(op.data),
          'reason': op.reason,
          'rejected_at': now,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<RejectedOp>> readAll() async {
    final rows = await _db.query(table, orderBy: 'rejected_at ASC');
    return rows
        .map((r) => RejectedOp(
              resource: r['resource'] as String,
              entityId: r['entity_id'] as String,
              data: jsonDecode(r['data'] as String) as Map<String, dynamic>,
              reason: r['reason'] as String,
            ))
        .toList(growable: false);
  }

  @override
  Future<int> count() async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM $table')) ?? 0;

  @override
  Future<void> clear() async {
    await _lock.synchronized(() async => _db.delete(table));
  }
}
