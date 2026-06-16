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

  // Ajoute un pneu Michelin via le bouton « Ajouter » de l'onglet Pneus.
  Future<void> addTire(WidgetTester tester, {String model = '', String size = ''}) async {
    await tester.tap(find.widgetWithText(TextButton, 'Ajouter'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tireBrandField')), 'Michelin');
    if (model.isNotEmpty) await tester.enterText(find.byKey(const Key('tireModelField')), model);
    if (size.isNotEmpty) await tester.enterText(find.byKey(const Key('tireSizeField')), size);
    final saveTire = find.byKey(const Key('saveTireButton'));
    await tester.ensureVisible(saveTire);
    await tester.pumpAndSettle();
    await tester.tap(saveTire);
    await tester.pumpAndSettle();
  }

  // Monte le pneu (unique candidat) en AVG via la page de position, à [odo] km.
  Future<void> mountInAvg(WidgetTester tester, String odo) async {
    await tester.tap(find.text('AVG'));
    await tester.pumpAndSettle();
    expect(find.text('Avant gauche'), findsOneWidget); // page de position
    await tester.tap(find.byKey(const Key('positionActionButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('mountOdometerField')), odo);
    final mountBtn = find.byKey(const Key('mountConfirmButton'));
    await tester.ensureVisible(mountBtn);
    await tester.pumpAndSettle();
    await tester.tap(mountBtn);
    await tester.pumpAndSettle();
  }

  testWidgets('pneu : carte → page détail ; roue → page position → montage', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (store, vehicleId) = await seed();
    await pumpDetail(tester, store, vehicleId);

    await tester.tap(find.text('Pneus'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun pneu. Touche « Ajouter » pour en enregistrer un.'), findsOneWidget);
    expect(find.text('AVG'), findsOneWidget); // grille de monte

    await addTire(tester, model: 'Pilot Sport 4S', size: '255/40 R19');
    expect((await store.query('tires')), hasLength(1));
    expect(find.text('Stock'), findsOneWidget);

    // Tap sur la carte → page détail du pneu (read-first).
    await tester.tap(find.text('Michelin Pilot Sport 4S'));
    await tester.pumpAndSettle();
    expect(find.text('En stock'), findsOneWidget); // statut sur la page détail
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Tap sur la roue → page position → montage à 10 000 km.
    await mountInAvg(tester, '10000');
    expect((await store.query('tire_mounts')), hasLength(1));
    // De retour sur la page position : le pneu est monté.
    expect(find.text('Michelin Pilot Sport 4S'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Changer / démonter'), findsOneWidget);

    // Historique des changements depuis l'onglet Pneus.
    await tester.pageBack();
    await tester.pumpAndSettle();
    final histBtn = find.widgetWithText(OutlinedButton, 'Historique des changements');
    await tester.ensureVisible(histBtn);
    await tester.pumpAndSettle();
    await tester.tap(histBtn);
    await tester.pumpAndSettle();
    expect(find.text('Historique des pneus'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsWidgets); // un « Monté »
  });

  testWidgets('l\'onglet Pressions porte les cibles & relevés (séparé de Pneus)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (store, vehicleId) = await seed();
    await pumpDetail(tester, store, vehicleId);

    await tester.tap(find.text('Pressions'));
    await tester.pumpAndSettle();
    expect(find.text('Relevés'), findsOneWidget);
    expect(find.text('Définir une pression cible'), findsOneWidget);
    expect(find.text('Inventaire'), findsNothing); // l'inventaire reste sur Pneus
  });

  testWidgets('mettre au rebut (depuis la page détail) : démontage auto, pneu gardé', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (store, vehicleId) = await seed();
    await pumpDetail(tester, store, vehicleId);

    await tester.tap(find.text('Pneus'));
    await tester.pumpAndSettle();
    await addTire(tester);
    await mountInAvg(tester, '10000');
    expect((await store.query('tire_mounts')), hasLength(1));

    // Retour au garage, puis ouvre la fiche du pneu via sa carte d'inventaire
    // (la fiche de roue ne donne pas accès au détail du pneu).
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Michelin').last); // carte d'inventaire, pas la cellule de roue
    await tester.pumpAndSettle();
    expect(find.text('Monté · Avant gauche'), findsOneWidget);

    // ✏️ → feuille → Mettre au rebut → confirme.
    await tester.tap(find.byKey(const Key('tireEditButton')));
    await tester.pumpAndSettle();
    final disposeBtn = find.byKey(const Key('disposeTireButton'));
    await tester.ensureVisible(disposeBtn);
    await tester.pumpAndSettle();
    await tester.tap(disposeBtn);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Au rebut'));
    await tester.pumpAndSettle();

    // Intervalle fermé (démontage auto au km courant), pneu conservé, statut au rebut.
    final mounts = await store.query('tire_mounts');
    expect(mounts, hasLength(1));
    expect(mounts.first['dismounted_odometer'], 10000);
    expect((await store.query('tires')), hasLength(1)); // pas supprimé
    expect(find.textContaining('Au rebut'), findsWidgets); // statut sur la page détail
  });
}
