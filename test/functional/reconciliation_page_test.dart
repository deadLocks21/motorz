import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:motorz/core/application/sync/sync_conflict.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/infrastructure/connectivity/connectivity_plus.service.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/infrastructure/sync/pending_queue.dart';
import 'package:motorz/infrastructure/sync/sync_api.dart';
import 'package:motorz/infrastructure/sync/sync_cursor.dart';
import 'package:motorz/infrastructure/sync/sync_service.dart';
import 'package:motorz/ui/pages/sync/reconciliation.page.dart';
import 'package:motorz/ui/theme/app_theme_data.dart';

/// Écran d'arbitrage des versions divergentes après une reconnexion : il doit
/// nommer l'entité, chiffrer l'écart et transmettre un choix par entité.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  SyncConflict vehicleConflict() => SyncConflict(
        local: const PendingOp(resource: 'vehicles', entityId: 'v-1', data: {
          'id': 'v-1',
          'nickname': 'La Mustang',
          'odometer': 50500,
          'updated_at': '2026-05-27T09:00:00Z',
        }),
        server: const {
          'id': 'v-1',
          'nickname': 'Mustang GT',
          'odometer': 51000,
          'updated_at': '2026-05-27T12:00:00Z',
        },
      );

  SyncConflict fuelConflict() => SyncConflict(
        local: const PendingOp(resource: 'fuel_entries', entityId: 'f-1', data: {
          'id': 'f-1',
          'date': '2026-03-12T00:00:00Z',
          'station': 'Total Nation',
          'updated_at': '2026-05-27T09:00:00Z',
        }),
        server: const {
          'id': 'f-1',
          'date': '2026-03-12T00:00:00Z',
          'station': 'Esso Wagram',
          'updated_at': '2026-05-27T12:00:00Z',
        },
      );

  Future<_SpySyncService> pumpPage(
    WidgetTester tester,
    List<SyncConflict> conflicts,
  ) async {
    final spy = _SpySyncService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncServiceProvider.overrideWithValue(spy),
          pendingConflictsProvider.overrideWith(() => _SeededConflicts(conflicts)),
        ],
        child: MaterialApp(
          theme: AppThemeData.buildLightTheme(),
          home: const ReconciliationPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return spy;
  }

  testWidgets('nomme chaque entité et chiffre l\'écart', (tester) async {
    await pumpPage(tester, [vehicleConflict(), fuelConflict()]);

    // « Mustang GT » apparaît deux fois : en titre de carte, et comme valeur
    // serveur de la ligne « Surnom » — l'écart sur ce champ est justement le
    // sujet de la carte.
    expect(find.text('Mustang GT'), findsWidgets);
    expect(find.text('Plein du 12/03/2026'), findsOneWidget);
    // Surnom + kilométrage diffèrent ; `updated_at` et `id` ne comptent pas.
    expect(find.text('+2 champ(s) différent(s)'), findsOneWidget);
    expect(find.text('+1 champ(s) différent(s)'), findsOneWidget);
    // Les deux valeurs sont montrées pour que le choix soit informé.
    expect(find.text('La Mustang'), findsOneWidget);
    expect(find.text('Total Nation'), findsOneWidget);
  });

  testWidgets('garde la version locale par défaut', (tester) async {
    // L'utilisateur arrive ici parce que ses saisies risquaient de disparaître.
    final spy = await pumpPage(tester, [vehicleConflict()]);

    expect(find.text('Envoyer 1 modification(s)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('applyReconciliationButton')));
    await tester.pumpAndSettle();

    expect(spy.resolved, {'vehicles/v-1': ConflictChoice.keepLocal});
  });

  testWidgets('un choix par entité est transmis tel quel', (tester) async {
    final spy = await pumpPage(tester, [vehicleConflict(), fuelConflict()]);

    // Bascule le seul véhicule sur « Serveur », laisse le plein sur « ma version ».
    await tester.tap(find.text('Serveur').first);
    await tester.pumpAndSettle();
    expect(find.text('Envoyer 1 modification(s)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('applyReconciliationButton')));
    await tester.pumpAndSettle();

    expect(spy.resolved, {
      'vehicles/v-1': ConflictChoice.keepServer,
      'fuel_entries/f-1': ConflictChoice.keepLocal,
    });
  });

  testWidgets('tout basculer sur le serveur annonce un abandon', (tester) async {
    await pumpPage(tester, [vehicleConflict()]);

    await tester.tap(find.text('Serveur').first);
    await tester.pumpAndSettle();

    expect(find.text('Tout abandonner'), findsOneWidget,
        reason: 'le bouton doit dire ce qu\'il fait quand plus rien n\'est envoyé');
  });
}

/// Capte les arbitrages sans toucher au réseau (même approche que les fakes
/// `SyncApi` des tests unitaires : on étend plutôt que d'implémenter).
class _SpySyncService extends SyncService {
  _SpySyncService()
      : super(
          api: SyncApi(Dio()),
          store: InMemoryLocalRecordStore(),
          queue: InMemoryPendingQueue(),
          connectivity: const AlwaysOnlineConnectivityService(),
          cursor: InMemorySyncCursorStore(),
          enabled: false,
        );

  Map<String, ConflictChoice>? resolved;

  @override
  Future<void> resolveConflicts(Map<String, ConflictChoice> choices) async {
    resolved = choices;
  }
}

class _SeededConflicts extends PendingConflicts {
  _SeededConflicts(this._seed);
  final List<SyncConflict> _seed;

  @override
  List<SyncConflict> build() => _seed;
}
