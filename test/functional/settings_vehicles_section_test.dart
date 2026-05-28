import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:motorz/core/domain/model/device.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/session.dart';
import 'package:motorz/core/domain/model/user.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/model/vehicle.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/ui/pages/settings/widgets/vehicles_section.widget.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/theme/app_theme_data.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final myId = UuidValue.generate();
  Session sessionFor(UuidValue userId) => Session(
        jwt: 'jwt',
        user: User(id: userId, firstName: 'Tim', lastName: 'H', phoneNumber: '+33612345678'),
        device: const Device(id: 'dev'),
      );
  Vehicle vehicleOwnedBy(UuidValue ownerId) => Vehicle(
        id: UuidValue.generate(),
        ownerUserId: ownerId,
        type: VehicleType.voiture,
        nickname: 'La 308',
        make: 'Peugeot',
        updatedAt: DateTime.utc(2026, 5, 1),
      );

  Future<void> pumpSection(WidgetTester tester, {required List<Vehicle> vehicles}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vehiclesProvider.overrideWith((ref) async => vehicles),
          currentSessionProvider.overrideWithValue(sessionFor(myId)),
        ],
        child: MaterialApp(
          theme: AppThemeData.buildLightTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(padding: EdgeInsets.all(16), child: VehiclesSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('liste les véhicules et propose Ajouter / Rejoindre', (tester) async {
    await pumpSection(tester, vehicles: [vehicleOwnedBy(myId)]);

    expect(find.text('Véhicules'), findsOneWidget);
    expect(find.text('La 308'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Ajouter'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Rejoindre'), findsOneWidget);
  });

  testWidgets('un véhicule possédé expose les trois boutons en ligne', (tester) async {
    await pumpSection(tester, vehicles: [vehicleOwnedBy(myId)]);

    expect(find.widgetWithText(TextButton, 'Modifier'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Partager'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Supprimer'), findsOneWidget);
  });

  testWidgets('un véhicule partagé n\'expose que Modifier', (tester) async {
    final otherOwner = UuidValue.generate();
    await pumpSection(tester, vehicles: [vehicleOwnedBy(otherOwner)]);

    // Marqué comme partagé dans la liste.
    expect(find.textContaining('Partagé'), findsOneWidget);

    expect(find.widgetWithText(TextButton, 'Modifier'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Partager'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Supprimer'), findsNothing);
  });

  testWidgets('le bouton Supprimer demande confirmation', (tester) async {
    await pumpSection(tester, vehicles: [vehicleOwnedBy(myId)]);

    await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer le véhicule ?'), findsOneWidget);
  });

  testWidgets('sous un viewport étroit, seules les icônes restent (tooltips)', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpSection(tester, vehicles: [vehicleOwnedBy(myId)]);

    // Plus de libellés...
    expect(find.text('Modifier'), findsNothing);
    expect(find.text('Partager'), findsNothing);
    expect(find.text('Supprimer'), findsNothing);
    // ...mais les trois actions restent accessibles en icônes.
    expect(find.byTooltip('Modifier'), findsOneWidget);
    expect(find.byTooltip('Partager'), findsOneWidget);
    expect(find.byTooltip('Supprimer'), findsOneWidget);
  });
}
