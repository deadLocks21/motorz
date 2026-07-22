import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:motorz/core/domain/services/auth.repository.dart';
import 'package:motorz/core/domain/services/connectivity.service.dart';
import 'package:motorz/core/domain/services/session.repository.dart';
import 'package:motorz/infrastructure/api/media_remote_api.dart';
import 'package:motorz/infrastructure/api/vehicle_remote_api.dart';
import 'package:motorz/infrastructure/auth/dio_auth_repository.dart';
import 'package:motorz/infrastructure/auth/in_memory_auth_repository.dart';
import 'package:motorz/infrastructure/connectivity/connectivity_plus.service.dart';
import 'package:motorz/infrastructure/http/auth_interceptor.dart';
import 'package:motorz/infrastructure/providers/logger_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/infrastructure/session/shared_prefs_session_repository.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/infrastructure/sync/pending_queue.dart';
import 'package:motorz/infrastructure/sync/rejected_op_store.dart';
import 'package:motorz/infrastructure/sync/sync_api.dart';
import 'package:motorz/infrastructure/sync/sync_cursor.dart';
import 'package:motorz/infrastructure/sync/sync_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'infra_providers.g.dart';

/// Mode local-only (sans backend) : la synchro est neutralisée, l'app
/// fonctionne entièrement sur le store local.
bool isMemoryMode(String url) => url == 'memory' || url.isEmpty;

const _envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'memory');

/// URL de l'API configurable au runtime (réglages) avec fallback `--dart-define`.
@Riverpod(keepAlive: true)
class ApiBaseUrl extends _$ApiBaseUrl {
  static const _prefKey = 'motorz.api_base_url';

  @override
  String build() => _envBaseUrl;

  Future<void> load() async {
    final stored = (await SharedPreferences.getInstance()).getString(_prefKey);
    if (stored != null && stored.isNotEmpty) state = stored;
  }

  Future<void> update(String url) async {
    await (await SharedPreferences.getInstance()).setString(_prefKey, url);
    state = url;
  }
}

@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: isMemoryMode(baseUrl) ? 'http://localhost' : baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      contentType: 'application/json',
      responseType: ResponseType.json,
    ),
  );
  dio.interceptors.add(AuthInterceptor(
    session: () => ref.read(currentSessionProvider),
    // Lecture paresseuse du notifier : `authRepository` dépend de ce provider,
    // la résoudre ici créerait un cycle.
    onUnauthorized: () => unawaited(ref.read(sessionControllerProvider.notifier).expire()),
  ));
  return dio;
}

@Riverpod(keepAlive: true)
ConnectivityService connectivityService(Ref ref) {
  if (kIsWeb) return const AlwaysOnlineConnectivityService();
  final service = ConnectivityPlusService();
  ref.onDispose(service.dispose);
  return service;
}

@riverpod
Stream<bool> connectivityStatus(Ref ref) => ref.watch(connectivityServiceProvider).watch();

@Riverpod(keepAlive: true)
SessionRepository sessionRepository(Ref ref) {
  // Persistance locale via `shared_preferences` sur **toutes** les plateformes,
  // web inclus (adossé à `localStorage` — stockage non chiffré, cf.
  // SharedPreferencesSessionRepository) : elle permet de survivre aux hot
  // restart sur mobile/desktop, et au rechargement de page sur web (sans quoi
  // le web imposerait un login à chaque visite).
  //
  // Sur web, le store local et le curseur de sync restent eux en mémoire (cf.
  // `syncCursor` plus bas et les overrides sqflite de `main()`) : l'état métier
  // est donc simplement re-synchronisé depuis le serveur une fois la session
  // restaurée, curseur nul = pull complet.
  //
  // En démo (memory) le JWT est factice et l'identité (cf.
  // InMemoryAuthRepository._demoUserId) est déterministe, donc la session
  // persistée reste cohérente avec le seed.
  return SharedPreferencesSessionRepository();
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  return isMemoryMode(baseUrl) ? InMemoryAuthRepository() : DioAuthRepository(ref.watch(dioProvider));
}

/// Store local — impl mémoire par défaut, **surchargée** par l'impl sqflite
/// dans `main()` sur mobile/desktop.
@Riverpod(keepAlive: true)
LocalRecordStore localRecordStore(Ref ref) => InMemoryLocalRecordStore();

@Riverpod(keepAlive: true)
PendingQueue pendingQueue(Ref ref) => InMemoryPendingQueue();

/// Dead-letter des écritures refusées en push — impl mémoire par défaut,
/// **surchargée** par l'impl sqflite dans `main()` sur mobile/desktop.
@Riverpod(keepAlive: true)
RejectedOpStore rejectedOpStore(Ref ref) => InMemoryRejectedOpStore();

@Riverpod(keepAlive: true)
SyncCursorStore syncCursor(Ref ref) =>
    kIsWeb ? InMemorySyncCursorStore() : SharedPrefsSyncCursorStore();

@Riverpod(keepAlive: true)
SyncApi syncApi(Ref ref) => SyncApi(ref.watch(dioProvider));

@Riverpod(keepAlive: true)
VehicleRemoteApi vehicleRemoteApi(Ref ref) =>
    VehicleRemoteApi(ref.watch(dioProvider), logger: ref.watch(loggerProvider));

@Riverpod(keepAlive: true)
MediaRemoteApi mediaRemoteApi(Ref ref) =>
    MediaRemoteApi(ref.watch(dioProvider), logger: ref.watch(loggerProvider));

@Riverpod(keepAlive: true)
SyncService syncService(Ref ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final service = SyncService(
    api: ref.watch(syncApiProvider),
    store: ref.watch(localRecordStoreProvider),
    queue: ref.watch(pendingQueueProvider),
    rejectedStore: ref.watch(rejectedOpStoreProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    cursor: ref.watch(syncCursorProvider),
    logger: ref.watch(loggerProvider),
    enabled: !isMemoryMode(baseUrl),
  );
  ref.onDispose(service.dispose);
  return service;
}

/// État de synchro observable par l'UI (phase, ops en attente, rejets).
@riverpod
Stream<SyncStatus> syncStatus(Ref ref) => ref.watch(syncServiceProvider).watchStatus();

/// Émet à chaque changement du store local — l'UI s'y abonne pour se rafraîchir.
/// Le flux porte un numéro de révision monotone (cf. [LocalRecordStore.changes]) :
/// indispensable pour que Riverpod renotifie à *chaque* écriture, et pas qu'à la 1ʳᵉ.
@riverpod
Stream<int> storeChanges(Ref ref) => ref.watch(localRecordStoreProvider).changes;
