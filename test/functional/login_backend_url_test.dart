import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:motorz/infrastructure/http/api_endpoint_probe.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/ui/pages/auth/phone_entry.page.dart';
import 'package:motorz/ui/theme/app_theme_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sondeur bouchonné : chaque base a un verdict décidé d'avance, aucune requête
/// ne part. Les bases absentes de [_verdicts] sont réputées injoignables.
class _FakeProbe extends ApiEndpointProbe {
  _FakeProbe(this._verdicts);

  final Map<String, ApiEndpointStatus> _verdicts;

  @override
  Future<ApiEndpointStatus> probe(String baseUrl) async =>
      _verdicts[baseUrl] ?? ApiEndpointStatus.unreachable;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Ouvre la page de connexion, saisit [url] dans le dialogue de serveur et
  /// enregistre. Renvoie le conteneur pour inspecter l'URL retenue.
  Future<ProviderContainer> saveUrl(
    WidgetTester tester,
    String url, {
    required Map<String, ApiEndpointStatus> verdicts,
  }) async {
    final container = ProviderContainer(overrides: [
      apiEndpointProbeProvider.overrideWithValue(_FakeProbe(verdicts)),
    ]);
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

    await tester.tap(find.byTooltip('Configurer le serveur'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('apiBaseUrlField')), url);
    await tester.tap(find.byKey(const Key('saveApiBaseUrlButton')));
    await tester.pumpAndSettle();
    return container;
  }

  /// Laisse le SnackBar expirer pour ne pas laisser de Timer au teardown.
  Future<void> letSnackBarExpire(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('la roue crantée de la page de connexion règle l\'URL du backend',
      (tester) async {
    final container = await saveUrl(
      tester,
      'https://motorz.dtfh.fr/api',
      verdicts: {'https://motorz.dtfh.fr/api': ApiEndpointStatus.reachable},
    );

    expect(container.read(apiBaseUrlProvider), 'https://motorz.dtfh.fr/api');
    expect(find.byKey(const Key('apiBaseUrlField')), findsNothing);
    expect(find.text('Serveur enregistré.'), findsOneWidget);

    await letSnackBarExpire(tester);
  });

  testWidgets('l\'hôte nu est corrigé tout seul quand l\'API répond sous /api',
      (tester) async {
    // Le cas qui a réellement cassé : l'URL vise le bon hôte, mais le client
    // web y répond en catch-all depuis que l'API est passée derrière /api.
    final container = await saveUrl(
      tester,
      'https://motorz.dtfh.fr',
      verdicts: {
        'https://motorz.dtfh.fr': ApiEndpointStatus.notApi,
        'https://motorz.dtfh.fr/api': ApiEndpointStatus.reachable,
      },
    );

    expect(container.read(apiBaseUrlProvider), 'https://motorz.dtfh.fr/api');
    expect(
      find.text('Serveur enregistré : l\'API répond sur https://motorz.dtfh.fr/api.'),
      findsOneWidget,
    );

    await letSnackBarExpire(tester);
  });

  testWidgets('un serveur muet s\'enregistre quand même, mais le dit',
      (tester) async {
    // Configurer un backend momentanément éteint reste légitime : on informe,
    // on ne bloque pas.
    final container = await saveUrl(tester, 'https://absent.example', verdicts: {});

    expect(container.read(apiBaseUrlProvider), 'https://absent.example');
    expect(find.text('Enregistré, mais ce serveur est injoignable.'), findsOneWidget);

    await letSnackBarExpire(tester);
  });

  testWidgets('un hôte qui répond sans être l\'API est signalé comme tel',
      (tester) async {
    final container = await saveUrl(
      tester,
      'https://example.com',
      verdicts: {'https://example.com': ApiEndpointStatus.notApi},
    );

    expect(container.read(apiBaseUrlProvider), 'https://example.com');
    expect(
      find.text('Enregistré, mais ce serveur ne répond pas comme l\'API Motorz.'),
      findsOneWidget,
    );

    await letSnackBarExpire(tester);
  });

  testWidgets('« memory » est enregistré sans sonder quoi que ce soit',
      (tester) async {
    final container = await saveUrl(tester, 'memory', verdicts: {});

    expect(container.read(apiBaseUrlProvider), 'memory');
    expect(find.text('Mode local activé.'), findsOneWidget);

    await letSnackBarExpire(tester);
  });
}
