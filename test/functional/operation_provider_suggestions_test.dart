import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:motorz/core/application/sync/entity_codecs.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/maintenance_operation.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/model/vehicle.dart';
import 'package:motorz/core/domain/services/connectivity.service.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/ui/pages/vehicle_detail/vehicle_detail.page.dart';
import 'package:motorz/ui/theme/app_theme_data.dart';

/// Le champ « Prestataire » d'une opération d'entretien propose les prestataires
/// déjà saisis (autocomplétion) tout en laissant taper un prestataire inédit —
/// même comportement que le champ « Station » d'un plein.
class _OfflineConnectivity implements ConnectivityService {
  const _OfflineConnectivity();
  @override
  bool get isOnline => false;
  @override
  Stream<bool> watch() => Stream<bool>.value(false);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// Véhicule avec deux opérations chez des prestataires différents → deux suggestions.
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
    for (final (i, provider) in ['Norauto', 'Speedy'].indexed) {
      await store.put(
        'maintenance_operations',
        operationCodec.toJson(Operation(
          id: UuidValue.generate(),
          vehicleId: vehicleId,
          date: DateTime.utc(2026, 5, 10 + i, 12),
          odometer: 100000 + i * 500,
          provider: provider,
          updatedAt: DateTime.utc(2026, 5, 10 + i),
        )),
      );
    }
    return (store, vehicleId);
  }

  Future<void> openNewOperationSheet(
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
    await tester.tap(find.text('Entretien')); // le FAB n'existe que hors onglet « Vue d'ensemble »
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detailFab')));
    await tester.pumpAndSettle();
    expect(find.text('Entretien réalisé'), findsOneWidget);
    // Le champ n'existe que hors DIY, et « Fait par moi-même » est actif par défaut.
    await tester.tap(find.byKey(const Key('operationDiySwitch')));
    await tester.pumpAndSettle();
  }

  /// Renseigne le km et un poste pour qu'une opération soit enregistrable.
  Future<void> fillRequiredFields(WidgetTester tester, {required String km}) async {
    await tester.enterText(find.byKey(const Key('operationOdometerField')), km);
    await tester.enterText(find.widgetWithText(TextField, 'Pièce'), 'Vidange');
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('saveOperationButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveOperationButton')));
    await tester.pumpAndSettle();
  }

  testWidgets('le champ prestataire devient une liste déroulante quand des prestataires existent',
      (tester) async {
    final (store, vehicleId) = await seed();
    await openNewOperationSheet(tester, store, vehicleId);

    // Affordance de liste déroulante (chevron) sur le champ prestataire.
    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
  });

  testWidgets('le champ prestataire est vide à l\'ouverture (pas de préremplissage auto)',
      (tester) async {
    final (store, vehicleId) = await seed();
    await openNewOperationSheet(tester, store, vehicleId);

    // Même avec des opérations existantes, on n'impose pas le dernier prestataire :
    // le champ s'ouvre vide, à compléter via la liste déroulante.
    final field = tester.widget<TextField>(find.byKey(const Key('operationProviderField')));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('taper filtre les suggestions ; sélectionner pré-remplit le prestataire',
      (tester) async {
    final (store, vehicleId) = await seed();
    await openNewOperationSheet(tester, store, vehicleId);

    // « nor » ne doit proposer que « Norauto » (« Speedy » est filtré).
    await tester.enterText(find.byKey(const Key('operationProviderField')), 'nor');
    await tester.pumpAndSettle();
    expect(find.text('Norauto'), findsOneWidget);
    expect(find.text('Speedy'), findsNothing);

    // Sélectionner la suggestion remplit le champ, puis on enregistre l'opération.
    await tester.tap(find.text('Norauto'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byKey(const Key('operationProviderField')));
    expect(field.controller!.text, 'Norauto');

    await fillRequiredFields(tester, km: '123456');
    await tapSave(tester);

    final rows = await store.query('maintenance_operations');
    final added = rows.firstWhere((r) => (r['odometer'] as num?)?.toInt() == 123456);
    expect(added['provider'], 'Norauto');
  });

  testWidgets('un prestataire inédit reste saisissable (pas imposé par la liste)',
      (tester) async {
    final (store, vehicleId) = await seed();
    await openNewOperationSheet(tester, store, vehicleId);

    // On tape un prestataire qui n'existe pas encore : aucune suggestion ne doit
    // l'écraser, il est enregistré tel quel.
    await tester.enterText(find.byKey(const Key('operationProviderField')), 'Feu Vert');
    await tester.pumpAndSettle();
    await fillRequiredFields(tester, km: '123456');
    await tapSave(tester);

    final rows = await store.query('maintenance_operations');
    final added = rows.firstWhere((r) => (r['odometer'] as num?)?.toInt() == 123456);
    expect(added['provider'], 'Feu Vert');
  });

  testWidgets('« Fait par moi-même » masque le prestataire et marque l\'opération DIY',
      (tester) async {
    final (store, vehicleId) = await seed();
    await openNewOperationSheet(tester, store, vehicleId);

    // openNewOperationSheet a désactivé le DIY pour révéler le champ : on le
    // remet, le champ disparaît et rien ne reste à saisir côté prestataire.
    await tester.tap(find.byKey(const Key('operationDiySwitch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('operationProviderField')), findsNothing);

    await fillRequiredFields(tester, km: '123456');
    await tapSave(tester);

    final rows = await store.query('maintenance_operations');
    final added = rows.firstWhere((r) => (r['odometer'] as num?)?.toInt() == 123456);
    expect(added['is_diy'], isTrue);
    expect(added['provider'], isNull);
  });

  testWidgets('hors DIY, le prestataire est obligatoire', (tester) async {
    final (store, vehicleId) = await seed();
    await openNewOperationSheet(tester, store, vehicleId); // DIY désactivé

    await fillRequiredFields(tester, km: '123456');
    await tapSave(tester);

    expect(find.text('Indique le prestataire.'), findsOneWidget);
    final rows = await store.query('maintenance_operations');
    expect(rows.where((r) => (r['odometer'] as num?)?.toInt() == 123456), isEmpty);
  });
}
