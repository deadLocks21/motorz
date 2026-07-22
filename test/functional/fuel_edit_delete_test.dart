import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:motorz/core/application/sync/entity_codecs.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/fuel_entry.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/model/vehicle.dart';
import 'package:motorz/core/domain/services/connectivity.service.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/ui/pages/vehicle_detail/vehicle_detail.page.dart';
import 'package:motorz/ui/theme/app_theme_data.dart';

/// Hors-ligne : les écritures restent locales (offline-first), aucune synchro
/// réseau n'est déclenchée — l'UI se met à jour via le stream `changes` du store.
class _OfflineConnectivity implements ConnectivityService {
  const _OfflineConnectivity();
  @override
  bool get isOnline => false;
  @override
  Stream<bool> watch() => Stream<bool>.value(false);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // Ancre stable et indépendante de la locale (date numérique + station) pour
  // retrouver la ligne du plein : les nombres formatés (séparateurs) varient
  // selon la locale active des tests, pas ce sous-titre.
  const fuelRow = '10/05/2026 · Total';

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
    final entry = FuelEntry(
      id: UuidValue.generate(),
      vehicleId: vehicleId,
      date: DateTime.utc(2026, 5, 10, 12),
      odometer: 100000,
      volumeLiters: 45,
      pricePerLiter: 1.85,
      totalCost: 45 * 1.85,
      fuelType: FuelType.essence,
      station: 'Total',
      updatedAt: DateTime.utc(2026, 5, 10),
    );
    await store.put('vehicles', vehicleCodec.toJson(vehicle));
    await store.put('fuel_entries', fuelEntryCodec.toJson(entry));
    return (store, vehicleId);
  }

  Future<void> pumpFuelTab(
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
    await tester.tap(find.text('Pleins'));
    await tester.pumpAndSettle();
  }

  testWidgets('taper une ligne rouvre la feuille pré-remplie et met à jour le plein',
      (tester) async {
    final (store, vehicleId) = await seed();
    await pumpFuelTab(tester, store, vehicleId);

    expect(find.text(fuelRow), findsOneWidget);

    // Tap → la feuille se rouvre pré-remplie (interaction uniformisée des
    // listes : la tuile édite, la suppression vit dans la feuille).
    await tester.tap(find.text(fuelRow));
    await tester.pumpAndSettle();
    expect(find.text('Modifier le plein'), findsOneWidget);
    final odoField = tester.widget<TextField>(find.byKey(const Key('fuelOdometerField')));
    expect(odoField.controller!.text, '100000');

    // Change le kilométrage et enregistre.
    await tester.enterText(find.byKey(const Key('fuelOdometerField')), '100123');
    await tester.tap(find.byKey(const Key('saveFuelButton')));
    await tester.pumpAndSettle();

    // Upsert sur le même id : une seule entrée, valeur mise à jour.
    final rows = await store.query('fuel_entries');
    expect(rows.length, 1, reason: 'édition = mise à jour, pas de nouveau plein');
    expect((rows.first['odometer'] as num).toInt(), 100123);
  });

  testWidgets('nouveau plein avec km seul (date effacée) est enregistré', (tester) async {
    final (store, vehicleId) = await seed();
    await pumpFuelTab(tester, store, vehicleId);

    // + → feuille « Nouveau plein » (date par défaut = aujourd'hui).
    await tester.tap(find.byKey(const Key('detailFab')));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau plein'), findsOneWidget);

    // Efface la date, saisit uniquement le kilométrage.
    await tester.tap(find.byKey(const Key('fuelDateClearButton')));
    await tester.pumpAndSettle();
    expect(find.text('Aucune (km seul)'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('fuelOdometerField')), '100200');
    await tester.tap(find.byKey(const Key('saveFuelButton')));
    await tester.pumpAndSettle();

    final rows = await store.query('fuel_entries');
    final added = rows.firstWhere((r) => (r['odometer'] as num?)?.toInt() == 100200);
    expect(added['date'], isNull, reason: 'km seul → pas de date');
  });

  testWidgets('nouveau plein avec date seule (km effacé) est enregistré', (tester) async {
    final (store, vehicleId) = await seed();
    await pumpFuelTab(tester, store, vehicleId);

    await tester.tap(find.byKey(const Key('detailFab')));
    await tester.pumpAndSettle();

    // Efface le kilométrage pré-rempli, garde la date par défaut.
    await tester.enterText(find.byKey(const Key('fuelOdometerField')), '');
    await tester.tap(find.byKey(const Key('saveFuelButton')));
    await tester.pumpAndSettle();

    final rows = await store.query('fuel_entries');
    final added = rows.firstWhere((r) => r['odometer'] == null);
    expect(added['date'], isNotNull, reason: 'date seule → km absent');
  });

  testWidgets('refus si ni km ni date', (tester) async {
    final (store, vehicleId) = await seed();
    await pumpFuelTab(tester, store, vehicleId);

    await tester.tap(find.byKey(const Key('detailFab')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fuelDateClearButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('fuelOdometerField')), '');
    await tester.tap(find.byKey(const Key('saveFuelButton')));
    await tester.pumpAndSettle();

    expect(find.text('Indique au moins le kilométrage ou la date.'), findsOneWidget);
    expect((await store.query('fuel_entries')).length, 1, reason: 'aucun plein ajouté');
  });

  testWidgets('« un plein manque avant celui-ci » se pose en édition et se persiste',
      (tester) async {
    final (store, vehicleId) = await seed();
    await pumpFuelTab(tester, store, vehicleId);

    // Absent du chemin de saisie : un plein manqué se découvre après coup.
    await tester.tap(find.byKey(const Key('detailFab')));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau plein'), findsOneWidget);
    expect(find.byKey(const Key('fuelMissedFillSwitch')), findsNothing);
    Navigator.of(tester.element(find.text('Nouveau plein'))).pop();
    await tester.pumpAndSettle();

    // Présent en édition, et enregistré sur l'entrée.
    await tester.tap(find.text(fuelRow));
    await tester.pumpAndSettle();
    final switchFinder = find.byKey(const Key('fuelMissedFillSwitch'));
    await tester.ensureVisible(switchFinder);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('saveFuelButton')));
    await tester.tap(find.byKey(const Key('saveFuelButton')));
    await tester.pumpAndSettle();

    final rows = await store.query('fuel_entries');
    expect(rows.length, 1);
    expect(rows.first['missed_fill_before'], true);
  });

  testWidgets('Supprimer, dans la feuille, demande confirmation puis retire le plein',
      (tester) async {
    final (store, vehicleId) = await seed();
    await pumpFuelTab(tester, store, vehicleId);

    await tester.tap(find.text(fuelRow));
    await tester.pumpAndSettle();
    // La feuille défile : le bouton du bas n'est pas forcément à l'écran.
    await tester.ensureVisible(find.text('Supprimer'));
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    // Modale de confirmation : rien n'est supprimé tant qu'on n'a pas confirmé.
    expect(find.text('Supprimer ce plein ?'), findsOneWidget);
    expect((await store.query('fuel_entries')).length, 1);

    // Confirme la suppression.
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(find.text(fuelRow), findsNothing);
    expect(find.text('Aucun plein. Touche + pour en ajouter un.'), findsOneWidget);
    expect((await store.query('fuel_entries')), isEmpty,
        reason: 'tombstone : le plein supprimé n\'est plus listé');
  });
}
