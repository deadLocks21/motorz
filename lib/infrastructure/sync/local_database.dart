import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
// Sur mobile, `openDatabase`/`databaseFactory` viennent de sqflite (auto-init du
// plugin natif) ; sur desktop on bascule sur la factory FFI.
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show databaseFactoryFfi, sqfliteFfiInit;
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/infrastructure/sync/pending_queue.dart';

/// Ouvre la base sqflite locale (init FFI sur desktop). Crée les tables
/// `records` (store) et `pending_ops` (file de synchro). Appelée au démarrage
/// sur mobile/desktop ; sur web on reste sur les impls mémoire.
Future<Database> openMotorzDatabase() async {
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  final dir = await getApplicationDocumentsDirectory();
  final path = p.join(dir.path, 'motorz.db');
  return openDatabase(
    path,
    version: 1,
    onCreate: (db, version) async {
      await SqfliteLocalRecordStore.createTable(db);
      await SqflitePendingQueue.createTable(db);
    },
  );
}
