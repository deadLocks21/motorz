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

/// Hors-ligne : les écritures restent locales, l'UI se met à jour via le stream
/// `changes` du store (aucune synchro réseau).
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

  testWidgets('opération à lignes : saisie + émergence d\'un plan + projection', (tester) async {
    final (store, vehicleId) = await seed();
    await pumpDetail(tester, store, vehicleId);

    await tester.tap(find.text('Entretien'));
    await tester.pumpAndSettle();
    expect(find.text('Aucune opération d\'entretien enregistrée.'), findsOneWidget);

    // FAB → feuille « Entretien réalisé ».
    await tester.tap(find.byKey(const Key('detailFab')));
    await tester.pumpAndSettle();
    expect(find.text('Entretien réalisé'), findsOneWidget);

    // Km + une ligne catalogue « Vidange » + coût pièces.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '20000'); // Km
    await tester.enterText(fields.at(4), 'Vidange'); // Poste (ligne 0)
    await tester.enterText(fields.at(5), '90'); // Pièces
    final saveBtn = find.widgetWithText(FilledButton, 'Enregistrer l\'opération');
    await tester.ensureVisible(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // Émergence : on propose de programmer un rappel pour « Vidange ».
    expect(find.text('Programmer un rappel ?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Programmer'));
    await tester.pumpAndSettle();

    // Persistance : opération + ligne + poste de catalogue + plan créés.
    expect((await store.query('maintenance_operations')), hasLength(1));
    expect((await store.query('maintenance_operation_lines')), hasLength(1));
    expect((await store.query('maintenance_catalog_items')), hasLength(1));
    expect((await store.query('maintenance_plans')), hasLength(1));
    // Titre dérivé « Vidange » dans la liste.
    expect(find.text('Vidange'), findsWidgets);

    // À prévoir : projection sans bouton « Fait », bouton « Gérer » présent.
    await tester.tap(find.text('À prévoir'));
    await tester.pumpAndSettle();
    expect(find.text('Fait'), findsNothing);
    expect(find.text('Gérer'), findsOneWidget);
    expect(find.text('Vidange'), findsWidgets);
  });

  testWidgets('À prévoir : le + crée une échéance à venir (sans passé)', (tester) async {
    final (store, vehicleId) = await seed();
    await pumpDetail(tester, store, vehicleId);

    await tester.tap(find.text('À prévoir'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('detailFab')));
    await tester.pumpAndSettle();
    expect(find.text('Échéance à venir'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Distribution'); // Titre
    await tester.enterText(fields.at(1), '120000'); // Avant km
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    expect((await store.query('maintenance_plans')), hasLength(1));
    expect(find.text('Distribution'), findsWidgets);
  });
}
