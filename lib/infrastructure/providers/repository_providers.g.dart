// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(vehicleRepository)
final vehicleRepositoryProvider = VehicleRepositoryProvider._();

final class VehicleRepositoryProvider
    extends
        $FunctionalProvider<
          SyncableRepository<Vehicle>,
          SyncableRepository<Vehicle>,
          SyncableRepository<Vehicle>
        >
    with $Provider<SyncableRepository<Vehicle>> {
  VehicleRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vehicleRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vehicleRepositoryHash();

  @$internal
  @override
  $ProviderElement<SyncableRepository<Vehicle>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncableRepository<Vehicle> create(Ref ref) {
    return vehicleRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncableRepository<Vehicle> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncableRepository<Vehicle>>(value),
    );
  }
}

String _$vehicleRepositoryHash() => r'0b8195227ccd2829f7b6ce4420519fc1d87daa64';

@ProviderFor(fuelRepository)
final fuelRepositoryProvider = FuelRepositoryProvider._();

final class FuelRepositoryProvider
    extends
        $FunctionalProvider<
          SyncableRepository<FuelEntry>,
          SyncableRepository<FuelEntry>,
          SyncableRepository<FuelEntry>
        >
    with $Provider<SyncableRepository<FuelEntry>> {
  FuelRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fuelRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fuelRepositoryHash();

  @$internal
  @override
  $ProviderElement<SyncableRepository<FuelEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncableRepository<FuelEntry> create(Ref ref) {
    return fuelRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncableRepository<FuelEntry> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncableRepository<FuelEntry>>(
        value,
      ),
    );
  }
}

String _$fuelRepositoryHash() => r'841778c8de547aceb87fc847a556edecd3ec903a';

@ProviderFor(catalogItemRepository)
final catalogItemRepositoryProvider = CatalogItemRepositoryProvider._();

final class CatalogItemRepositoryProvider
    extends
        $FunctionalProvider<
          SyncableRepository<CatalogItem>,
          SyncableRepository<CatalogItem>,
          SyncableRepository<CatalogItem>
        >
    with $Provider<SyncableRepository<CatalogItem>> {
  CatalogItemRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'catalogItemRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$catalogItemRepositoryHash();

  @$internal
  @override
  $ProviderElement<SyncableRepository<CatalogItem>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncableRepository<CatalogItem> create(Ref ref) {
    return catalogItemRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncableRepository<CatalogItem> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncableRepository<CatalogItem>>(
        value,
      ),
    );
  }
}

String _$catalogItemRepositoryHash() =>
    r'dc32732cb3240fe6ef3c6976babde845f2d78c01';

@ProviderFor(operationRepository)
final operationRepositoryProvider = OperationRepositoryProvider._();

final class OperationRepositoryProvider
    extends
        $FunctionalProvider<
          SyncableRepository<Operation>,
          SyncableRepository<Operation>,
          SyncableRepository<Operation>
        >
    with $Provider<SyncableRepository<Operation>> {
  OperationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'operationRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$operationRepositoryHash();

  @$internal
  @override
  $ProviderElement<SyncableRepository<Operation>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncableRepository<Operation> create(Ref ref) {
    return operationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncableRepository<Operation> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncableRepository<Operation>>(
        value,
      ),
    );
  }
}

String _$operationRepositoryHash() =>
    r'6806493404076a2504d066312a2afb8fc2cf857b';

@ProviderFor(operationLineRepository)
final operationLineRepositoryProvider = OperationLineRepositoryProvider._();

final class OperationLineRepositoryProvider
    extends
        $FunctionalProvider<
          SyncableRepository<OperationLine>,
          SyncableRepository<OperationLine>,
          SyncableRepository<OperationLine>
        >
    with $Provider<SyncableRepository<OperationLine>> {
  OperationLineRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'operationLineRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$operationLineRepositoryHash();

  @$internal
  @override
  $ProviderElement<SyncableRepository<OperationLine>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncableRepository<OperationLine> create(Ref ref) {
    return operationLineRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncableRepository<OperationLine> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncableRepository<OperationLine>>(
        value,
      ),
    );
  }
}

String _$operationLineRepositoryHash() =>
    r'a8c2e3473547ced3714b1e7f3551727a80d1efb7';

@ProviderFor(planRepository)
final planRepositoryProvider = PlanRepositoryProvider._();

final class PlanRepositoryProvider
    extends
        $FunctionalProvider<
          SyncableRepository<Plan>,
          SyncableRepository<Plan>,
          SyncableRepository<Plan>
        >
    with $Provider<SyncableRepository<Plan>> {
  PlanRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'planRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$planRepositoryHash();

  @$internal
  @override
  $ProviderElement<SyncableRepository<Plan>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncableRepository<Plan> create(Ref ref) {
    return planRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncableRepository<Plan> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncableRepository<Plan>>(value),
    );
  }
}

String _$planRepositoryHash() => r'9ce2487d526d687b499c0c1c23ded737b61a3d67';

@ProviderFor(tirePressureRepository)
final tirePressureRepositoryProvider = TirePressureRepositoryProvider._();

