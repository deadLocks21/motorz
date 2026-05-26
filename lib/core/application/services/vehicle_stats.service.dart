import 'package:motorz/core/domain/model/fuel_entry.dart';
import 'package:motorz/core/domain/model/maintenance_event.dart';
import 'package:motorz/core/domain/model/tire_pressure_entry.dart';

/// Calculs dérivés d'un véhicule — faits **localement** (offline-first).
abstract final class VehicleStatsService {
  /// Km courant = MAX(odometer) sur toutes les saisies.
  static int? currentOdometer({
    List<FuelEntry> fuel = const [],
    List<MaintenanceEvent> maintenance = const [],
    List<TirePressureEntry> tires = const [],
  }) {
    final odos = <int>[
      ...fuel.map((e) => e.odometer),
      ...maintenance.map((e) => e.odometer),
      ...tires.map((e) => e.odometer),
    ];
    if (odos.isEmpty) return null;
    return odos.reduce((a, b) => a > b ? a : b);
  }

  /// Consommation moyenne (L/100 km) sur la plage de km couverte par les pleins
  /// renseignés en volume. Approximation assumée (cf. brief §5.3).
  static double? averageConsumption(List<FuelEntry> fuel) {
    final withVolume = fuel.where((e) => e.volumeLiters != null).toList()
      ..sort((a, b) => a.odometer.compareTo(b.odometer));
    if (withVolume.length < 2) return null;
    final distance = withVolume.last.odometer - withVolume.first.odometer;
    if (distance <= 0) return null;
    // On ne compte pas le volume du premier plein (il a rempli avant la plage).
    final volume = withVolume.skip(1).fold<double>(0, (s, e) => s + (e.volumeLiters ?? 0));
    if (volume <= 0) return null;
    return volume / distance * 100;
  }

  /// Total dépensé en carburant.
  static double totalFuelCost(List<FuelEntry> fuel) {
    return fuel.fold<double>(0, (s, e) => s + (e.totalCost ?? 0));
  }
}
