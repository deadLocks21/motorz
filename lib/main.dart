import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/application/services/logger_application.service.dart';
import 'package:motorz/core/domain/model/app_theme_mode.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/logger_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/infrastructure/providers/theme_providers.dart';
import 'package:motorz/infrastructure/sync/local_database.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/infrastructure/sync/pending_queue.dart';
import 'package:motorz/infrastructure/sync/rejected_op_store.dart';
import 'package:motorz/ui/router/app_router.dart';
import 'package:motorz/ui/theme/app_theme_data.dart';
import 'package:motorz/updating_splash.dart';

Future<void> main(List<String> args) async {
  // Mode « fenêtre de mise à jour » : l'updater desktop (tool/updater) lance
  // `motorz --updating …` pour afficher une petite fenêtre de progression
  // pendant qu'il télécharge/installe la nouvelle version. On NE démarre PAS
  // l'app complète (ni la base sqflite) dans ce cas.
  if (args.contains('--updating')) {
    runUpdatingSplash(args);
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();

  // Sur mobile/desktop, ouvre la base sqflite et surcharge le store/file
  // (impls mémoire par défaut). En cas d'échec, on reste sur la mémoire ; on
  // remontera l'incident au logger une fois celui-ci disponible (il a besoin
  // du container).
  Object? sqfliteError;
  StackTrace? sqfliteStack;
  ProviderContainer container;
  if (!kIsWeb) {
    try {
      final db = await openMotorzDatabase();
      container = ProviderContainer(overrides: [
        localRecordStoreProvider.overrideWithValue(SqfliteLocalRecordStore(db)),
        pendingQueueProvider.overrideWithValue(SqflitePendingQueue(db)),
        rejectedOpStoreProvider.overrideWithValue(SqfliteRejectedOpStore(db)),
      ]);
    } catch (e, st) {
      sqfliteError = e;
      sqfliteStack = st;
      container = ProviderContainer();
    }
  } else {
    container = ProviderContainer();
  }

  // Lit le logger avant `runApp` pour câbler les handlers d'erreur globaux.
  final logger = container.read(loggerProvider);
  _installErrorHandlers(logger);

  if (sqfliteError != null) {
    logger.warn('sqflite.init_failed — bascule sur le store en mémoire',
        error: sqfliteError, stack: sqfliteStack);
  }
  logger.info('app.started');

  runApp(UncontrolledProviderScope(container: container, child: const MotorzApp()));
}

/// Route les erreurs Flutter/Dart non capturées vers le logger.
///
/// Deux hooks couvrent l'immense majorité des défaillances côté Dart :
///
/// - [FlutterError.onError] — erreurs synchrones du framework (build de
///   widget, layout, render, assertions).
/// - [PlatformDispatcher.onError] — erreurs Dart asynchrones qui échappent à
///   tous les `Future`/`Stream`/zones au-dessus d'elles (filet de dernier
///   recours introduit en Flutter 3.3).
///
/// Les crashes natifs (Swift/Obj-C, JVM, libs FFI) contournent les deux hooks :
/// ils tuent l'isolate Dart avant que l'un ou l'autre ne s'exécute.
void _installErrorHandlers(LoggerApplicationService logger) {
  final defaultOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    logger.error(
      'flutter.error',
      error: details.exception,
      stack: details.stack,
      attrs: {
        if (details.library != null) 'flutter.library': details.library!,
        if (details.context != null) 'flutter.context': details.context!.toString(),
      },
    );
    // Conserve le comportement par défaut (écran rouge en debug, dump console
    // ailleurs) pour ne pas masquer silencieusement les erreurs en dev.
    defaultOnError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.error('dart.uncaught', error: error, stack: stack);
    // `true` = erreur gérée : l'app continue plutôt que de propager au système.
    return true;
  };
}

/// Locale unique de l'app : français (France). Force notamment les
/// date pickers en français, avec le lundi comme premier jour de semaine.
const _appLocale = Locale('fr', 'FR');

/// Délégués Material/Widgets/Cupertino traduits, fournis par
/// `flutter_localizations`. Sans eux, Flutter retombe sur l'anglais.
const _localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const _supportedLocales = <Locale>[_appLocale];

class MotorzApp extends ConsumerStatefulWidget {
  const MotorzApp({super.key});

  @override
  ConsumerState<MotorzApp> createState() => _MotorzAppState();
}

class _MotorzAppState extends ConsumerState<MotorzApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final logger = ref.read(loggerProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        logger.info('app.resumed');
      case AppLifecycleState.paused:
        // Flush pour que les logs en tampon partent avant que l'OS suspende.
        logger.info('app.paused');
        logger.flush();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(bootstrapProvider);
    final themeMode = ref.watch(themeModeControllerProvider).value ?? AppThemeMode.system;

    final light = AppThemeData.buildLightTheme();
    final dark = AppThemeData.buildDarkTheme();

    return bootstrap.when(
      loading: () => MaterialApp(
        title: 'Motorz',
        theme: light,
        darkTheme: dark,
        themeMode: ThemeMode.system,
        locale: _appLocale,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: _supportedLocales,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => MaterialApp(
        title: 'Motorz',
        theme: light,
        darkTheme: dark,
        locale: _appLocale,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: _supportedLocales,
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: Text('Erreur de démarrage : $e'))),
      ),
      data: (_) => MaterialApp.router(
        title: 'Motorz',
        theme: light,
        darkTheme: dark,
        themeMode: AppThemeData.toFlutterThemeMode(themeMode),
        locale: _appLocale,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: _supportedLocales,
        debugShowCheckedModeBanner: false,
        routerConfig: ref.watch(goRouterProvider),
      ),
    );
  }
}
