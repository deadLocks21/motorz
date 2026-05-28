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

/// Le champ « Station » d'un nouveau plein propose les stations déjà saisies
/// (autocomplétion) tout en laissant taper une station inédite (§5.8).
class _OfflineConnectivity implements ConnectivityService {
  const _OfflineConnectivity();
  @override
  bool get isOnline => false;
  @override
  Stream<bool> watch() => Stream<bool>.value(false);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// Véhicule avec deux pleins à des stations différentes → deux suggestions.
  Future<(InMemoryLocalRecordStore, UuidValue)> seed() async {
    final store = InMemoryLocalRecordStore();
    final vehicleId = UuidValue.generate();
    await store.put(
      'vehicles',
      vehicleCodec.toJson(Vehicle(
        id: vehicleId,
        ownerUserId: UuidValue.generate(),
        type: VehicleType.voiture,
        nickname: 'La 308',
        make: 'Peugeot',
        updatedAt: DateTime.utc(2026, 5, 1),
      )),
    );
    for (final (i, station) in ['Total', 'Esso'].indexed) {
      await store.put(
        'fuel_entries',
        fuelEntryCodec.toJson(FuelEntry(
          id: UuidValue.generate(),
          vehicleId: vehicleId,
          date: DateTime.utc(2026, 5, 10 + i, 12),
          odometer: 100000 + i * 500,
          volumeLiters: 45,
          pricePerLiter: 1.85,
          fuelType: FuelType.essence,
          station: station,
          updatedAt: DateTime.utc(2026, 5, 10 + i),
        )),
      );
    }
    return (store, vehicleId);
  }

  Future<void> openNewFuelSheet(
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
    await tester.tap(find.text('Pleins')); // le FAB n'existe que hors onglet « Vue d'ensemble »
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detailFab')));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau plein'), findsOneWidget);
  }

  testWidgets('le champ station devient une liste déroulante quand des stations existent',
      (tester) async {
    final (store, vehicleId) = await seed();
    await openNewFuelSheet(tester, store, vehicleId);

    // Affordance de liste déroulante (chevron) sur le champ station.
    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
  });

  testWidgets('le champ station est vide à l\'ouverture (pas de préremplissage auto)',
      (tester) async {
    final (store, vehicleId) = await seed();
    await openNewFuelSheet(tester, store, vehicleId);

    // Même avec des pleins existants, on n'impose plus la station de la dernière
    // fois : le champ s'ouvre vide, à compléter via la liste déroulante.
    final field = tester.widget<TextField>(find.byKey(const Key('fuelStationField')));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('taper filtre les suggestions ; sélectionner pré-remplit la station',
      (tester) async {
    final (store, vehicleId) = await seed();
    await openNewFuelSheet(tester, store, vehicleId);

    // « ess » ne doit proposer que « Esso » (« Total » est filtré).
    await tester.enterText(find.byKey(const Key('fuelStationField')), 'ess');
    await tester.pumpAndSettle();
    expect(find.text('Esso'), findsOneWidget);
    expect(find.text('Total'), findsNothing);

    // Sélectionner la suggestion remplit le champ, puis on enregistre le plein.
    await tester.tap(find.text('Esso'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byKey(const Key('fuelStationField')));
    expect(field.controller!.text, 'Esso');

    await tester.enterText(find.byKey(const Key('fuelOdometerField')), '101000');
    await tester.tap(find.byKey(const Key('saveFuelButton')));
    await tester.pumpAndSettle();

    final rows = await store.query('fuel_entries');
    final added = rows.firstWhere((r) => (r['odometer'] as num?)?.toInt() == 101000);
    expect(added['station'], 'Esso');
  });

  testWidgets('une station inédite reste saisissable (pas imposée par la liste)',
      (tester) async {
    final (store, vehicleId) = await seed();
    await openNewFuelSheet(tester, store, vehicleId);

    // On tape une station qui n'existe pas encore : aucune suggestion ne doit
    // l'écraser, elle est enregistrée telle quelle.
    await tester.enterText(find.byKey(const Key('fuelStationField')), 'Avia Cergy');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('fuelOdometerField')), '101000');
    await tester.tap(find.byKey(const Key('saveFuelButton')));
    await tester.pumpAndSettle();

    final rows = await store.query('fuel_entries');
    final added = rows.firstWhere((r) => (r['odometer'] as num?)?.toInt() == 101000);
    expect(added['station'], 'Avia Cergy');
  });
}
