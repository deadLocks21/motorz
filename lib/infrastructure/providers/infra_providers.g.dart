// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'infra_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// URL de l'API configurable au runtime (réglages) avec fallback `--dart-define`.

@ProviderFor(ApiBaseUrl)
final apiBaseUrlProvider = ApiBaseUrlProvider._();

/// URL de l'API configurable au runtime (réglages) avec fallback `--dart-define`.
final class ApiBaseUrlProvider extends $NotifierProvider<ApiBaseUrl, String> {
  /// URL de l'API configurable au runtime (réglages) avec fallback `--dart-define`.
  ApiBaseUrlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiBaseUrlProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiBaseUrlHash();

  @$internal
  @override
  ApiBaseUrl create() => ApiBaseUrl();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$apiBaseUrlHash() => r'8eb48bf6a99ddb2496712efc0a6bdb469aa6fe87';

/// URL de l'API configurable au runtime (réglages) avec fallback `--dart-define`.

abstract class _$ApiBaseUrl extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(dio)
final dioProvider = DioProvider._();

final class DioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  DioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dioProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return dio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$dioHash() => r'58f585863ede4cbbcaf052fd021021ba145200ca';

@ProviderFor(connectivityService)
final connectivityServiceProvider = ConnectivityServiceProvider._();

final class ConnectivityServiceProvider
    extends
        $FunctionalProvider<
          ConnectivityService,
          ConnectivityService,
          ConnectivityService
        >
    with $Provider<ConnectivityService> {
  ConnectivityServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectivityServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectivityServiceHash();

  @$internal
  @override
  $ProviderElement<ConnectivityService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConnectivityService create(Ref ref) {
    return connectivityService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConnectivityService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConnectivityService>(value),
    );
  }
}

String _$connectivityServiceHash() =>
    r'46c10db5cd5efd54f053ca2c532c9f159fd349b2';

@ProviderFor(connectivityStatus)
final connectivityStatusProvider = ConnectivityStatusProvider._();

final class ConnectivityStatusProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  ConnectivityStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectivityStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectivityStatusHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return connectivityStatus(ref);
  }
}

String _$connectivityStatusHash() =>
    r'a7ece4cb0332ddabf6e1d6d76c479f672268fe8c';

@ProviderFor(sessionRepository)
final sessionRepositoryProvider = SessionRepositoryProvider._();

final class SessionRepositoryProvider
    extends
        $FunctionalProvider<
          SessionRepository,
          SessionRepository,
          SessionRepository
        >
    with $Provider<SessionRepository> {
  SessionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionRepositoryHash();

  @$internal
  @override
  $ProviderElement<SessionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionRepository create(Ref ref) {
    return sessionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionRepository>(value),
    );
  }
}

String _$sessionRepositoryHash() => r'd6f0d5ec5b5d487d69c780add3298417e874c810';

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  AuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRepository create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRepository>(value),
    );
  }
}

String _$authRepositoryHash() => r'15b3fc1e784eb8c2742bd3558518a9b352815b7c';

/// Store local — impl mémoire par défaut, **surchargée** par l'impl sqflite
/// dans `main()` sur mobile/desktop.

@ProviderFor(localRecordStore)
final localRecordStoreProvider = LocalRecordStoreProvider._();

/// Store local — impl mémoire par défaut, **surchargée** par l'impl sqflite
/// dans `main()` sur mobile/desktop.

final class LocalRecordStoreProvider
    extends
        $FunctionalProvider<
          LocalRecordStore,
          LocalRecordStore,
          LocalRecordStore
        >
    with $Provider<LocalRecordStore> {
  /// Store local — impl mémoire par défaut, **surchargée** par l'impl sqflite
  /// dans `main()` sur mobile/desktop.
  LocalRecordStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localRecordStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localRecordStoreHash();

  @$internal
  @override
  $ProviderElement<LocalRecordStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocalRecordStore create(Ref ref) {
    return localRecordStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalRecordStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalRecordStore>(value),
    );
  }
}

String _$localRecordStoreHash() => r'd832c6a563a2bce73733f058b5bb873f63d5af83';

@ProviderFor(pendingQueue)
final pendingQueueProvider = PendingQueueProvider._();

