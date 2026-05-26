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
import 'package:motorz/infrastructure/connectivity/connectivity_plus.service.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/ui/pages/garage/garage.page.dart';
import 'package:motorz/ui/theme/app_theme_data.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('le garage affiche mes véhicules', (tester) async {
    final userId = UuidValue.generate();
    final session = Session(
      jwt: 'jwt',
      user: User(id: userId, firstName: 'Tim', lastName: 'H', phoneNumber: '+33612345678'),
      device: const Device(id: 'dev'),
    );
    final vehicle = Vehicle(
      id: UuidValue.generate(),
      ownerUserId: userId,
      type: VehicleType.voiture,
      nickname: 'La 308',
      make: 'Peugeot',
      updatedAt: DateTime.utc(2026, 5, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vehiclesProvider.overrideWith((ref) async => [vehicle]),
          currentSessionProvider.overrideWithValue(session),
          connectivityServiceProvider.overrideWithValue(const AlwaysOnlineConnectivityService()),
        ],
        child: MaterialApp(
          theme: AppThemeData.buildLightTheme(),
          home: const GaragePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('La 308'), findsOneWidget);
    expect(find.text('MES VÉHICULES'), findsOneWidget);
    expect(find.byKey(Key('vehicleCard_${vehicle.id.value}')), findsOneWidget);
  });

  testWidgets('garage vide affiche un état vide', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vehiclesProvider.overrideWith((ref) async => []),
          currentSessionProvider.overrideWithValue(null),
          connectivityServiceProvider.overrideWithValue(const AlwaysOnlineConnectivityService()),
        ],
        child: MaterialApp(
          theme: AppThemeData.buildLightTheme(),
          home: const GaragePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ton garage est vide'), findsOneWidget);
  });
}
