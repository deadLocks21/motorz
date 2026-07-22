import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:motorz/core/application/sync/entity_codecs.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/maintenance_operation.dart';
import 'package:motorz/core/domain/model/maintenance_operation_line.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/model/vehicle.dart';
import 'package:motorz/core/domain/services/connectivity.service.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/ui/pages/maintenance_detail/maintenance_detail.page.dart';
import 'package:motorz/ui/theme/app_theme_data.dart';

/// Devis comparatifs d'une opération (§5.5) : un devis saisi compte, le choix du
/// devis retenu n'apparaît qu'à partir de deux.
class _OfflineConnectivity implements ConnectivityService {
  const _OfflineConnectivity();
  @override
  bool get isOnline => false;
  @override
  Stream<bool> watch() => Stream<bool>.value(false);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// Opération faite soi-même à 85 € (deux postes), sans devis.
  Future<(InMemoryLocalRecordStore, Operation)> seed() async {
    final store = InMemoryLocalRecordStore();
    final vehicleId = UuidValue.generate();
    final at = DateTime.utc(2026, 3, 7);
    await store.put(
      'vehicles',
      vehicleCodec.toJson(Vehicle(
        id: vehicleId,
        ownerUserId: UuidValue.generate(),
        type: VehicleType.voiture,
        nickname: 'La 308',
        make: 'Peugeot',
        updatedAt: at,
      )),
    );
    final operation = Operation(
      id: UuidValue.generate(),
      vehicleId: vehicleId,
      date: at,
      odometer: 11800,
      isDiy: true,
      updatedAt: at,
    );
    await store.put('maintenance_operations', operationCodec.toJson(operation));
    await store.put(
      'maintenance_operation_lines',
      operationLineCodec.toJson(OperationLine(
        id: UuidValue.generate(),
        operationId: operation.id,
        label: 'Filtre à air',
        partsCost: 85,
        updatedAt: at,
      )),
    );
    return (store, operation);
  }

  Future<void> pumpDetail(
      WidgetTester tester, InMemoryLocalRecordStore store, Operation operation) async {
    // Feuille de devis + documents : la surface par défaut (800×600) tronquerait
    // le bouton d'enregistrement.
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
          home: MaintenanceOperationDetailPage(operation: operation),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Saisit un devis via la feuille (prestataire + montant, tous deux requis).
  Future<void> addQuote(WidgetTester tester, String provider, String amount) async {
    await tester.tap(find.byKey(const Key('addQuoteButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quoteProviderField')), provider);
    await tester.enterText(find.byKey(const Key('quoteAmountField')), amount);
    await tester.tap(find.byKey(const Key('saveQuoteButton')));
    await tester.pumpAndSettle();
  }

  testWidgets('un seul devis : pas de choix à faire, et l\'économie est affichée',
      (tester) async {
    final (store, operation) = await seed();
    await pumpDetail(tester, store, operation);
    expect(find.textContaining('Aucun devis'), findsOneWidget);

    await addQuote(tester, 'Speedy', '210');

    final quotes = (await store.query('maintenance_quotes'))
        .map(maintenanceQuoteCodec.fromJson)
        .toList();
    expect(quotes, hasLength(1));
    expect(quotes.single.provider, 'Speedy');
    expect(quotes.single.amount, 210);
    expect(quotes.single.isSelected, isTrue, reason: 'le premier devis fait référence d\'office');

    // Un seul devis : aucun sélecteur, et l'effet est écrit noir sur blanc.
    expect(find.byType(Radio<String>), findsNothing);
    expect(find.textContaining('Économie de'), findsOneWidget);
  });

  testWidgets('deux devis : le sélecteur apparaît et désigne celui qui compte',
      (tester) async {
    final (store, operation) = await seed();
    await pumpDetail(tester, store, operation);

    await addQuote(tester, 'Speedy', '210');
    expect(find.byType(Radio<String>), findsNothing);

    await addQuote(tester, 'Ford Store', '280');
    expect(find.byType(Radio<String>), findsNWidgets(2));

    // Le second devis prend la référence quand on le coche.
    await tester.tap(find.byType(Radio<String>).last);
    await tester.pumpAndSettle();

    final quotes = (await store.query('maintenance_quotes'))
        .map(maintenanceQuoteCodec.fromJson)
        .toList();
    final retained = quotes.singleWhere((q) => q.isSelected);
    expect(retained.provider, 'Ford Store');
  });

  testWidgets('prestataire et montant sont tous deux requis', (tester) async {
    final (store, operation) = await seed();
    await pumpDetail(tester, store, operation);

    await tester.tap(find.byKey(const Key('addQuoteButton')));
    await tester.pumpAndSettle();

    // Montant seul : refusé.
    await tester.enterText(find.byKey(const Key('quoteAmountField')), '210');
    await tester.tap(find.byKey(const Key('saveQuoteButton')));
    await tester.pumpAndSettle();
    expect(find.text('Indique le prestataire (garage).'), findsOneWidget);

    // Laisser expirer le premier message : les SnackBars s'empilent, le suivant
    // n'apparaîtrait pas tant que celui-ci est à l'écran.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Prestataire seul : refusé aussi.
    await tester.enterText(find.byKey(const Key('quoteProviderField')), 'Speedy');
    await tester.enterText(find.byKey(const Key('quoteAmountField')), '');
    await tester.tap(find.byKey(const Key('saveQuoteButton')));
    await tester.pumpAndSettle();
    expect(find.text('Indique le montant du devis.'), findsOneWidget);

    expect(await store.query('maintenance_quotes'), isEmpty);
  });
}
