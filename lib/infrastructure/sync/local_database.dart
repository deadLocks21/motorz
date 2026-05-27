// Ce fichier importe `dart:io` et `sqflite_common_ffi` tout en étant atteignable
// depuis `main.dart`, et pourtant le build web n'en est PAS cassé (vérifié :
// `flutter build web` passe, Wasm dry-run inclus). Donc inutile de planquer ces
// imports derrière un import conditionnel — ce n'est pas nécessaire ici.
//
//   • `dart:io` est *stubé* par le SDK sur les cibles web (dart2js/dartdevc/
//     wasm) : l'import compile ; `Platform.*` ne lèverait `UnsupportedError`
//     qu'à l'exécution.
//   • `sqflite_common_ffi` est déjà web-safe — son `sqflite_ffi.dart` fait
//     `export … if (dart.library.js_interop) 'sqflite_ffi_web.dart'`, donc
//     aucun `dart:ffi` n'est tiré sur web.
//
// De toute façon `openMotorzDatabase()` n'est jamais appelée sur web : `main()`
// la garde derrière `!kIsWeb` (+ try/catch de repli sur la mémoire). Web tourne
// en mode mémoire et les stubs ci-dessus ne sont jamais invoqués au runtime.
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
