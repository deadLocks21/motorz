import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/services/vehicle_stats.service.dart';
import 'package:motorz/core/domain/model/fuel_entry.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';

void main() {
  final vehicleId = UuidValue.generate();

  FuelEntry fuel(int odo, double? volume) => FuelEntry(
        id: UuidValue.generate(),
        vehicleId: vehicleId,
        date: DateTime.utc(2026, 1, odo % 27 + 1),
        odometer: odo,
        volumeLiters: volume,
        updatedAt: DateTime.utc(2026, 1, 1),
      );

  test('km courant = max odometer toutes saisies', () {
    final odo = VehicleStatsService.currentOdometer(
      fuel: [fuel(100000, 40), fuel(100600, 38)],
    );
    expect(odo, 100600);
  });

  test('km courant null sans saisie', () {
    expect(VehicleStatsService.currentOdometer(), isNull);
  });

  test('consommation moyenne = volume (hors 1er plein) / distance * 100', () {
    // 100000 → 100500 (= 500 km), volume du 2e plein = 30 L → 6 L/100.
    final conso = VehicleStatsService.averageConsumption([fuel(100000, 45), fuel(100500, 30)]);
    expect(conso, closeTo(6.0, 0.001));
  });

  test('consommation null avec un seul plein', () {
    expect(VehicleStatsService.averageConsumption([fuel(100000, 40)]), isNull);
  });

  FuelEntry dated(DateTime? date, int odo, double? volume) => FuelEntry(
        id: UuidValue.generate(),
        vehicleId: vehicleId,
        date: date,
        odometer: odo,
        volumeLiters: volume,
        updatedAt: DateTime.utc(2026, 1, 1),
      );

  test('la moyenne est datée du dernier plein qui entre dans le calcul', () {
    final average = VehicleStatsService.consumptionAverage([
      dated(DateTime.utc(2026, 1, 10), 100000, 45),
      dated(DateTime.utc(2026, 2, 14), 100500, 30),
    ]);
    expect(average!.value, closeTo(6.0, 0.001));
    expect(average.asOf, DateTime.utc(2026, 2, 14));
  });

  test('un plein sans date ne prive pas la moyenne de sa date', () {
    // Un plein peut n'avoir qu'un kilométrage : on date alors la moyenne sur le
    // plein daté le plus récent, plutôt que de renoncer à afficher une date.
    final average = VehicleStatsService.consumptionAverage([
      dated(DateTime.utc(2026, 1, 10), 100000, 45),
      dated(DateTime.utc(2026, 2, 14), 100500, 30),
      dated(null, 100900, 25),
    ]);
    expect(average!.asOf, DateTime.utc(2026, 2, 14));
  });
}
