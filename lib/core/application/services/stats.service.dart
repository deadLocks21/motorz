import 'package:motorz/core/domain/model/fuel_entry.dart';

/// Point d'une série temporelle (graphes §5.9).
typedef SeriesPoint = ({DateTime date, double value});

/// Distance parcourue sur un mois donné (`month` est calé au 1er du mois).
typedef MonthlyDistance = ({DateTime month, int km});

/// Préparation des séries statistiques — pur, calculé localement.
abstract final class StatsService {
  /// Consommation L/100 km par segment entre pleins consécutifs (volume du
  /// plein rapporté aux km parcourus depuis le précédent).
  static List<SeriesPoint> consumptionSeries(List<FuelEntry> fuel) {
    final f = fuel
        .where((e) => e.volumeLiters != null && e.odometer != null && e.date != null)
        .toList()
      ..sort((a, b) => a.odometer!.compareTo(b.odometer!));
    final out = <SeriesPoint>[];
    for (var i = 1; i < f.length; i++) {
      final dist = f[i].odometer! - f[i - 1].odometer!;
      final vol = f[i].volumeLiters;
      if (dist > 0 && vol != null) {
        out.add((date: f[i].date!, value: vol / dist * 100));
      }
    }
    return out;
  }

  /// Prix au litre payé dans le temps.
  static List<SeriesPoint> pricePerLiterSeries(List<FuelEntry> fuel) {
    final out = <SeriesPoint>[];
    for (final e in fuel) {
      if (e.date == null) continue;
      final price = e.pricePerLiter ??
          ((e.totalCost != null && e.volumeLiters != null && e.volumeLiters! > 0)
              ? e.totalCost! / e.volumeLiters!
              : null);
      if (price != null) out.add((date: e.date!, value: price));
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  /// Km parcourus par mois — basé sur la progression du compteur entre pleins.
  /// Série continue du plus ancien au plus récent : un mois sans plein vaut 0
  /// (sinon le graphe tasserait une pause de six mois contre le mois suivant),
  /// tronquée aux [maxMonths] derniers mois pour rester lisible.
  static List<MonthlyDistance> kmPerMonth(List<FuelEntry> fuel, {int maxMonths = 12}) {
    final f = fuel.where((e) => e.odometer != null && e.date != null).toList()
      ..sort((a, b) => a.odometer!.compareTo(b.odometer!));
    final byMonth = <DateTime, int>{};
    for (var i = 1; i < f.length; i++) {
      final dist = f[i].odometer! - f[i - 1].odometer!;
      if (dist <= 0) continue;
      final d = f[i].date!.toLocal();
      final key = DateTime(d.year, d.month);
      byMonth[key] = (byMonth[key] ?? 0) + dist;
    }
    if (byMonth.isEmpty) return const [];
    final months = byMonth.keys.toList()..sort();
    final out = <MonthlyDistance>[];
    for (var m = months.first; !m.isAfter(months.last); m = DateTime(m.year, m.month + 1)) {
      out.add((month: m, km: byMonth[m] ?? 0));
    }
    return out.length <= maxMonths ? out : out.sublist(out.length - maxMonths);
  }
}