final class TirePressureRepositoryProvider
    extends
        $FunctionalProvider<
          SyncableRepository<TirePressureEntry>,
          SyncableRepository<TirePressureEntry>,
          SyncableRepository<TirePressureEntry>
        >
    with $Provider<SyncableRepository<TirePressureEntry>> {
  TirePressureRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tirePressureRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tirePressureRepositoryHash();

  @$internal
  @override
  $ProviderElement<SyncableRepository<TirePressureEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncableRepository<TirePressureEntry> create(Ref ref) {
    return tirePressureRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncableRepository<TirePressureEntry> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<SyncableRepository<TirePressureEntry>>(value),
    );
  }
}

String _$tirePressureRepositoryHash() =>
    r'2bc6276959779409c0a20e3f0d1bdba7e9f91e19';

@ProviderFor(targetPressureRepository)
final targetPressureRepositoryProvider = TargetPressureRepositoryProvider._();

final class TargetPressureRepositoryProvider
    extends
        $FunctionalProvider<
          SyncableRepository<TargetPressure>,
          SyncableRepository<TargetPressure>,
          SyncableRepository<TargetPressure>
        >
    with $Provider<SyncableRepository<TargetPressure>> {
  TargetPressureRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'targetPressureRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$targetPressureRepositoryHash();

  @$internal
  @override
  $ProviderElement<SyncableRepository<TargetPressure>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncableRepository<TargetPressure> create(Ref ref) {
    return targetPressureRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncableRepository<TargetPressure> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncableRepository<TargetPressure>>(
        value,
      ),
    );
  }
}

String _$targetPressureRepositoryHash() =>
    r'75a351f4926bbd5fbd4cf67266daa64c807759aa';

@ProviderFor(ownershipRepository)
final ownershipRepositoryProvider = OwnershipRepositoryProvider._();

final class OwnershipRepositoryProvider
    extends
        $FunctionalProvider<
          SyncableRepository<Ownership>,
          SyncableRepository<Ownership>,
          SyncableRepository<Ownership>
        >
    with $Provider<SyncableRepository<Ownership>> {
  OwnershipRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ownershipRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ownershipRepositoryHash();

  @$internal
  @override
  $ProviderElement<SyncableRepository<Ownership>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncableRepository<Ownership> create(Ref ref) {
    return ownershipRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncableRepository<Ownership> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncableRepository<Ownership>>(
        value,
      ),
    );
  }
}

String _$ownershipRepositoryHash() =>
    r'2fdda370c69543eb2226dc2c809a73533f2f712c';

@ProviderFor(costEntryRepository)
final costEntryRepositoryProvider = CostEntryRepositoryProvider._();

final class CostEntryRepositoryProvider
    extends
        $FunctionalProvider<
          SyncableRepository<CostEntry>,
          SyncableRepository<CostEntry>,
          SyncableRepository<CostEntry>
        >
    with $Provider<SyncableRepository<CostEntry>> {
  CostEntryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'costEntryRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$costEntryRepositoryHash();

  @$internal
  @override
  $ProviderElement<SyncableRepository<CostEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncableRepository<CostEntry> create(Ref ref) {
    return costEntryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncableRepository<CostEntry> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncableRepository<CostEntry>>(
        value,
      ),
    );
  }
}

String _$costEntryRepositoryHash() =>
    r'2116242d68db70282bdf22841320c7809a709fc0';

@ProviderFor(maintenanceQuoteRepository)
final maintenanceQuoteRepositoryProvider =
    MaintenanceQuoteRepositoryProvider._();

final class MaintenanceQuoteRepositoryProvider
    extends
        $FunctionalProvider<
          SyncableRepository<MaintenanceQuote>,
          SyncableRepository<MaintenanceQuote>,
          SyncableRepository<MaintenanceQuote>
        >
    with $Provider<SyncableRepository<MaintenanceQuote>> {
  MaintenanceQuoteRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'maintenanceQuoteRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$maintenanceQuoteRepositoryHash();

  @$internal
  @override
  $ProviderElement<SyncableRepository<MaintenanceQuote>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncableRepository<MaintenanceQuote> create(Ref ref) {
    return maintenanceQuoteRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncableRepository<MaintenanceQuote> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<SyncableRepository<MaintenanceQuote>>(value),
    );
  }
}

String _$maintenanceQuoteRepositoryHash() =>
    r'bf1378638b89f0e05092ba8970719d264ac0c3ce';

@ProviderFor(mediaRepository)
final mediaRepositoryProvider = MediaRepositoryProvider._();

final class MediaRepositoryProvider
    extends
        $FunctionalProvider<
          SyncableRepository<MediaItem>,
          SyncableRepository<MediaItem>,
          SyncableRepository<MediaItem>
        >
    with $Provider<SyncableRepository<MediaItem>> {
  MediaRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaRepositoryHash();

  @$internal
  @override
  $ProviderElement<SyncableRepository<MediaItem>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncableRepository<MediaItem> create(Ref ref) {
    return mediaRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncableRepository<MediaItem> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncableRepository<MediaItem>>(
        value,
      ),
    );
  }
}

String _$mediaRepositoryHash() => r'8391477cc24401a7f9ceb2ddf48953509a4adc4d';
