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
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/infrastructure/session/secure_storage_session_repository.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/infrastructure/sync/pending_queue.dart';
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
  dio.interceptors.add(AuthInterceptor(session: () => ref.read(currentSessionProvider)));
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
SessionRepository sessionRepository(Ref ref) =>
    kIsWeb ? InMemorySessionRepository() : SecureStorageSessionRepository();

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

@Riverpod(keepAlive: true)
SyncCursorStore syncCursor(Ref ref) =>
    kIsWeb ? InMemorySyncCursorStore() : SharedPrefsSyncCursorStore();

@Riverpod(keepAlive: true)
SyncApi syncApi(Ref ref) => SyncApi(ref.watch(dioProvider));

@Riverpod(keepAlive: true)
VehicleRemoteApi vehicleRemoteApi(Ref ref) => VehicleRemoteApi(ref.watch(dioProvider));

@Riverpod(keepAlive: true)
MediaRemoteApi mediaRemoteApi(Ref ref) => MediaRemoteApi(ref.watch(dioProvider));

@Riverpod(keepAlive: true)
SyncService syncService(Ref ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final service = SyncService(
    api: ref.watch(syncApiProvider),
    store: ref.watch(localRecordStoreProvider),
    queue: ref.watch(pendingQueueProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    cursor: ref.watch(syncCursorProvider),
    enabled: !isMemoryMode(baseUrl),
  );
  ref.onDispose(service.dispose);
  return service;
}

/// Émet à chaque changement du store local — l'UI s'y abonne pour se rafraîchir.
@riverpod
Stream<void> storeChanges(Ref ref) => ref.watch(localRecordStoreProvider).changes;
