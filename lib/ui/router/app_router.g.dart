// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Router unique, dont le `redirect` est piloté par [SessionState] et
/// rafraîchi via un `ValueNotifier` bumpé à chaque transition de session.

@ProviderFor(goRouter)
final goRouterProvider = GoRouterProvider._();

/// Router unique, dont le `redirect` est piloté par [SessionState] et
/// rafraîchi via un `ValueNotifier` bumpé à chaque transition de session.

final class GoRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// Router unique, dont le `redirect` est piloté par [SessionState] et
  /// rafraîchi via un `ValueNotifier` bumpé à chaque transition de session.
  GoRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'goRouterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$goRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return goRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$goRouterHash() => r'5422a5828ac8a0a261b1225552cf0fd89aa58ba6';