final class PendingQueueProvider
    extends $FunctionalProvider<PendingQueue, PendingQueue, PendingQueue>
    with $Provider<PendingQueue> {
  PendingQueueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingQueueProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingQueueHash();

  @$internal
  @override
  $ProviderElement<PendingQueue> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PendingQueue create(Ref ref) {
    return pendingQueue(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PendingQueue value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PendingQueue>(value),
    );
  }
}

String _$pendingQueueHash() => r'ae16510e08c59d266f3edc1da2db2096b26cde21';

@ProviderFor(syncCursor)
final syncCursorProvider = SyncCursorProvider._();

final class SyncCursorProvider
    extends
        $FunctionalProvider<SyncCursorStore, SyncCursorStore, SyncCursorStore>
    with $Provider<SyncCursorStore> {
  SyncCursorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncCursorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncCursorHash();

  @$internal
  @override
  $ProviderElement<SyncCursorStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncCursorStore create(Ref ref) {
    return syncCursor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncCursorStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncCursorStore>(value),
    );
  }
}

String _$syncCursorHash() => r'966d4c0550b3c6c037f9b03e5aac92e9917bdb91';

@ProviderFor(syncApi)
final syncApiProvider = SyncApiProvider._();

final class SyncApiProvider
    extends $FunctionalProvider<SyncApi, SyncApi, SyncApi>
    with $Provider<SyncApi> {
  SyncApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncApiHash();

  @$internal
  @override
  $ProviderElement<SyncApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncApi create(Ref ref) {
    return syncApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncApi>(value),
    );
  }
}

String _$syncApiHash() => r'8ff802c2cd0fd39a10ec0d5c929bfae52498853f';

@ProviderFor(vehicleRemoteApi)
final vehicleRemoteApiProvider = VehicleRemoteApiProvider._();

final class VehicleRemoteApiProvider
    extends
        $FunctionalProvider<
          VehicleRemoteApi,
          VehicleRemoteApi,
          VehicleRemoteApi
        >
    with $Provider<VehicleRemoteApi> {
  VehicleRemoteApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vehicleRemoteApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vehicleRemoteApiHash();

  @$internal
  @override
  $ProviderElement<VehicleRemoteApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VehicleRemoteApi create(Ref ref) {
    return vehicleRemoteApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VehicleRemoteApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VehicleRemoteApi>(value),
    );
  }
}

String _$vehicleRemoteApiHash() => r'596b0126901398f27344cae584ddac43c771db9b';

@ProviderFor(mediaRemoteApi)
final mediaRemoteApiProvider = MediaRemoteApiProvider._();

final class MediaRemoteApiProvider
    extends $FunctionalProvider<MediaRemoteApi, MediaRemoteApi, MediaRemoteApi>
    with $Provider<MediaRemoteApi> {
  MediaRemoteApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaRemoteApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaRemoteApiHash();

  @$internal
  @override
  $ProviderElement<MediaRemoteApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MediaRemoteApi create(Ref ref) {
    return mediaRemoteApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaRemoteApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaRemoteApi>(value),
    );
  }
}

String _$mediaRemoteApiHash() => r'f35f88b9ef4d6bd4dc6f7df5f9bdde09cd456a8f';

@ProviderFor(syncService)
final syncServiceProvider = SyncServiceProvider._();

final class SyncServiceProvider
    extends $FunctionalProvider<SyncService, SyncService, SyncService>
    with $Provider<SyncService> {
  SyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncServiceHash();

  @$internal
  @override
  $ProviderElement<SyncService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncService create(Ref ref) {
    return syncService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncService>(value),
    );
  }
}

String _$syncServiceHash() => r'ec19b96b4a0ac4d7a2279d956d74ced49ce02d8e';

/// Émet à chaque changement du store local — l'UI s'y abonne pour se rafraîchir.

@ProviderFor(storeChanges)
final storeChangesProvider = StoreChangesProvider._();

/// Émet à chaque changement du store local — l'UI s'y abonne pour se rafraîchir.

final class StoreChangesProvider
    extends $FunctionalProvider<AsyncValue<void>, void, Stream<void>>
    with $FutureModifier<void>, $StreamProvider<void> {
  /// Émet à chaque changement du store local — l'UI s'y abonne pour se rafraîchir.
  StoreChangesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storeChangesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storeChangesHash();

  @$internal
  @override
  $StreamProviderElement<void> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<void> create(Ref ref) {
    return storeChanges(ref);
  }
}

String _$storeChangesHash() => r'1f26b75c2894e52b543b6a3a53280e8d90db1fb1';
