import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:motorz/core/application/sync/entity_codecs.dart';
import 'package:motorz/core/domain/model/diagnostic_session.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/model/vehicle.dart';
import 'package:motorz/core/domain/services/connectivity.service.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/ui/pages/vehicle_detail/vehicle_detail.page.dart';
import 'package:motorz/ui/theme/app_theme_data.dart';

/// Parcours de l'onglet *Diagnostics* (§5.11) : coller un rapport de valise,
/// l'analyser, et retrouver 3 défauts — pas 15 — malgré la répétition du même
/// trio sur plusieurs calculateurs.
class _OfflineConnectivity implements ConnectivityService {
  const _OfflineConnectivity();
  @override
  bool get isOnline => false;
  @override
  Stream<bool> watch() => Stream<bool>.value(false);
}

const _report = '''
Car Scanner ELM OBD2
Version: 1.118.0/401180/GP
DTC report
Connection profile: Citroen OBD-II / EOBDDate: 28/05/2025 20:20:20
============================
OBD-IIOBD-II
DTCs: 3
----------------------------
P2291 [0x2291]
Injector control pressure, engine cranking - pressure too low
Statut: En attente de défaut présent
----------------------------
P0017 [0x0017]
Crankshaft position/camshaft position, bank 1 sensor B - correlation
Statut: En attente de défaut présent
----------------------------
P050B [0x050B]
Ignition timing, cold start - performance problem
Statut: En attente de défaut présent
============================
Unité de contrôle moteur#1Unité de contrôle moteur#1
DTCs: 3
----------------------------
P2291 [0x2291]
Injector control pressure, engine cranking - pressure too low
Statut: En attente de défaut présent
----------------------------
P0017 [0x0017]
Crankshaft position/camshaft position, bank 1 sensor B - correlation
Statut: En attente de défaut présent
----------------------------
P050B [0x050B]
Ignition timing, cold start - performance problem
Statut: En attente de défaut présent
============================
ABS
Aucun code défaut détecté.
''';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<(InMemoryLocalRecordStore, String)> seed() async {
    final store = InMemoryLocalRecordStore();
    final vehicleId = UuidValue.generate();
    await store.put(
      'vehicles',
      vehicleCodec.toJson(Vehicle(
        id: vehicleId,
        ownerUserId: UuidValue.generate(),
        type: VehicleType.voiture,
        nickname: 'La 308',
        updatedAt: DateTime.utc(2026, 3, 7),
      )),
    );
    return (store, vehicleId.value);
  }

  Future<void> pumpVehicle(
      WidgetTester tester, InMemoryLocalRecordStore store, String vehicleId) async {
    // Large : la fiche véhicule a huit onglets scrollables, et « Diagnostics »
    // tombe hors écran sur une surface étroite.
    await tester.binding.setSurfaceSize(const Size(1500, 1800));
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
          home: VehicleDetailPage(vehicleId: vehicleId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diagnostics'));
    await tester.pumpAndSettle();
  }

  testWidgets('coller un rapport de valise : 3 défauts enregistrés, pas 15', (tester) async {
    final (store, vehicleId) = await seed();
    await pumpVehicle(tester, store, vehicleId);
    expect(find.textContaining('Aucun diagnostic'), findsOneWidget);

    await tester.tap(find.byKey(const Key('detailFab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('diagnosticReportField')), _report);
    await tester.tap(find.byKey(const Key('analyzeReportButton')));
    await tester.pumpAndSettle();

    // L'analyse pré-remplit et annonce ce qu'elle a compris, avant validation.
    expect(find.textContaining('3 défauts'), findsWidgets);
    expect(find.text('P2291'), findsOneWidget);

    await tester.tap(find.byKey(const Key('saveDiagnosticButton')));
    await tester.pumpAndSettle();

    final sessions =
        (await store.query('diagnostic_sessions')).map(diagnosticSessionCodec.fromJson).toList();
    expect(sessions, hasLength(1));
    final session = sessions.single;
    expect(session.tool, 'Car Scanner ELM OBD2 1.118.0');
    expect(session.connectionProfile, 'Citroen OBD-II / EOBD');
    // La date vient du rapport, pas du jour de la saisie (l'heure du rapport est
    // lue en heure locale puis stockée en UTC, comme toute date synchronisée).
    expect(session.date, DateTime(2025, 5, 28, 20, 20, 20).toUtc());
    // Le rapport brut est conservé pour une ré-analyse ultérieure.
    expect(session.rawText, contains('P050B'));
    // Le calculateur sans défaut compte aussi : c'est lui qui permettra de dire
    // qu'un code a disparu plutôt que « pas revérifié ».
    expect(session.modulesScanned, contains('ABS'));
    expect(session.analyzedAt, isNotNull);

    final codes =
        (await store.query('diagnostic_codes')).map(diagnosticCodeCodec.fromJson).toList();
    // Fidèle au rapport : 3 codes × 2 calculateurs.
    expect(codes, hasLength(6));
    expect(codes.map((c) => c.code).toSet(), {'P2291', 'P0017', 'P050B'});

    // …mais la liste n'affiche que 3 défauts.
    expect(find.textContaining('3 défauts'), findsWidgets);
  });

  testWidgets('le lien d\'un testeur de batterie est décodé sur l\'appareil', (tester) async {
    final (store, vehicleId) = await seed();
    await pumpVehicle(tester, store, vehicleId);

    await tester.tap(find.byKey(const Key('detailFab')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batterie'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('batteryLinkField')),
      'https://e.dh5z.com/?d=10760127308670110010000337200000000000000000000000041',
    );
    await tester.tap(find.byKey(const Key('decodeLinkButton')));
    await tester.pumpAndSettle();

    // Les mesures décodées sont montrées avant enregistrement.
    expect(find.text('12.73 V'), findsOneWidget);
    expect(find.text('867 A'), findsOneWidget);

    await tester.tap(find.byKey(const Key('saveDiagnosticButton')));
    await tester.pumpAndSettle();

    final session = (await store.query('diagnostic_sessions'))
        .map(diagnosticSessionCodec.fromJson)
        .single;
    expect(session.type, DiagnosticType.battery);
    expect(session.source, DiagnosticSource.link);
    expect(session.summary, 'Bonne batterie');
    // Les mesures vivent dans le carnet, pas seulement dans l'URL.
    expect(session.measurements?['voltage'], 12.73);
    expect(session.measurements?['soh'], 100);
    expect(session.sourceUrl, contains('e.dh5z.com'));
  });
}
