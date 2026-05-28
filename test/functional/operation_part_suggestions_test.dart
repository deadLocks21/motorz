import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:motorz/core/application/sync/entity_codecs.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/maintenance_plan.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/model/vehicle.dart';
import 'package:motorz/core/domain/services/connectivity.service.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/ui/pages/vehicle_detail/vehicle_detail.page.dart';
import 'package:motorz/ui/theme/app_theme_data.dart';

/// Le champ « Pièce » d'une ligne d'entretien propose les échéances « À prévoir »
/// (autocomplétion) tout en laissant taper un poste inédit — même comportement
/// que le champ « Station » d'un plein, mais alimenté par les échéances en attente.
class _OfflineConnectivity implements ConnectivityService {
  const _OfflineConnectivity();
  @override
  bool get isOnline => false;
  @override
  Stream<bool> watch() => Stream<bool>.value(false);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// Véhicule avec deux échéances « À prévoir » (sans déclencheur → « à réaliser »)
  /// → deux suggestions pour le champ « Pièce ».
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
    for (final (i, title) in ['Vidange', 'Plaquettes'].indexed) {
      await store.put(
        'maintenance_plans',
        planCodec.toJson(Plan(
          id: UuidValue.generate(),
          vehicleId: vehicleId,
          title: title,
          updatedAt: DateTime.utc(2026, 5, 1 + i),
        )),
      );
    }
    return (store, vehicleId);
  }

  Future<void> openNewOperationSheet(
      WidgetTester tester, InMemoryLocalRecordStore store, UuidValue vehicleId) async {
    // Fenêtre haute : la feuille tient en entier (bouton « Enregistrer » visible
    // sans dépendre du scroll/du champ ayant le focus avant l'enregistrement).
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('saveOperationButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveOperationButton')));
    await tester.pumpAndSettle();
  }

  /// Le libellé de la ligne enregistrée (premier poste) de l'opération au km donné.
  Future<String?> savedLineLabel(InMemoryLocalRecordStore store, int km) async {
    final ops = await store.query('maintenance_operations');
    final op = ops.firstWhere((r) => (r['odometer'] as num?)?.toInt() == km);
    final lines = await store.query('maintenance_operation_lines');
    final line = lines.firstWhere((l) => l['operation_id'] == op['id']);
    return line['label'] as String?;
  }

  testWidgets('le champ pièce devient une liste déroulante quand des échéances existent',
      (tester) async {
    final (store, vehicleId) = await seed();
    await openNewOperationSheet(tester, store, vehicleId);

    // Aucune opération seedée → pas de prestataire connu, donc le seul chevron
    // visible est celui du champ « Pièce » (alimenté par les échéances).
    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
  });

  testWidgets('taper filtre les suggestions ; sélectionner pré-remplit la pièce',
      (tester) async {
    final (store, vehicleId) = await seed();
    await openNewOperationSheet(tester, store, vehicleId);

    // « vid » ne doit proposer que « Vidange » (« Plaquettes » est filtré).
    await tester.enterText(find.widgetWithText(TextField, 'Pièce'), 'vid');
    await tester.pumpAndSettle();
    expect(find.text('Vidange'), findsOneWidget);
    expect(find.text('Plaquettes'), findsNothing);

    // Sélectionner la suggestion remplit le champ, puis on enregistre l'opération.
    await tester.tap(find.text('Vidange'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.widgetWithText(TextField, 'Pièce'));
    expect(field.controller!.text, 'Vidange');

    await tester.enterText(find.byKey(const Key('operationOdometerField')), '123456');
    await tapSave(tester);

    expect(await savedLineLabel(store, 123456), 'Vidange');
  });

  testWidgets('un poste inédit reste saisissable (pas imposé par la liste)', (tester) async {
    final (store, vehicleId) = await seed();
    await openNewOperationSheet(tester, store, vehicleId);

    // On tape un poste qui n'est pas une échéance : aucune suggestion ne l'écrase.
    await tester.enterText(find.widgetWithText(TextField, 'Pièce'), 'Filtre à air');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('operationOdometerField')), '123456');
    await tapSave(tester);

    expect(await savedLineLabel(store, 123456), 'Filtre à air');
  });
}
