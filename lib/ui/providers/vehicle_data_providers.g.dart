// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicle_data_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tous les véhicules accessibles (mes véhicules + partagés), depuis le local.

@ProviderFor(vehicles)
final vehiclesProvider = VehiclesProvider._();

/// Tous les véhicules accessibles (mes véhicules + partagés), depuis le local.

final class VehiclesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Vehicle>>,
          List<Vehicle>,
          FutureOr<List<Vehicle>>
        >
    with $FutureModifier<List<Vehicle>>, $FutureProvider<List<Vehicle>> {
  /// Tous les véhicules accessibles (mes véhicules + partagés), depuis le local.
  VehiclesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vehiclesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vehiclesHash();

  @$internal
  @override
  $FutureProviderElement<List<Vehicle>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Vehicle>> create(Ref ref) {
    return vehicles(ref);
  }
}

String _$vehiclesHash() => r'a6a1b1786829bb9a369410cc03d39627a9f33cfa';

@ProviderFor(vehicleById)
final vehicleByIdProvider = VehicleByIdFamily._();

final class VehicleByIdProvider
    extends
        $FunctionalProvider<AsyncValue<Vehicle?>, Vehicle?, FutureOr<Vehicle?>>
    with $FutureModifier<Vehicle?>, $FutureProvider<Vehicle?> {
  VehicleByIdProvider._({
    required VehicleByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'vehicleByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$vehicleByIdHash();

  @override
  String toString() {
    return r'vehicleByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Vehicle?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Vehicle?> create(Ref ref) {
    final argument = this.argument as String;
    return vehicleById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VehicleByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$vehicleByIdHash() => r'83a19e403b3ae5d536df730102c687c102a1c263';

final class VehicleByIdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Vehicle?>, String> {
  VehicleByIdFamily._()
    : super(
        retry: null,
        name: r'vehicleByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  VehicleByIdProvider call(String vehicleId) =>
      VehicleByIdProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'vehicleByIdProvider';
}

@ProviderFor(fuelEntries)
final fuelEntriesProvider = FuelEntriesFamily._();

final class FuelEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FuelEntry>>,
          List<FuelEntry>,
          FutureOr<List<FuelEntry>>
        >
    with $FutureModifier<List<FuelEntry>>, $FutureProvider<List<FuelEntry>> {
  FuelEntriesProvider._({
    required FuelEntriesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'fuelEntriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$fuelEntriesHash();

  @override
  String toString() {
    return r'fuelEntriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<FuelEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<FuelEntry>> create(Ref ref) {
    final argument = this.argument as String;
    return fuelEntries(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FuelEntriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$fuelEntriesHash() => r'57f0f27e35090154ed656875fb6e6742fed56cab';

final class FuelEntriesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<FuelEntry>>, String> {
  FuelEntriesFamily._()
    : super(
        retry: null,
        name: r'fuelEntriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FuelEntriesProvider call(String vehicleId) =>
      FuelEntriesProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'fuelEntriesProvider';
}

@ProviderFor(maintenanceEvents)
final maintenanceEventsProvider = MaintenanceEventsFamily._();

final class MaintenanceEventsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MaintenanceEvent>>,
          List<MaintenanceEvent>,
          FutureOr<List<MaintenanceEvent>>
        >
    with
        $FutureModifier<List<MaintenanceEvent>>,
        $FutureProvider<List<MaintenanceEvent>> {
  MaintenanceEventsProvider._({
    required MaintenanceEventsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'maintenanceEventsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$maintenanceEventsHash();

  @override
  String toString() {
    return r'maintenanceEventsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<MaintenanceEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MaintenanceEvent>> create(Ref ref) {
    final argument = this.argument as String;
    return maintenanceEvents(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MaintenanceEventsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$maintenanceEventsHash() => r'9755fa16a95b1fbc2445be455d5b1ea6ede18960';

final class MaintenanceEventsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<MaintenanceEvent>>, String> {
  MaintenanceEventsFamily._()
    : super(
        retry: null,
        name: r'maintenanceEventsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MaintenanceEventsProvider call(String vehicleId) =>
      MaintenanceEventsProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'maintenanceEventsProvider';
}

@ProviderFor(maintenanceTasks)
final maintenanceTasksProvider = MaintenanceTasksFamily._();

final class MaintenanceTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MaintenanceTask>>,
          List<MaintenanceTask>,
          FutureOr<List<MaintenanceTask>>
        >
    with
        $FutureModifier<List<MaintenanceTask>>,
        $FutureProvider<List<MaintenanceTask>> {
  MaintenanceTasksProvider._({
    required MaintenanceTasksFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'maintenanceTasksProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$maintenanceTasksHash();

  @override
  String toString() {
    return r'maintenanceTasksProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<MaintenanceTask>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MaintenanceTask>> create(Ref ref) {
    final argument = this.argument as String;
    return maintenanceTasks(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MaintenanceTasksProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$maintenanceTasksHash() => r'6af2d2273951ec184a3eeeebca319ebf4673fc12';

final class MaintenanceTasksFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<MaintenanceTask>>, String> {
  MaintenanceTasksFamily._()
    : super(
        retry: null,
        name: r'maintenanceTasksProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MaintenanceTasksProvider call(String vehicleId) =>
      MaintenanceTasksProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'maintenanceTasksProvider';
}

@ProviderFor(tirePressures)
final tirePressuresProvider = TirePressuresFamily._();

final class TirePressuresProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TirePressureEntry>>,
          List<TirePressureEntry>,
          FutureOr<List<TirePressureEntry>>
        >
    with
        $FutureModifier<List<TirePressureEntry>>,
        $FutureProvider<List<TirePressureEntry>> {
  TirePressuresProvider._({
    required TirePressuresFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'tirePressuresProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tirePressuresHash();

  @override
  String toString() {
    return r'tirePressuresProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TirePressureEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TirePressureEntry>> create(Ref ref) {
    final argument = this.argument as String;
    return tirePressures(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TirePressuresProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tirePressuresHash() => r'cc4c075de0b4ef1a2821524bfc53426c94e92abd';

final class TirePressuresFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<TirePressureEntry>>, String> {
  TirePressuresFamily._()
    : super(
        retry: null,
        name: r'tirePressuresProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TirePressuresProvider call(String vehicleId) =>
      TirePressuresProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'tirePressuresProvider';
}

@ProviderFor(targetPressures)
final targetPressuresProvider = TargetPressuresFamily._();

final class TargetPressuresProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TargetPressure>>,
          List<TargetPressure>,
          FutureOr<List<TargetPressure>>
        >
    with
        $FutureModifier<List<TargetPressure>>,
        $FutureProvider<List<TargetPressure>> {
  TargetPressuresProvider._({
    required TargetPressuresFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'targetPressuresProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$targetPressuresHash();

  @override
  String toString() {
    return r'targetPressuresProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TargetPressure>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TargetPressure>> create(Ref ref) {
    final argument = this.argument as String;
    return targetPressures(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TargetPressuresProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$targetPressuresHash() => r'4dfbf769a021d7c2b40483d0d881635694aa3ce5';

final class TargetPressuresFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<TargetPressure>>, String> {
  TargetPressuresFamily._()
    : super(
        retry: null,
        name: r'targetPressuresProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TargetPressuresProvider call(String vehicleId) =>
      TargetPressuresProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'targetPressuresProvider';
}

@ProviderFor(ownerships)
final ownershipsProvider = OwnershipsFamily._();

final class OwnershipsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Ownership>>,
          List<Ownership>,
          FutureOr<List<Ownership>>
        >
    with $FutureModifier<List<Ownership>>, $FutureProvider<List<Ownership>> {
  OwnershipsProvider._({
    required OwnershipsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'ownershipsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$ownershipsHash();

  @override
  String toString() {
    return r'ownershipsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Ownership>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Ownership>> create(Ref ref) {
    final argument = this.argument as String;
    return ownerships(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is OwnershipsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$ownershipsHash() => r'6d93d37b10af6a10e922355edf1832bdc38bbe91';

final class OwnershipsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Ownership>>, String> {
  OwnershipsFamily._()
    : super(
        retry: null,
        name: r'ownershipsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  OwnershipsProvider call(String vehicleId) =>
      OwnershipsProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'ownershipsProvider';
}

@ProviderFor(costEntries)
final costEntriesProvider = CostEntriesFamily._();

final class CostEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CostEntry>>,
          List<CostEntry>,
          FutureOr<List<CostEntry>>
        >
    with $FutureModifier<List<CostEntry>>, $FutureProvider<List<CostEntry>> {
  CostEntriesProvider._({
    required CostEntriesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'costEntriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$costEntriesHash();

  @override
  String toString() {
    return r'costEntriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<CostEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CostEntry>> create(Ref ref) {
    final argument = this.argument as String;
    return costEntries(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CostEntriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$costEntriesHash() => r'b7e583a2e075920f3679b0f80c484c5f56e4e5c4';

final class CostEntriesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<CostEntry>>, String> {
  CostEntriesFamily._()
    : super(
        retry: null,
        name: r'costEntriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CostEntriesProvider call(String vehicleId) =>
      CostEntriesProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'costEntriesProvider';
}

/// Devis du véhicule (filtrés via les opérations d'entretien du véhicule).

@ProviderFor(quotesForVehicle)
final quotesForVehicleProvider = QuotesForVehicleFamily._();

/// Devis du véhicule (filtrés via les opérations d'entretien du véhicule).

final class QuotesForVehicleProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MaintenanceQuote>>,
          List<MaintenanceQuote>,
          FutureOr<List<MaintenanceQuote>>
        >
    with
        $FutureModifier<List<MaintenanceQuote>>,
        $FutureProvider<List<MaintenanceQuote>> {
  /// Devis du véhicule (filtrés via les opérations d'entretien du véhicule).
  QuotesForVehicleProvider._({
    required QuotesForVehicleFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'quotesForVehicleProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$quotesForVehicleHash();

  @override
  String toString() {
    return r'quotesForVehicleProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<MaintenanceQuote>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MaintenanceQuote>> create(Ref ref) {
    final argument = this.argument as String;
    return quotesForVehicle(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is QuotesForVehicleProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$quotesForVehicleHash() => r'287d60fb674a088dc134fe7ef951e09fd6457e1d';

/// Devis du véhicule (filtrés via les opérations d'entretien du véhicule).

final class QuotesForVehicleFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<MaintenanceQuote>>, String> {
  QuotesForVehicleFamily._()
    : super(
        retry: null,
        name: r'quotesForVehicleProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Devis du véhicule (filtrés via les opérations d'entretien du véhicule).

  QuotesForVehicleProvider call(String vehicleId) =>
      QuotesForVehicleProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'quotesForVehicleProvider';
}

@ProviderFor(quotesForEvent)
final quotesForEventProvider = QuotesForEventFamily._();

final class QuotesForEventProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MaintenanceQuote>>,
          List<MaintenanceQuote>,
          FutureOr<List<MaintenanceQuote>>
        >
    with
        $FutureModifier<List<MaintenanceQuote>>,
        $FutureProvider<List<MaintenanceQuote>> {
  QuotesForEventProvider._({
    required QuotesForEventFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'quotesForEventProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$quotesForEventHash();

  @override
  String toString() {
    return r'quotesForEventProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<MaintenanceQuote>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MaintenanceQuote>> create(Ref ref) {
    final argument = this.argument as String;
    return quotesForEvent(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is QuotesForEventProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$quotesForEventHash() => r'1d867b48e425bfb93dd2196859b09b3c42da121a';

final class QuotesForEventFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<MaintenanceQuote>>, String> {
  QuotesForEventFamily._()
    : super(
        retry: null,
        name: r'quotesForEventProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  QuotesForEventProvider call(String eventId) =>
      QuotesForEventProvider._(argument: eventId, from: this);

  @override
  String toString() => r'quotesForEventProvider';
}

/// Documents (photos/PDF) rattachés à une cible (véhicule, plein, opération…).

@ProviderFor(mediaForOwner)
final mediaForOwnerProvider = MediaForOwnerFamily._();

/// Documents (photos/PDF) rattachés à une cible (véhicule, plein, opération…).

final class MediaForOwnerProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MediaItem>>,
          List<MediaItem>,
          FutureOr<List<MediaItem>>
        >
    with $FutureModifier<List<MediaItem>>, $FutureProvider<List<MediaItem>> {
  /// Documents (photos/PDF) rattachés à une cible (véhicule, plein, opération…).
  MediaForOwnerProvider._({
    required MediaForOwnerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'mediaForOwnerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mediaForOwnerHash();

  @override
  String toString() {
    return r'mediaForOwnerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<MediaItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MediaItem>> create(Ref ref) {
    final argument = this.argument as String;
    return mediaForOwner(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MediaForOwnerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mediaForOwnerHash() => r'04bddcd76a14095304ead5cf73a1586d007cffee';

/// Documents (photos/PDF) rattachés à une cible (véhicule, plein, opération…).

final class MediaForOwnerFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<MediaItem>>, String> {
  MediaForOwnerFamily._()
    : super(
        retry: null,
        name: r'mediaForOwnerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Documents (photos/PDF) rattachés à une cible (véhicule, plein, opération…).

  MediaForOwnerProvider call(String ownerId) =>
      MediaForOwnerProvider._(argument: ownerId, from: this);

  @override
  String toString() => r'mediaForOwnerProvider';
}

/// Synthèse TCO (mon achat + carburant + entretien + autres frais depuis mon achat).

@ProviderFor(financeSummary)
final financeSummaryProvider = FinanceSummaryFamily._();

/// Synthèse TCO (mon achat + carburant + entretien + autres frais depuis mon achat).

final class FinanceSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<TcoSummary>,
          TcoSummary,
          FutureOr<TcoSummary>
        >
    with $FutureModifier<TcoSummary>, $FutureProvider<TcoSummary> {
  /// Synthèse TCO (mon achat + carburant + entretien + autres frais depuis mon achat).
  FinanceSummaryProvider._({
    required FinanceSummaryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'financeSummaryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$financeSummaryHash();

  @override
  String toString() {
    return r'financeSummaryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TcoSummary> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<TcoSummary> create(Ref ref) {
    final argument = this.argument as String;
    return financeSummary(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FinanceSummaryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$financeSummaryHash() => r'585fdba961d1755e0ef27c0b1facec0cbca164b8';

/// Synthèse TCO (mon achat + carburant + entretien + autres frais depuis mon achat).

final class FinanceSummaryFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TcoSummary>, String> {
  FinanceSummaryFamily._()
    : super(
        retry: null,
        name: r'financeSummaryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Synthèse TCO (mon achat + carburant + entretien + autres frais depuis mon achat).

  FinanceSummaryProvider call(String vehicleId) =>
      FinanceSummaryProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'financeSummaryProvider';
}

/// Km courant dérivé localement (MAX odometer toutes saisies).

@ProviderFor(currentOdometer)
final currentOdometerProvider = CurrentOdometerFamily._();

/// Km courant dérivé localement (MAX odometer toutes saisies).

final class CurrentOdometerProvider
    extends $FunctionalProvider<AsyncValue<int?>, int?, FutureOr<int?>>
    with $FutureModifier<int?>, $FutureProvider<int?> {
  /// Km courant dérivé localement (MAX odometer toutes saisies).
  CurrentOdometerProvider._({
    required CurrentOdometerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'currentOdometerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$currentOdometerHash();

  @override
  String toString() {
    return r'currentOdometerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int?> create(Ref ref) {
    final argument = this.argument as String;
    return currentOdometer(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CurrentOdometerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$currentOdometerHash() => r'3de72d935e6937e152f3a187a365bbd1f321662a';

/// Km courant dérivé localement (MAX odometer toutes saisies).

final class CurrentOdometerFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int?>, String> {
  CurrentOdometerFamily._()
    : super(
        retry: null,
        name: r'currentOdometerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Km courant dérivé localement (MAX odometer toutes saisies).

  CurrentOdometerProvider call(String vehicleId) =>
      CurrentOdometerProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'currentOdometerProvider';
}

@ProviderFor(averageConsumption)
final averageConsumptionProvider = AverageConsumptionFamily._();

final class AverageConsumptionProvider
    extends $FunctionalProvider<AsyncValue<double?>, double?, FutureOr<double?>>
    with $FutureModifier<double?>, $FutureProvider<double?> {
  AverageConsumptionProvider._({
    required AverageConsumptionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'averageConsumptionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$averageConsumptionHash();

  @override
  String toString() {
    return r'averageConsumptionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<double?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double?> create(Ref ref) {
    final argument = this.argument as String;
    return averageConsumption(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AverageConsumptionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$averageConsumptionHash() =>
    r'fdfcd0b286434e9336ba9a4464f9440783403872';

final class AverageConsumptionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<double?>, String> {
  AverageConsumptionFamily._()
    : super(
        retry: null,
        name: r'averageConsumptionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AverageConsumptionProvider call(String vehicleId) =>
      AverageConsumptionProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'averageConsumptionProvider';
}

/// Échéances triées par urgence (en retard, puis bientôt, puis à venir).

@ProviderFor(dueTasks)
final dueTasksProvider = DueTasksFamily._();

/// Échéances triées par urgence (en retard, puis bientôt, puis à venir).

final class DueTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DueTask>>,
          List<DueTask>,
          FutureOr<List<DueTask>>
        >
    with $FutureModifier<List<DueTask>>, $FutureProvider<List<DueTask>> {
  /// Échéances triées par urgence (en retard, puis bientôt, puis à venir).
  DueTasksProvider._({
    required DueTasksFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'dueTasksProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dueTasksHash();

  @override
  String toString() {
    return r'dueTasksProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<DueTask>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<DueTask>> create(Ref ref) {
    final argument = this.argument as String;
    return dueTasks(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DueTasksProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dueTasksHash() => r'34166c6cab9b33d495611c573e79672d5536402c';

/// Échéances triées par urgence (en retard, puis bientôt, puis à venir).

final class DueTasksFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<DueTask>>, String> {
  DueTasksFamily._()
    : super(
        retry: null,
        name: r'dueTasksProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Échéances triées par urgence (en retard, puis bientôt, puis à venir).

  DueTasksProvider call(String vehicleId) =>
      DueTasksProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'dueTasksProvider';
}
