import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/sync/sync_conflict.dart';
import 'package:motorz/infrastructure/connectivity/connectivity_plus.service.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/infrastructure/sync/pending_queue.dart';
import 'package:motorz/infrastructure/sync/sync_api.dart';
import 'package:motorz/infrastructure/sync/sync_cursor.dart';
import 'package:motorz/infrastructure/sync/sync_service.dart';

/// SyncApi fictif reproduisant le last-write-wins du serveur : un push n'écrase
/// l'état serveur que si sa ligne est plus récente, et le pull suivant renvoie
/// cet état. Sans cette fidélité, un `push` puis `pull` ramènerait l'ancienne
/// version et masquerait ce que le vrai serveur fait.
class _FakeSyncApi extends SyncApi {
  _FakeSyncApi(this.serverState) : super(Dio());

  Map<String, List<Map<String, dynamic>>> serverState;
  final List<Map<String, List<Map<String, dynamic>>>> pushed = [];
  int pullCount = 0;

  @override
  Future<PullResult> pull(String? since) async {
    pullCount++;
    return PullResult(serverTime: '2026-05-27T00:00:00Z', changes: serverState);
  }

  @override
  Future<PushResult> push(Map<String, List<Map<String, dynamic>>> changes) async {
    pushed.add(changes);
    for (final entry in changes.entries) {
      final rows = serverState.putIfAbsent(entry.key, () => []);
      for (final row in entry.value) {
        final i = rows.indexWhere((r) => r['id'] == row['id']);
        if (i < 0) {
          rows.add(row);
          continue;
        }
        final incoming = DateTime.parse(row['updated_at'] as String);
        final existing = DateTime.parse(rows[i]['updated_at'] as String);
        if (!incoming.isBefore(existing)) rows[i] = row;
      }
    }
    return const PushResult(rejected: []);
  }
}

