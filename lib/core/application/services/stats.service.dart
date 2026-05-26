import 'package:motorz/core/domain/model/fuel_entry.dart';

/// Point d'une série temporelle (graphes §5.9).
typedef SeriesPoint = ({DateTime date, double value});

/// Préparation des séries statistiques — pur, calculé localement.
abstract final class StatsService {
  /// Consommation L/100 km par segment entre pleins consécutifs (volume du
  /// plein rapporté aux km parcourus depuis le précédent).
  static List<SeriesPoint> consumptionSeries(List<FuelEntry> fuel) {
    final f = fuel.where((e) => e.volumeLiters != null).toList()
      ..sort((a, b) => a.odometer.compareTo(b.odometer));
    final out = <SeriesPoint>[];
    for (var i = 1; i < f.length; i++) {
      final dist = f[i].odometer - f[i - 1].odometer;
      final vol = f[i].volumeLiters;
      if (dist > 0 && vol != null) {
        out.add((date: f[i].date, value: vol / dist * 100));
      }
    }
    return out;
  }

  /// Prix au litre payé dans le temps.
  static List<SeriesPoint> pricePerLiterSeries(List<FuelEntry> fuel) {
    final out = <SeriesPoint>[];
    for (final e in fuel) {
      final price = e.pricePerLiter ??
          ((e.totalCost != null && e.volumeLiters != null && e.volumeLiters! > 0)
              ? e.totalCost! / e.volumeLiters!
              : null);
      if (price != null) out.add((date: e.date, value: price));
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  /// Km parcourus par mois (clé `YYYY-MM`) — basé sur la progression du compteur.
  static Map<String, int> kmPerMonth(List<FuelEntry> fuel) {
    final f = fuel.toList()..sort((a, b) => a.odometer.compareTo(b.odometer));
    final out = <String, int>{};
    for (var i = 1; i < f.length; i++) {
      final dist = f[i].odometer - f[i - 1].odometer;
      if (dist <= 0) continue;
      final key = '${f[i].date.year}-${f[i].date.month.toString().padLeft(2, '0')}';
      out[key] = (out[key] ?? 0) + dist;
    }
    return out;
  }
}
