import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/app_theme_mode.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/infrastructure/providers/theme_providers.dart';
import 'package:motorz/infrastructure/sync/local_database.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/infrastructure/sync/pending_queue.dart';
import 'package:motorz/ui/router/app_router.dart';
import 'package:motorz/ui/theme/app_theme_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sur mobile/desktop, ouvre la base sqflite et surcharge le store/file
  // (impls mémoire par défaut). En cas d'échec, on reste sur la mémoire.
  ProviderContainer container;
  if (!kIsWeb) {
    try {
      final db = await openMotorzDatabase();
      container = ProviderContainer(overrides: [
        localRecordStoreProvider.overrideWithValue(SqfliteLocalRecordStore(db)),
        pendingQueueProvider.overrideWithValue(SqflitePendingQueue(db)),
      ]);
    } catch (e, st) {
      developer.log('sqflite init failed — using in-memory store',
          name: 'motorz', error: e, stackTrace: st);
      container = ProviderContainer();
    }
  } else {
    container = ProviderContainer();
  }

  _installErrorHandlers();

  runApp(UncontrolledProviderScope(container: container, child: const MotorzApp()));
}

void _installErrorHandlers() {
  final defaultOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    developer.log('flutter.error', name: 'motorz', error: details.exception, stackTrace: details.stack);
    defaultOnError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    developer.log('dart.uncaught', name: 'motorz', error: error, stackTrace: stack);
    return true;
  };
}

class MotorzApp extends ConsumerWidget {
  const MotorzApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => MaterialApp(
        title: 'Motorz',
        theme: light,
        darkTheme: dark,
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: Text('Erreur de démarrage : $e'))),
      ),
      data: (_) => MaterialApp.router(
        title: 'Motorz',
        theme: light,
        darkTheme: dark,
        themeMode: AppThemeData.toFlutterThemeMode(themeMode),
        debugShowCheckedModeBanner: false,
        routerConfig: ref.watch(goRouterProvider),
      ),
    );
  }
}
