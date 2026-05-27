import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/ui/pages/auth/phone_entry.page.dart';
import 'package:motorz/ui/theme/app_theme_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('la roue crantée de la page de connexion règle l\'URL du backend',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppThemeData.buildLightTheme(),
          home: const PhoneEntryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // La roue crantée est présente en haut à droite de l'écran de connexion.
    final gear = find.byTooltip('Configurer le serveur');
    expect(gear, findsOneWidget);

    // Elle ouvre le dialogue, pré-rempli avec l'URL courante (« memory » par défaut).
    await tester.tap(gear);
    await tester.pumpAndSettle();
    expect(find.text('Serveur'), findsOneWidget);
    expect(find.byKey(const Key('apiBaseUrlField')), findsOneWidget);
    expect(find.text('memory'), findsOneWidget);

    // Saisir une URL puis enregistrer met à jour le provider et ferme le dialogue.
    await tester.enterText(
        find.byKey(const Key('apiBaseUrlField')), 'https://motorz.dtfh.fr');
    await tester.tap(find.byKey(const Key('saveApiBaseUrlButton')));
    await tester.pumpAndSettle();

    expect(container.read(apiBaseUrlProvider), 'https://motorz.dtfh.fr');
    expect(find.byKey(const Key('apiBaseUrlField')), findsNothing);
    expect(find.text('Serveur enregistré.'), findsOneWidget);

    // Laisse le SnackBar expirer pour ne pas laisser de Timer pendant le teardown.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
