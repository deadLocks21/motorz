import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:motorz/core/application/sync/entity_codecs.dart';
import 'package:motorz/core/domain/model/cost_entry.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/ownership.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/model/vehicle.dart';
import 'package:motorz/core/domain/services/connectivity.service.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/ui/pages/finances/finances.page.dart';
import 'package:motorz/ui/theme/app_theme_data.dart';
import 'package:motorz/ui/utils/format.dart';

/// Écran Finances (§5.2) : coût d'usage et coût total de possession présentés
/// séparément, et frais récurrents saisis une seule fois avec leur périodicité.
class _OfflineConnectivity implements ConnectivityService {
  const _OfflineConnectivity();
  @override
  bool get isOnline => false;
  @override
  Stream<bool> watch() => Stream<bool>.value(false);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // Les montants affichés dépendent du temps écoulé depuis l'acquisition : on
  // ancre le véhicule un an en arrière, en dates relatives, pour que le test ne
  // pourrisse pas avec le calendrier.
  final acquired = DateTime.now().toUtc().subtract(const Duration(days: 365));

  Future<(InMemoryLocalRecordStore, UuidValue)> seed({bool withInsurance = true}) async {
    final store = InMemoryLocalRecordStore();
    final vehicleId = UuidValue.generate();
    await store.put(
      'vehicles',
      vehicleCodec.toJson(Vehicle(
        id: vehicleId,
        ownerUserId: UuidValue.generate(),
        type: VehicleType.voiture,
        nickname: 'La 308',
        updatedAt: acquired,
      )),
    );
    await store.put(
      'vehicle_ownerships',
      ownershipCodec.toJson(Ownership(
        id: UuidValue.generate(),
        vehicleId: vehicleId,
        acquiredDate: acquired.toIso8601String().substring(0, 10),
        acquiredOdometer: 100000,
        purchasePrice: 18000,
        isCurrent: true,
        updatedAt: acquired,
      )),
    );
    if (withInsurance) {
      await store.put(
        'cost_entries',
        costEntryCodec.toJson(CostEntry(
          id: UuidValue.generate(),
          vehicleId: vehicleId,
          label: 'Assurance tous risques',
          category: 'assurance',
          amount: 1200,
          recurrence: CostRecurrence.annuel,
          date: acquired,
          updatedAt: acquired,
        )),
      );
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
          home: FinancesPage(vehicleId: vehicleId.value),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('le prix d\'achat vit dans le coût total, pas dans le coût d\'usage',
      (tester) async {
    final (store, vehicleId) = await seed();
    await open(tester, store, vehicleId);

    expect(find.text('Coût d\'usage'), findsWidgets);
    expect(find.text('Coût total de possession'), findsOneWidget);
    // 18 000 € d'achat : visible dans le bloc possession, absent du coût
    // d'usage — dont le total reste celui de la seule assurance courue.
    expect(find.text('Prix d\'achat'), findsOneWidget);
    expect(find.text(formatEur(18000)), findsOneWidget);
    expect(find.text(formatEur(18000 + 1200)), findsNothing,
        reason: 'le coût d\'usage ne doit jamais absorber le prix d\'achat');
  });

  testWidgets('une prime annuelle se lit telle quelle et donne la charge fixe mensuelle',
      (tester) async {
    final (store, vehicleId) = await seed();
    await open(tester, store, vehicleId);

    // Le montant reste affiché dans l'unité saisie…
    expect(find.text('${formatEur(1200)}/an'), findsOneWidget);
    // …et l'équivalent mensuel est dérivé, sans dépendre de la date du jour.
    expect(find.text('Charge fixe actuelle : ${formatEur(100)} par mois'), findsOneWidget);
  });

  testWidgets('sans frais récurrent, l\'écran invite à en saisir un', (tester) async {
    final (store, vehicleId) = await seed(withInsurance: false);
    await open(tester, store, vehicleId);

    expect(find.textContaining('Saisis ton assurance une bonne fois'), findsOneWidget);
    expect(find.textContaining('Charge fixe actuelle'), findsNothing);
  });

  testWidgets('saisir un frais mensuel l\'enregistre avec sa périodicité', (tester) async {
    final (store, vehicleId) = await seed(withInsurance: false);
    await open(tester, store, vehicleId);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('costLabelField')), 'Parking résidentiel');
    await tester.enterText(find.byKey(const Key('costAmountField')), '65');
    await tester.tap(find.byKey(const Key('costRecurrenceField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Par mois').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveCostButton')));
    await tester.pumpAndSettle();

    final rows = await store.query('cost_entries');
    final added = rows.firstWhere((r) => r['label'] == 'Parking résidentiel');
    expect(added['recurrence'], 'mensuel');
    expect(added['amount'], 65);
    // Une charge en cours n'a pas de fin : c'est ce qui la rend perpétuelle.
    expect(added['end_date'], isNull);
  });

  testWidgets('un frais ponctuel n\'expose ni date de fin ni charge fixe', (tester) async {
    final (store, vehicleId) = await seed(withInsurance: false);
    await open(tester, store, vehicleId);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('costRecurrenceField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ponctuel').last);
    await tester.pumpAndSettle();

    expect(find.text('Jusqu\'au'), findsNothing);
    expect(find.text('Date'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('costLabelField')), 'Franchise sinistre');
    await tester.enterText(find.byKey(const Key('costAmountField')), '350');
    await tester.tap(find.byKey(const Key('saveCostButton')));
    await tester.pumpAndSettle();

    final rows = await store.query('cost_entries');
    final added = rows.firstWhere((r) => r['label'] == 'Franchise sinistre');
    expect(added['recurrence'], 'ponctuel');
    // Il atterrit dans la liste, en bas de page (d'où le défilement), et sans
    // suffixe de périodicité : un versement unique ne se lit pas « /mois ».
    await tester.scrollUntilVisible(find.text('Franchise sinistre'), 200);
    expect(find.text(formatEur(350)), findsWidgets);
    expect(find.textContaining('350,00 €/'), findsNothing);
  });

  testWidgets('toucher un frais rouvre la feuille pré-remplie pour le corriger',
      (tester) async {
    final (store, vehicleId) = await seed();
    await open(tester, store, vehicleId);

    await tester.tap(find.text('Assurance tous risques'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier la dépense'), findsOneWidget);
    final amount = tester.widget<TextField>(find.byKey(const Key('costAmountField')));
    expect(amount.controller!.text, '1200,0');

    // La prime augmente : on corrige la ligne au lieu d'en empiler une seconde.
    await tester.enterText(find.byKey(const Key('costAmountField')), '1400');
    await tester.tap(find.byKey(const Key('saveCostButton')));
    await tester.pumpAndSettle();

    final rows = await store.query('cost_entries');
    expect(rows.where((r) => r['deleted_at'] == null).length, 1);
    expect(rows.single['amount'], 1400);
  });
}
