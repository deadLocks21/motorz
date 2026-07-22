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
import 'package:motorz/ui/pages/stats/stats.page.dart';
import 'package:motorz/ui/theme/app_theme_data.dart';

/// Écran Statistiques (§5.9) : des courbes d'usage, pas de comptabilité — les
/// dépenses sont ventilées dans l'écran Finances.
class _OfflineConnectivity implements ConnectivityService {
  const _OfflineConnectivity();
  @override
  bool get isOnline => false;
  @override
  Stream<bool> watch() => Stream<bool>.value(false);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // 100 000 → 100 500 km (500 km) puis 32,1 L : 6,42 L/100, arrêtés au
  // 14/02/2026 — la moyenne ignore le volume du premier plein.
  final defaultFuel = <(DateTime, int, double)>[
    (DateTime.utc(2026, 1, 10), 100000, 40.0),
    (DateTime.utc(2026, 2, 14), 100500, 32.1),
  ];

  Future<(InMemoryLocalRecordStore, UuidValue)> seed({
    bool withFuel = true,
    List<(DateTime, int, double)>? entries,
    double? pricePerLiter,
  }) async {
    final store = InMemoryLocalRecordStore();
    final vehicleId = UuidValue.generate();
    await store.put(
      'vehicles',
      vehicleCodec.toJson(Vehicle(
        id: vehicleId,
        ownerUserId: UuidValue.generate(),
        type: VehicleType.voiture,
        nickname: 'La 308',
        updatedAt: DateTime.utc(2026, 1, 1),
      )),
    );
    if (withFuel) {
      var i = 0;
      for (final entry in entries ?? defaultFuel) {
        await store.put(
          'fuel_entries',
          fuelEntryCodec.toJson(FuelEntry(
            id: UuidValue.generate(),
            vehicleId: vehicleId,
            date: entry.$1,
            odometer: entry.$2,
            volumeLiters: entry.$3,
            pricePerLiter: pricePerLiter ?? 1.85 + i++ * 0.05,
            totalCost: 60,
            updatedAt: entry.$1,
          )),
        );
      }
    }
    return (store, vehicleId);
  }

  Future<void> open(
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
          home: StatsPage(vehicleId: vehicleId.value),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('la moyenne est donnée à deux décimales, avec sa date d\'arrêté',
      (tester) async {
    final (store, vehicleId) = await seed();
    await open(tester, store, vehicleId);

    expect(find.text('moy. 6,42 L/100 · au 14/02/2026'), findsOneWidget);
  });

  testWidgets('les dépenses ne sont plus ici — elles vivent dans Finances', (tester) async {
    final (store, vehicleId) = await seed();
    await open(tester, store, vehicleId);

    expect(find.text('Dépenses'), findsNothing);
    expect(find.textContaining('Total :'), findsNothing);
    expect(find.text('Carburant'), findsNothing);
    expect(find.text('Entretien'), findsNothing);
  });

  testWidgets('l\'écran tient sur trois courbes d\'usage', (tester) async {
    final (store, vehicleId) = await seed();
    await open(tester, store, vehicleId);

    expect(find.text('Consommation'), findsOneWidget);
    expect(find.text('Prix au litre'), findsOneWidget);
    expect(find.text('Km parcourus'), findsOneWidget);
  });

  testWidgets('les graduations de conso ne se répètent pas et datent les points',
      (tester) async {
    // 2,84 / 2,97 / 2,90 L/100 : au pas libre et à une décimale, l'axe sortait
    // « 2,9 » trois fois de suite.
    final (store, vehicleId) = await seed(entries: [
      (DateTime.utc(2026, 1, 10), 100000, 40.0),
      (DateTime.utc(2026, 2, 10), 101000, 28.4),
      (DateTime.utc(2026, 3, 10), 102000, 29.7),
      (DateTime.utc(2026, 4, 10), 103000, 29.0),
    ]);
    await open(tester, store, vehicleId);

    for (final graduation in ['2,80', '2,85', '2,90', '2,95', '3,00']) {
      expect(find.text(graduation), findsOneWidget, reason: 'graduation $graduation attendue');
    }
    expect(find.text('2,9'), findsNothing, reason: 'plus aucune graduation à une décimale');
    // Chaque point est situé dans le temps par l'axe des abscisses.
    expect(find.text('04/26'), findsWidgets);
  });

  testWidgets('des pleins tous au même prix ne dupliquent pas une graduation',
      (tester) async {
    // Plage nulle : sans marge, le bas et le haut de l'axe tombent sur la même
    // valeur, que fl_chart dessine deux fois.
    final (store, vehicleId) = await seed(entries: [
      (DateTime.utc(2026, 1, 10), 100000, 40.0),
      (DateTime.utc(2026, 2, 10), 101000, 40.0),
      (DateTime.utc(2026, 3, 10), 102000, 40.0),
    ], pricePerLiter: 1.92);
    await open(tester, store, vehicleId);

    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => RegExp(r'^\d,\d{2}$').hasMatch(s))
        .toList();
    expect(labels, isNotEmpty);
    expect(labels.toSet().length, labels.length, reason: 'graduations dupliquées : $labels');
  });

  testWidgets('l\'axe des km ne gradue que des valeurs rondes', (tester) async {
    // 2 000 km sur février : le haut du graphe se cale sur 3 000 plutôt que sur
    // 2 300 (max + rembourrage), qui donnerait un « 2,3k » collé au « 2,0k ».
    final (store, vehicleId) = await seed(entries: [
      (DateTime.utc(2026, 1, 10), 100000, 40.0),
      (DateTime.utc(2026, 2, 10), 102000, 130.0),
    ]);
    await open(tester, store, vehicleId);

    expect(find.text('3,0k'), findsOneWidget);
    expect(find.text('2,3k'), findsNothing);
  });

  testWidgets('sans plein, l\'écran le dit au lieu d\'afficher une moyenne', (tester) async {
    final (store, vehicleId) = await seed(withFuel: false);
    await open(tester, store, vehicleId);

    expect(find.text('Pas assez de données'), findsNWidgets(3));
    expect(find.textContaining('moy.'), findsNothing);
  });
}
