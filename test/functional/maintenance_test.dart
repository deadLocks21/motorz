import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:motorz/core/application/sync/entity_codecs.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/model/vehicle.dart';
import 'package:motorz/core/domain/services/connectivity.service.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/ui/pages/vehicle_detail/vehicle_detail.page.dart';
import 'package:motorz/ui/theme/app_theme_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _OfflineConnectivity implements ConnectivityService {
  const _OfflineConnectivity();
  @override
  bool get isOnline => false;
  @override
  Stream<bool> watch() => Stream<bool>.value(false);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<(InMemoryLocalRecordStore, UuidValue)> seed() async {
    final store = InMemoryLocalRecordStore();
    final vehicleId = UuidValue.generate();
    final vehicle = Vehicle(
      id: vehicleId,
      ownerUserId: UuidValue.generate(),
      type: VehicleType.voiture,
      nickname: 'La 308',
      make: 'Peugeot',
      updatedAt: DateTime.utc(2026, 5, 1),
    );
    await store.put('vehicles', vehicleCodec.toJson(vehicle));
    return (store, vehicleId);
  }

  Future<void> pumpDetail(
      WidgetTester tester, InMemoryLocalRecordStore store, UuidValue vehicleId) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localRecordStoreProvider.overrideWithValue(store),
          connectivityServiceProvider.overrideWithValue(const _OfflineConnectivity()),
          currentSessionProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          theme: AppThemeData.buildLightTheme(),
          home: VehicleDetailPage(vehicleId: vehicleId.value),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opération à lignes libres : saisie + apparition dans Entretien', (tester) async {
    final (store, vehicleId) = await seed();
    await pumpDetail(tester, store, vehicleId);

    await tester.tap(find.text('Entretien'));
    await tester.pumpAndSettle();
    expect(find.text('Aucune opération d\'entretien enregistrée.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('detailFab')));
    await tester.pumpAndSettle();
    expect(find.text('Entretien réalisé'), findsOneWidget);

    // Ciblage par libellé plutôt que par position : la feuille masque le champ
    // « Prestataire » tant que l'opération est faite par soi-même.
    await tester.enterText(find.byKey(const Key('operationOdometerField')), '20000');
    await tester.enterText(find.widgetWithText(TextField, 'Pièce'), 'Vidange');
    await tester.enterText(find.widgetWithText(TextField, 'Prix'), '90');
    final saveBtn = find.widgetWithText(FilledButton, 'Enregistrer l\'opération');
    await tester.ensureVisible(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // Pas d'émergence : sauvegarde directe.
    expect((await store.query('maintenance_operations')), hasLength(1));
    expect((await store.query('maintenance_operation_lines')), hasLength(1));
    expect((await store.query('maintenance_catalog_items')), isEmpty);
    // Titre dérivé « Vidange » dans la liste.
    expect(find.text('Vidange'), findsWidgets);
  });

  testWidgets('À prévoir : le + crée une tâche ponctuelle → section « À réaliser »', (tester) async {
    final (store, vehicleId) = await seed();
    await pumpDetail(tester, store, vehicleId);

    await tester.tap(find.text('À prévoir'));
    await tester.pumpAndSettle();
    expect(find.text('Fait'), findsNothing); // plus de bouton « Fait »

    await tester.tap(find.byKey(const Key('detailFab')));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle entrée'), findsOneWidget);

    // Bascule sur « Ponctuelle » → pas d'intervalle requis.
    await tester.tap(find.text('Ponctuelle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Changer le rétroviseur'); // Titre
    final saveBtn = find.widgetWithText(FilledButton, 'Enregistrer');
    await tester.ensureVisible(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    expect((await store.query('maintenance_plans')), hasLength(1));
    // Une ponctuelle sans déclencheur apparaît sous « À réaliser ».
    expect(find.text('À RÉALISER'), findsOneWidget);
    expect(find.text('Changer le rétroviseur'), findsWidgets);
  });
}