void main() {
  late InMemoryLocalRecordStore store;
  late InMemoryPendingQueue queue;
  late InMemorySyncCursorStore cursor;
  late _FakeSyncApi api;
  late SyncService sync;

  // Le serveur a touché la Mustang après notre dernière synchro.
  const serverVehicle = {
    'id': 'v-1',
    'nickname': 'Mustang GT',
    'license_plate': 'AA-123-BB',
    'odometer': 51000,
    'updated_at': '2026-05-27T12:00:00Z',
  };

  // Notre version locale, saisie hors ligne et jamais poussée : plus ancienne.
  const localVehicle = {
    'id': 'v-1',
    'nickname': 'La Mustang',
    'license_plate': 'AA-123-BB',
    'odometer': 50500,
    'updated_at': '2026-05-27T09:00:00Z',
  };

  setUp(() {
    store = InMemoryLocalRecordStore();
    queue = InMemoryPendingQueue();
    cursor = InMemorySyncCursorStore();
    api = _FakeSyncApi({
      'vehicles': [Map<String, dynamic>.from(serverVehicle)],
    });
    sync = SyncService(
      api: api,
      store: store,
      queue: queue,
      connectivity: const AlwaysOnlineConnectivityService(),
      cursor: cursor,
    );
  });

  group('Détection', () {
    test('signale une entité modifiée des deux côtés', () async {
      await queue.enqueue('vehicles', 'v-1', Map<String, dynamic>.from(localVehicle));

      final conflicts = await sync.detectConflicts();

      expect(conflicts, hasLength(1));
      expect(conflicts.single.entityId, 'v-1');
      expect(conflicts.single.changedFields, ['nickname', 'odometer'],
          reason: 'la plaque est identique des deux côtés, elle ne compte pas');
    });

    test('ne touche ni au store, ni à la file, ni au curseur', () async {
      // La détection sert à demander avant d'écraser : elle doit pouvoir être
      // abandonnée sans laisser de trace.
      await queue.enqueue('vehicles', 'v-1', Map<String, dynamic>.from(localVehicle));
      await cursor.write('2026-05-27T08:00:00Z');

      await sync.detectConflicts();

      expect(await store.query('vehicles'), isEmpty);
      expect(await queue.readAll(), hasLength(1));
      expect(await cursor.read(), '2026-05-27T08:00:00Z');
      expect(api.pushed, isEmpty);
    });

    test('pas de conflit si le serveur n\'a pas touché l\'entité', () async {
      api.serverState = {'vehicles': []};
      await queue.enqueue('vehicles', 'v-1', Map<String, dynamic>.from(localVehicle));

      expect(await sync.detectConflicts(), isEmpty);
    });

    test('pas de conflit si notre version est la plus récente', () async {
      await queue.enqueue('vehicles', 'v-1', {
        ...localVehicle,
        'updated_at': '2026-05-27T18:00:00Z',
      });

      expect(await sync.detectConflicts(), isEmpty);
    });

    test('une création locale pure n\'est jamais un conflit', () async {
      await queue.enqueue('vehicles', 'v-neuf', {
        'id': 'v-neuf',
        'nickname': 'Nouvelle',
        'updated_at': '2026-05-27T09:00:00Z',
      });

      expect(await sync.detectConflicts(), isEmpty);
    });

    test('file vide → aucun appel réseau', () async {
      expect(await sync.detectConflicts(), isEmpty);
      expect(api.pullCount, 0);
    });
  });

  group('Résolution', () {
    test('« ma version » est re-datée, sans quoi le serveur la rejetterait encore', () async {
      // Le serveur applique un last-write-wins muet : pousser la ligne telle
      // quelle (plus ancienne que la sienne) serait ignoré en silence, et
      // « garder ma version » ne ferait rien du tout.
      await queue.enqueue('vehicles', 'v-1', Map<String, dynamic>.from(localVehicle));

      await sync.resolveConflicts({'vehicles/v-1': ConflictChoice.keepLocal});

      final sent = api.pushed.single['vehicles']!.single;
      expect(sent['nickname'], 'La Mustang');
      expect(
        DateTime.parse(sent['updated_at'] as String)
            .isAfter(DateTime.parse(serverVehicle['updated_at'] as String)),
        isTrue,
        reason: 'sans re-datage, le LWW serveur jetterait de nouveau la ligne',
      );
    });

    test('« ma version » met aussi le store à jour', () async {
      await queue.enqueue('vehicles', 'v-1', Map<String, dynamic>.from(localVehicle));

      await sync.resolveConflicts({'vehicles/v-1': ConflictChoice.keepLocal});

      final stored = await store.getById('vehicles', 'v-1');
      expect(stored?['nickname'], 'La Mustang',
          reason: "l'UI afficherait l'ancienne ligne jusqu'au prochain pull");
    });

    test('« version serveur » sort l\'op de la file et ne la pousse pas', () async {
      await queue.enqueue('vehicles', 'v-1', Map<String, dynamic>.from(localVehicle));

      await sync.resolveConflicts({'vehicles/v-1': ConflictChoice.keepServer});

      expect(await queue.readAll(), isEmpty);
      expect(api.pushed, isEmpty, reason: 'rien de local à envoyer');
      final stored = await store.getById('vehicles', 'v-1');
      expect(stored?['nickname'], 'Mustang GT', reason: 'le pull ramène la version serveur');
    });

    test('les choix mixtes sont appliqués indépendamment', () async {
      await queue.enqueue('vehicles', 'v-1', Map<String, dynamic>.from(localVehicle));
      await queue.enqueue('fuel_entries', 'f-1', {
        'id': 'f-1',
        'station': 'Total Nation',
        'updated_at': '2026-05-27T09:00:00Z',
      });

      await sync.resolveConflicts({
        'vehicles/v-1': ConflictChoice.keepServer,
        'fuel_entries/f-1': ConflictChoice.keepLocal,
      });

      final sent = api.pushed.single;
      expect(sent.keys, ['fuel_entries']);
      expect(sent['fuel_entries']!.single['station'], 'Total Nation');
    });
  });

  group('Diff et libellés', () {
    test('les métadonnées ne comptent pas comme des différences', () async {
      // Seul `updated_at` diffère : annoncer « +1 champ » serait un faux positif.
      final conflict = SyncConflict(
        local: const PendingOp(resource: 'vehicles', entityId: 'v-1', data: {
          'id': 'v-1',
          'nickname': 'Mustang GT',
          'updated_at': '2026-05-27T09:00:00Z',
          'created_at': '2026-01-01T00:00:00Z',
        }),
        server: const {
          'id': 'v-1',
          'nickname': 'Mustang GT',
          'updated_at': '2026-05-27T12:00:00Z',
          'created_at': '2026-01-01T00:00:00Z',
        },
      );

      expect(conflict.changedFields, isEmpty);
    });

    test('une suppression locale est signalée comme telle', () async {
      final conflict = SyncConflict(
        local: const PendingOp(resource: 'fuel_entries', entityId: 'f-1', data: {
          'id': 'f-1',
          'updated_at': '2026-05-27T09:00:00Z',
          'deleted_at': '2026-05-27T09:00:00Z',
        }),
        server: const {'id': 'f-1', 'updated_at': '2026-05-27T12:00:00Z'},
      );

      expect(conflict.localDeletes, isTrue);
    });

    test('l\'entité est nommée lisiblement, avec repli sur la ressource', () {
      expect(entityLabel('vehicles', const {'nickname': 'Mustang GT'}, const {}), 'Mustang GT');
      expect(
        entityLabel('fuel_entries', const {'date': '2026-03-12T00:00:00Z'}, const {}),
        'Plein du 12/03/2026',
      );
      expect(entityLabel('tires', const {}, const {}), 'Pneu',
          reason: 'sans champ exploitable, le nom de la ressource reste lisible');
    });

    test('les champs inconnus restent lisibles sans table exhaustive', () {
      expect(fieldLabel('license_plate'), 'Plaque');
      expect(fieldLabel('some_new_field'), 'Some new field');
    });
  });
}
