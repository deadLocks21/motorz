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

String _$fuelEntriesHash() => r'a02a94de43a3a69f83ea0e61198107d113299f66';

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

/// Stations déjà saisies, tous véhicules confondus — pour l'autocomplétion du
/// champ « Station » d'un plein (on fait le plein aux mêmes endroits quel que
/// soit le véhicule). Voir [rankStations] pour l'ordre.

@ProviderFor(knownStations)
final knownStationsProvider = KnownStationsProvider._();

/// Stations déjà saisies, tous véhicules confondus — pour l'autocomplétion du
/// champ « Station » d'un plein (on fait le plein aux mêmes endroits quel que
/// soit le véhicule). Voir [rankStations] pour l'ordre.

final class KnownStationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// Stations déjà saisies, tous véhicules confondus — pour l'autocomplétion du
  /// champ « Station » d'un plein (on fait le plein aux mêmes endroits quel que
  /// soit le véhicule). Voir [rankStations] pour l'ordre.
  KnownStationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'knownStationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$knownStationsHash();

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    return knownStations(ref);
  }
}

String _$knownStationsHash() => r'7fe2e1b695f2d19d324e760df8f014c60af2874d';

/// Prestataires déjà saisis, tous véhicules confondus — pour l'autocomplétion du
/// champ « Prestataire » d'une opération d'entretien **et d'un devis** (on revient
/// souvent au même garage quel que soit le véhicule). Voir [rankProviders].

@ProviderFor(knownProviders)
final knownProvidersProvider = KnownProvidersProvider._();

/// Prestataires déjà saisis, tous véhicules confondus — pour l'autocomplétion du
/// champ « Prestataire » d'une opération d'entretien **et d'un devis** (on revient
/// souvent au même garage quel que soit le véhicule). Voir [rankProviders].

final class KnownProvidersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// Prestataires déjà saisis, tous véhicules confondus — pour l'autocomplétion du
  /// champ « Prestataire » d'une opération d'entretien **et d'un devis** (on revient
  /// souvent au même garage quel que soit le véhicule). Voir [rankProviders].
  KnownProvidersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'knownProvidersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$knownProvidersHash();

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    return knownProviders(ref);
  }
}

String _$knownProvidersHash() => r'7274d876ef4d5e009009345bb4b596e204b453b5';

/// Intitulés des échéances « À prévoir » du véhicule — pour l'autocomplétion du
/// champ « Pièce » d'une ligne d'entretien. Saisir une ligne au même intitulé
/// qu'une échéance la remet à zéro (rapprochement par intitulé, cf. À prévoir) :
/// on propose donc directement les échéances en attente plutôt que des postes
/// déjà saisis. Contrairement aux stations/prestataires (tous véhicules
/// confondus), les échéances sont propres au véhicule. Voir [rankDueTitles] pour
/// l'ordre.

@ProviderFor(knownPartLabels)
final knownPartLabelsProvider = KnownPartLabelsFamily._();

/// Intitulés des échéances « À prévoir » du véhicule — pour l'autocomplétion du
/// champ « Pièce » d'une ligne d'entretien. Saisir une ligne au même intitulé
/// qu'une échéance la remet à zéro (rapprochement par intitulé, cf. À prévoir) :
/// on propose donc directement les échéances en attente plutôt que des postes
/// déjà saisis. Contrairement aux stations/prestataires (tous véhicules
/// confondus), les échéances sont propres au véhicule. Voir [rankDueTitles] pour
/// l'ordre.

