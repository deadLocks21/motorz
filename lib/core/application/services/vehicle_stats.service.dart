import 'package:motorz/core/domain/model/fuel_entry.dart';
import 'package:motorz/core/domain/model/maintenance_operation.dart';
import 'package:motorz/core/domain/model/tire_mount.dart';
import 'package:motorz/core/domain/model/tire_pressure_entry.dart';

/// Consommation moyenne, avec la date du dernier plein qui entre dans le calcul
/// (« moy. 6,42 L/100 au 14/07/2026 »). `asOf` est nul si aucun plein retenu
/// n'est daté (un plein peut n'avoir qu'un kilométrage, cf. [FuelEntry.date]).
typedef ConsumptionAverage = ({double value, DateTime? asOf});

/// Calculs dérivés d'un véhicule — faits **localement** (offline-first).
abstract final class VehicleStatsService {
  /// Km courant = MAX(odometer) sur toutes les saisies (pleins, entretien,
  /// relevés de pression, et bornes de montage/démontage des pneus).
  static int? currentOdometer({
    List<FuelEntry> fuel = const [],
    List<Operation> operations = const [],
    List<TirePressureEntry> tires = const [],
    List<TireMount> mounts = const [],
  }) {
    final odos = <int>[
      ...fuel.map((e) => e.odometer).whereType<int>(),
      ...operations.map((e) => e.odometer),
      ...tires.map((e) => e.odometer),
      ...mounts.map((e) => e.mountedOdometer),
      ...mounts.map((e) => e.dismountedOdometer).whereType<int>(),
    ];
    if (odos.isEmpty) return null;
    return odos.reduce((a, b) => a > b ? a : b);
  }

  /// Consommation moyenne (L/100 km) sur la plage de km couverte par les pleins
  /// renseignés en volume, et date du dernier plein retenu — la moyenne est un
  /// instantané, elle vaut « à cette date ». Approximation assumée (brief §5.3).
  static ConsumptionAverage? consumptionAverage(List<FuelEntry> fuel) {
    final withVolume = fuel
        .where((e) => e.volumeLiters != null && e.odometer != null)
        .toList()
      ..sort((a, b) => a.odometer!.compareTo(b.odometer!));
    if (withVolume.length < 2) return null;
    final distance = withVolume.last.odometer! - withVolume.first.odometer!;
    if (distance <= 0) return null;
    // On ne compte pas le volume du premier plein (il a rempli avant la plage).
    final volume = withVolume.skip(1).fold<double>(0, (s, e) => s + (e.volumeLiters ?? 0));
    if (volume <= 0) return null;
    final dates = withVolume.map((e) => e.date).whereType<DateTime>();
    return (
      value: volume / distance * 100,
      asOf: dates.isEmpty ? null : dates.reduce((a, b) => a.isAfter(b) ? a : b),
    );
  }

  /// Consommation moyenne seule (L/100 km) — cf. [consumptionAverage].
  static double? averageConsumption(List<FuelEntry> fuel) => consumptionAverage(fuel)?.value;

  /// Total dépensé en carburant.
  static double totalFuelCost(List<FuelEntry> fuel) {
    return fuel.fold<double>(0, (s, e) => s + (e.totalCost ?? 0));
  }
}
