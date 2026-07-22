import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/services/stats.service.dart';
import 'package:motorz/core/domain/model/fuel_entry.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';

/// Séries alimentant les graphes de l'écran Statistiques (§5.9).
void main() {
  final vehicleId = UuidValue.generate();

  FuelEntry fuel(DateTime date, int odo) => FuelEntry(
        id: UuidValue.generate(),
        vehicleId: vehicleId,
        date: date,
        odometer: odo,
        volumeLiters: 40,
        updatedAt: DateTime.utc(2026, 1, 1),
      );

  test('les km sont imputés au mois du plein qui clôt le segment', () {
    final series = StatsService.kmPerMonth([
      fuel(DateTime(2026, 1, 10), 100000),
      fuel(DateTime(2026, 2, 5), 100400),
      fuel(DateTime(2026, 2, 25), 100700),
    ]);

    // Janvier n'ouvre aucune barre : le premier plein ne clôt aucun segment,
    // on ignore les km parcourus avant lui. 400 + 300 se cumulent en février.
    expect(series, [(month: DateTime(2026, 2), km: 700)]);
  });

  test('un mois sans plein vaut 0 plutôt que de disparaître du graphe', () {
    final series = StatsService.kmPerMonth([
      fuel(DateTime(2026, 1, 10), 100000),
      fuel(DateTime(2026, 2, 5), 100400),
      fuel(DateTime(2026, 5, 10), 101000),
    ]);

    expect(series.map((p) => p.month),
        [DateTime(2026, 2), DateTime(2026, 3), DateTime(2026, 4), DateTime(2026, 5)]);
    expect(series.map((p) => p.km), [400, 0, 0, 600]);
  });

  test('seuls les derniers mois sont retenus, les plus récents', () {
    final series = StatsService.kmPerMonth(
      [for (var m = 1; m <= 12; m++) fuel(DateTime(2026, m, 10), 100000 + m * 500)],
      maxMonths: 3,
    );

    expect(series.map((p) => p.month),
        [DateTime(2026, 10), DateTime(2026, 11), DateTime(2026, 12)]);
  });

  test('deux pleins au même compteur ne comptent pas de distance', () {
    // Cas réel : on fait le plein à la pompe puis on complète un bidon, sans
    // avoir roulé entre les deux.
    final series = StatsService.kmPerMonth([
      fuel(DateTime(2026, 1, 10), 100000),
      fuel(DateTime(2026, 2, 5), 100400),
      fuel(DateTime(2026, 2, 5), 100400),
    ]);

    expect(series.last, (month: DateTime(2026, 2), km: 400));
  });

  test('série vide sans plein exploitable', () {
    expect(StatsService.kmPerMonth([]), isEmpty);
    expect(StatsService.kmPerMonth([fuel(DateTime(2026, 1, 10), 100000)]), isEmpty);
  });
}
