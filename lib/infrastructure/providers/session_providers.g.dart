// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Pilote la machine d'états [SessionState] (cf. redirect go_router).

@ProviderFor(SessionController)
final sessionControllerProvider = SessionControllerProvider._();

/// Pilote la machine d'états [SessionState] (cf. redirect go_router).
final class SessionControllerProvider
    extends $NotifierProvider<SessionController, SessionState> {
  /// Pilote la machine d'états [SessionState] (cf. redirect go_router).
  SessionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionControllerHash();

  @$internal
  @override
  SessionController create() => SessionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionState>(value),
    );
  }
}

String _$sessionControllerHash() => r'715ab7334538d09f87479dea85f4f57ee818878a';

/// Pilote la machine d'états [SessionState] (cf. redirect go_router).

abstract class _$SessionController extends $Notifier<SessionState> {
  SessionState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SessionState, SessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SessionState, SessionState>,
              SessionState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Session courante (ou `null` si non authentifié).

@ProviderFor(currentSession)
final currentSessionProvider = CurrentSessionProvider._();

/// Session courante (ou `null` si non authentifié).

final class CurrentSessionProvider
    extends $FunctionalProvider<Session?, Session?, Session?>
    with $Provider<Session?> {
  /// Session courante (ou `null` si non authentifié).
  CurrentSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentSessionHash();

  @$internal
  @override
  $ProviderElement<Session?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Session? create(Ref ref) {
    return currentSession(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Session? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Session?>(value),
    );
  }
}

String _$currentSessionHash() => r'1035642f1e816b8c00fa4b4db40bf65626b048bd';

/// Amorce l'app : charge l'URL d'API, restaure la session, démarre la synchro.

@ProviderFor(bootstrap)
final bootstrapProvider = BootstrapProvider._();

/// Amorce l'app : charge l'URL d'API, restaure la session, démarre la synchro.

final class BootstrapProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Amorce l'app : charge l'URL d'API, restaure la session, démarre la synchro.
  BootstrapProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bootstrapProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bootstrapHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return bootstrap(ref);
  }
}

String _$bootstrapHash() => r'6f6397a602aa123c89a309faf1a232be70fba6ca';
