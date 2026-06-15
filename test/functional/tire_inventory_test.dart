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

  testWidgets('ajoute un pneu à l\'inventaire puis le monte en AVG', (tester) async {
    // Feuilles longues : surface haute pour garder boutons et grille à l'écran.
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (store, vehicleId) = await seed();
    await pumpDetail(tester, store, vehicleId);

    await tester.tap(find.text('Pneus'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun pneu. Touche « Ajouter » pour en enregistrer un.'), findsOneWidget);
    expect(find.text('AVG'), findsOneWidget); // grille de monte affichée

    // Ajoute un pneu via le bouton de section (pas le FAB, réservé aux pressions).
    await tester.tap(find.widgetWithText(TextButton, 'Ajouter'));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau pneu'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('tireBrandField')), 'Michelin');
    await tester.enterText(find.byKey(const Key('tireModelField')), 'Pilot Sport 4S');
    await tester.enterText(find.byKey(const Key('tireSizeField')), '255/40 R19');
    final saveTire = find.byKey(const Key('saveTireButton'));
    await tester.ensureVisible(saveTire);
    await tester.pumpAndSettle();
    await tester.tap(saveTire);
    await tester.pumpAndSettle();

    expect((await store.query('tires')), hasLength(1));
    expect(find.text('Michelin Pilot Sport 4S'), findsWidgets); // carte d'inventaire
    expect(find.text('Stock'), findsOneWidget); // pas encore monté

    // Monte le pneu en avant gauche.
    await tester.tap(find.text('AVG'));
    await tester.pumpAndSettle();
    expect(find.text('Position Avant gauche'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('mountOdometerField')), '10000');
    final mountBtn = find.byKey(const Key('mountConfirmButton'));
    await tester.ensureVisible(mountBtn);
    await tester.pumpAndSettle();
    await tester.tap(mountBtn);
    await tester.pumpAndSettle();

    // Un intervalle ouvert créé ; la pastille passe de « Stock » à « AVG ».
    expect((await store.query('tire_mounts')), hasLength(1));
    expect(find.text('Stock'), findsNothing);
    expect(find.text('AVG'), findsWidgets); // cellule + pastille d'inventaire

    // L'historique des changements s'ouvre et montre le montage.
    final histBtn = find.widgetWithText(OutlinedButton, 'Historique des changements');
    await tester.ensureVisible(histBtn);
    await tester.pumpAndSettle();
    await tester.tap(histBtn);
    await tester.pumpAndSettle();
    expect(find.text('Historique des pneus'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsWidgets); // au moins un « Monté »
  });

  testWidgets('l\'onglet Pressions porte les cibles & relevés (séparé de Pneus)', (tester) async {
    // Surface large : les 7 onglets tiennent, « Pressions » est visible.
    await tester.binding.setSurfaceSize(const Size(1400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (store, vehicleId) = await seed();
    await pumpDetail(tester, store, vehicleId);

    await tester.tap(find.text('Pressions'));
    await tester.pumpAndSettle();
    // Contenu pressions (déplacé hors de l'onglet Pneus).
    expect(find.text('Relevés'), findsOneWidget);
    expect(find.text('Définir une pression cible'), findsOneWidget);
    // L'inventaire reste sur l'onglet Pneus, pas ici.
    expect(find.text('Inventaire'), findsNothing);
  });

  testWidgets('mettre au rebut : sort de la monte (démontage auto) mais garde le pneu', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (store, vehicleId) = await seed();
    await pumpDetail(tester, store, vehicleId);

    await tester.tap(find.text('Pneus'));
    await tester.pumpAndSettle();

    // Ajoute un pneu puis le monte en AVG à 10 000 km.
    await tester.tap(find.widgetWithText(TextButton, 'Ajouter'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tireBrandField')), 'Michelin');
    final saveTire = find.byKey(const Key('saveTireButton'));
    await tester.ensureVisible(saveTire);
    await tester.pumpAndSettle();
    await tester.tap(saveTire);
    await tester.pumpAndSettle();

    await tester.tap(find.text('AVG'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('mountOdometerField')), '10000');
    final mountBtn = find.byKey(const Key('mountConfirmButton'));
    await tester.ensureVisible(mountBtn);
    await tester.pumpAndSettle();
    await tester.tap(mountBtn);
    await tester.pumpAndSettle();
    expect((await store.query('tire_mounts')), hasLength(1));

    // Ouvre la carte d'inventaire (2ᵉ occurrence : la 1ʳᵉ est la cellule de monte).
    await tester.tap(find.text('Michelin').last);
    await tester.pumpAndSettle();
    final disposeBtn = find.byKey(const Key('disposeTireButton'));
    await tester.ensureVisible(disposeBtn);
    await tester.pumpAndSettle();
    await tester.tap(disposeBtn);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Au rebut')); // confirme
    await tester.pumpAndSettle();

    // L'intervalle est fermé (démontage auto au km courant), le pneu conservé,
    // et il passe en « Au rebut ».
    final mounts = await store.query('tire_mounts');
    expect(mounts, hasLength(1));
    expect(mounts.first['dismounted_odometer'], 10000);
    expect((await store.query('tires')), hasLength(1)); // pas supprimé
    expect(find.text('Au rebut'), findsOneWidget); // pastille de la section rebut
  });
}