final class KnownPartLabelsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// Intitulés des échéances « À prévoir » du véhicule — pour l'autocomplétion du
  /// champ « Pièce » d'une ligne d'entretien. Saisir une ligne au même intitulé
  /// qu'une échéance la remet à zéro (rapprochement par intitulé, cf. À prévoir) :
  /// on propose donc directement les échéances en attente plutôt que des postes
  /// déjà saisis. Contrairement aux stations/prestataires (tous véhicules
  /// confondus), les échéances sont propres au véhicule. Voir [rankDueTitles] pour
  /// l'ordre.
  KnownPartLabelsProvider._({
    required KnownPartLabelsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'knownPartLabelsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$knownPartLabelsHash();

  @override
  String toString() {
    return r'knownPartLabelsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    final argument = this.argument as String;
    return knownPartLabels(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is KnownPartLabelsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$knownPartLabelsHash() => r'02908c3f25d3e65a031dd6b7fae41d49eb158fa4';

/// Intitulés des échéances « À prévoir » du véhicule — pour l'autocomplétion du
/// champ « Pièce » d'une ligne d'entretien. Saisir une ligne au même intitulé
/// qu'une échéance la remet à zéro (rapprochement par intitulé, cf. À prévoir) :
/// on propose donc directement les échéances en attente plutôt que des postes
/// déjà saisis. Contrairement aux stations/prestataires (tous véhicules
/// confondus), les échéances sont propres au véhicule. Voir [rankDueTitles] pour
/// l'ordre.

final class KnownPartLabelsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<String>>, String> {
  KnownPartLabelsFamily._()
    : super(
        retry: null,
        name: r'knownPartLabelsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Intitulés des échéances « À prévoir » du véhicule — pour l'autocomplétion du
  /// champ « Pièce » d'une ligne d'entretien. Saisir une ligne au même intitulé
  /// qu'une échéance la remet à zéro (rapprochement par intitulé, cf. À prévoir) :
  /// on propose donc directement les échéances en attente plutôt que des postes
  /// déjà saisis. Contrairement aux stations/prestataires (tous véhicules
  /// confondus), les échéances sont propres au véhicule. Voir [rankDueTitles] pour
  /// l'ordre.

  KnownPartLabelsProvider call(String vehicleId) =>
      KnownPartLabelsProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'knownPartLabelsProvider';
}

/// Opérations d'entretien réalisées du véhicule (plus récentes d'abord).

@ProviderFor(operations)
final operationsProvider = OperationsFamily._();

/// Opérations d'entretien réalisées du véhicule (plus récentes d'abord).

final class OperationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Operation>>,
          List<Operation>,
          FutureOr<List<Operation>>
        >
    with $FutureModifier<List<Operation>>, $FutureProvider<List<Operation>> {
  /// Opérations d'entretien réalisées du véhicule (plus récentes d'abord).
  OperationsProvider._({
    required OperationsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'operationsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$operationsHash();

  @override
  String toString() {
    return r'operationsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Operation>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Operation>> create(Ref ref) {
    final argument = this.argument as String;
    return operations(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is OperationsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$operationsHash() => r'86a4c69096d90d14f3cd45418d6854f45d188cdd';

/// Opérations d'entretien réalisées du véhicule (plus récentes d'abord).

final class OperationsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Operation>>, String> {
  OperationsFamily._()
    : super(
        retry: null,
        name: r'operationsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Opérations d'entretien réalisées du véhicule (plus récentes d'abord).

  OperationsProvider call(String vehicleId) =>
      OperationsProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'operationsProvider';
}

/// Lignes d'une opération (un poste fait par ligne).

@ProviderFor(operationLines)
final operationLinesProvider = OperationLinesFamily._();

/// Lignes d'une opération (un poste fait par ligne).

final class OperationLinesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<OperationLine>>,
          List<OperationLine>,
          FutureOr<List<OperationLine>>
        >
    with
        $FutureModifier<List<OperationLine>>,
        $FutureProvider<List<OperationLine>> {
  /// Lignes d'une opération (un poste fait par ligne).
  OperationLinesProvider._({
    required OperationLinesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'operationLinesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$operationLinesHash();

  @override
  String toString() {
    return r'operationLinesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<OperationLine>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<OperationLine>> create(Ref ref) {
    final argument = this.argument as String;
    return operationLines(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is OperationLinesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$operationLinesHash() => r'cc3a61d93ad10659726e3a0dc480085554dc4646';

/// Lignes d'une opération (un poste fait par ligne).

final class OperationLinesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<OperationLine>>, String> {
  OperationLinesFamily._()
    : super(
        retry: null,
        name: r'operationLinesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Lignes d'une opération (un poste fait par ligne).

  OperationLinesProvider call(String operationId) =>
      OperationLinesProvider._(argument: operationId, from: this);

  @override
  String toString() => r'operationLinesProvider';
}

/// Toutes les lignes d'opérations du véhicule (pour la dérivation des échéances).

@ProviderFor(linesForVehicle)
final linesForVehicleProvider = LinesForVehicleFamily._();

/// Toutes les lignes d'opérations du véhicule (pour la dérivation des échéances).

final class LinesForVehicleProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<OperationLine>>,
          List<OperationLine>,
          FutureOr<List<OperationLine>>
        >
    with
        $FutureModifier<List<OperationLine>>,
        $FutureProvider<List<OperationLine>> {
  /// Toutes les lignes d'opérations du véhicule (pour la dérivation des échéances).
  LinesForVehicleProvider._({
    required LinesForVehicleFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'linesForVehicleProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$linesForVehicleHash();

  @override
  String toString() {
    return r'linesForVehicleProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<OperationLine>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<OperationLine>> create(Ref ref) {
    final argument = this.argument as String;
    return linesForVehicle(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LinesForVehicleProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$linesForVehicleHash() => r'b6eafbb504289f2f174679ea6eb07d29c64b0d6e';

/// Toutes les lignes d'opérations du véhicule (pour la dérivation des échéances).

final class LinesForVehicleFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<OperationLine>>, String> {
  LinesForVehicleFamily._()
    : super(
        retry: null,
        name: r'linesForVehicleProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Toutes les lignes d'opérations du véhicule (pour la dérivation des échéances).

  LinesForVehicleProvider call(String vehicleId) =>
      LinesForVehicleProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'linesForVehicleProvider';
}

/// Plans (échéances à prévoir) du véhicule.

@ProviderFor(plans)
final plansProvider = PlansFamily._();

/// Plans (échéances à prévoir) du véhicule.

final class PlansProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Plan>>,
          List<Plan>,
          FutureOr<List<Plan>>
        >
    with $FutureModifier<List<Plan>>, $FutureProvider<List<Plan>> {
  /// Plans (échéances à prévoir) du véhicule.
  PlansProvider._({
    required PlansFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'plansProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$plansHash();

  @override
  String toString() {
    return r'plansProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Plan>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Plan>> create(Ref ref) {
    final argument = this.argument as String;
    return plans(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PlansProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$plansHash() => r'df2a9f52683de121f6427b25284c4ac094760bc0';

/// Plans (échéances à prévoir) du véhicule.

final class PlansFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Plan>>, String> {
  PlansFamily._()
    : super(
        retry: null,
        name: r'plansProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Plans (échéances à prévoir) du véhicule.

  PlansProvider call(String vehicleId) =>
      PlansProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'plansProvider';
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

/// Inventaire de pneus du véhicule (montés + en stock).

@ProviderFor(tires)
final tiresProvider = TiresFamily._();

/// Inventaire de pneus du véhicule (montés + en stock).

final class TiresProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Tire>>,
          List<Tire>,
          FutureOr<List<Tire>>
        >
    with $FutureModifier<List<Tire>>, $FutureProvider<List<Tire>> {
  /// Inventaire de pneus du véhicule (montés + en stock).
  TiresProvider._({
    required TiresFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'tiresProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tiresHash();

  @override
  String toString() {
    return r'tiresProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Tire>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Tire>> create(Ref ref) {
    final argument = this.argument as String;
    return tires(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TiresProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tiresHash() => r'ad86b493e939cad66370c104f3cf9bb05e796df2';

/// Inventaire de pneus du véhicule (montés + en stock).

final class TiresFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Tire>>, String> {
  TiresFamily._()
    : super(
        retry: null,
        name: r'tiresProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Inventaire de pneus du véhicule (montés + en stock).

  TiresProvider call(String vehicleId) =>
      TiresProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'tiresProvider';
}

/// Journal de montages du véhicule (intervalles ouverts = pneus montés).

@ProviderFor(tireMounts)
final tireMountsProvider = TireMountsFamily._();

/// Journal de montages du véhicule (intervalles ouverts = pneus montés).

final class TireMountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TireMount>>,
          List<TireMount>,
          FutureOr<List<TireMount>>
        >
    with $FutureModifier<List<TireMount>>, $FutureProvider<List<TireMount>> {
  /// Journal de montages du véhicule (intervalles ouverts = pneus montés).
  TireMountsProvider._({
    required TireMountsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'tireMountsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tireMountsHash();

  @override
  String toString() {
    return r'tireMountsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TireMount>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TireMount>> create(Ref ref) {
    final argument = this.argument as String;
    return tireMounts(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TireMountsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tireMountsHash() => r'7234ec22408ebbd80753d49a68ba2144b6fed3ce';

/// Journal de montages du véhicule (intervalles ouverts = pneus montés).

final class TireMountsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<TireMount>>, String> {
  TireMountsFamily._()
    : super(
        retry: null,
        name: r'tireMountsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Journal de montages du véhicule (intervalles ouverts = pneus montés).

  TireMountsProvider call(String vehicleId) =>
      TireMountsProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'tireMountsProvider';
}

@ProviderFor(tireFleet)
final tireFleetProvider = TireFleetFamily._();

final class TireFleetProvider
    extends
        $FunctionalProvider<
          AsyncValue<TireFleet>,
          TireFleet,
          FutureOr<TireFleet>
        >
    with $FutureModifier<TireFleet>, $FutureProvider<TireFleet> {
  TireFleetProvider._({
    required TireFleetFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'tireFleetProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tireFleetHash();

  @override
  String toString() {
    return r'tireFleetProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TireFleet> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<TireFleet> create(Ref ref) {
    final argument = this.argument as String;
    return tireFleet(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TireFleetProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tireFleetHash() => r'0a9f73ebd2d18064ce6fa6bb8cfd80ee186d5a59';

final class TireFleetFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TireFleet>, String> {
  TireFleetFamily._()
    : super(
        retry: null,
        name: r'tireFleetProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TireFleetProvider call(String vehicleId) =>
      TireFleetProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'tireFleetProvider';
}

/// Marques de pneus déjà saisies (tous véhicules) — autocomplétion du champ
/// « Marque ». Voir [rankTireBrands].

@ProviderFor(knownTireBrands)
final knownTireBrandsProvider = KnownTireBrandsProvider._();

/// Marques de pneus déjà saisies (tous véhicules) — autocomplétion du champ
/// « Marque ». Voir [rankTireBrands].

final class KnownTireBrandsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// Marques de pneus déjà saisies (tous véhicules) — autocomplétion du champ
  /// « Marque ». Voir [rankTireBrands].
  KnownTireBrandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'knownTireBrandsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$knownTireBrandsHash();

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    return knownTireBrands(ref);
  }
}

String _$knownTireBrandsHash() => r'857bd94c25534e19b555607268c7bd7280740e53';

/// Tailles de pneus déjà saisies (tous véhicules) — autocomplétion du champ
/// « Taille ». Voir [rankTireSizes].

@ProviderFor(knownTireSizes)
final knownTireSizesProvider = KnownTireSizesProvider._();

/// Tailles de pneus déjà saisies (tous véhicules) — autocomplétion du champ
/// « Taille ». Voir [rankTireSizes].

final class KnownTireSizesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// Tailles de pneus déjà saisies (tous véhicules) — autocomplétion du champ
  /// « Taille ». Voir [rankTireSizes].
  KnownTireSizesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'knownTireSizesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$knownTireSizesHash();

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    return knownTireSizes(ref);
  }
}

String _$knownTireSizesHash() => r'ea9a7a294d55ef3047ad0fef56db899a1a625336';

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

String _$quotesForVehicleHash() => r'4db57c794380da03108947fce4e7bcf3b963e069';

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

@ProviderFor(quotesForOperation)
final quotesForOperationProvider = QuotesForOperationFamily._();

final class QuotesForOperationProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MaintenanceQuote>>,
          List<MaintenanceQuote>,
          FutureOr<List<MaintenanceQuote>>
        >
    with
        $FutureModifier<List<MaintenanceQuote>>,
        $FutureProvider<List<MaintenanceQuote>> {
  QuotesForOperationProvider._({
    required QuotesForOperationFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'quotesForOperationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$quotesForOperationHash();

  @override
  String toString() {
    return r'quotesForOperationProvider'
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
    return quotesForOperation(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is QuotesForOperationProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$quotesForOperationHash() =>
    r'df34b6d19524d1d5777f1b70526a3654b5e9f5c2';

final class QuotesForOperationFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<MaintenanceQuote>>, String> {
  QuotesForOperationFamily._()
    : super(
        retry: null,
        name: r'quotesForOperationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  QuotesForOperationProvider call(String operationId) =>
      QuotesForOperationProvider._(argument: operationId, from: this);

  @override
  String toString() => r'quotesForOperationProvider';
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

String _$financeSummaryHash() => r'694536ddab875c4dce3217bb12602182f7d84099';

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

String _$currentOdometerHash() => r'e5664c4299d58e3b7c2b35b896241b8e21ee12ba';

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
/// Projection pure : plans + historique (dernière réalisation dérivée).

@ProviderFor(duePlans)
final duePlansProvider = DuePlansFamily._();

/// Échéances triées par urgence (en retard, puis bientôt, puis à venir).
/// Projection pure : plans + historique (dernière réalisation dérivée).

final class DuePlansProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DuePlan>>,
          List<DuePlan>,
          FutureOr<List<DuePlan>>
        >
    with $FutureModifier<List<DuePlan>>, $FutureProvider<List<DuePlan>> {
  /// Échéances triées par urgence (en retard, puis bientôt, puis à venir).
  /// Projection pure : plans + historique (dernière réalisation dérivée).
  DuePlansProvider._({
    required DuePlansFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'duePlansProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$duePlansHash();

  @override
  String toString() {
    return r'duePlansProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<DuePlan>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<DuePlan>> create(Ref ref) {
    final argument = this.argument as String;
    return duePlans(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DuePlansProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$duePlansHash() => r'8b8a36f5ea2baf1567d03f4368fb5cd18ca86610';

/// Échéances triées par urgence (en retard, puis bientôt, puis à venir).
/// Projection pure : plans + historique (dernière réalisation dérivée).

final class DuePlansFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<DuePlan>>, String> {
  DuePlansFamily._()
    : super(
        retry: null,
        name: r'duePlansProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Échéances triées par urgence (en retard, puis bientôt, puis à venir).
  /// Projection pure : plans + historique (dernière réalisation dérivée).

  DuePlansProvider call(String vehicleId) =>
      DuePlansProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'duePlansProvider';
}
