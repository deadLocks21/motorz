import 'package:motorz/core/domain/model/fuel_entry.dart';

/// Point d'une série temporelle (graphes §5.9).
typedef SeriesPoint = ({DateTime date, double value});

/// Point de la courbe de conso. [cutBefore] signale que le point précédent
/// n'est pas le segment adjacent (chaîne rompue, plein sans volume, plein sans
/// date) : la ligne ne doit pas être tracée depuis lui.
typedef ConsumptionPoint = ({DateTime date, double value, bool cutBefore});

/// Distance parcourue sur un mois donné (`month` est calé au 1er du mois).
typedef MonthlyDistance = ({DateTime month, int km});

/// Portion mesurable de l'historique : les litres versés entre deux pleins
/// bornés en kilométrage. [liters] est le volume du plein qui **ferme** le
/// segment — le niveau de cuve est supposé identique aux deux bornes, ce qui
/// rend inutile la distinction plein complet/partiel (§5.3).
typedef ConsumptionSegment = ({FuelEntry from, FuelEntry to, int km, double liters});

/// Préparation des séries statistiques — pur, calculé localement.
abstract final class StatsService {
  /// Découpe l'historique en segments mesurables. **Source unique** de la conso :
  /// la moyenne (VehicleStatsService) et la courbe en dérivent toutes deux, donc
  /// elles ne peuvent plus diverger.
  ///
  /// Un plein reste une **borne** dès qu'il porte un kilométrage, même sans
  /// volume : sinon le segment suivant s'étirerait jusqu'à la borne d'avant et
  /// diluerait ses litres sur une distance qu'ils n'ont pas parcourue. Seul le
  /// segment que ce plein *ferme* est écarté, faute de connaître ses litres.
  ///
  /// Un segment écarté l'est **entièrement** — ni ses litres, ni ses km. Ne
  /// retirer que les litres remplacerait une conso trop basse par une pire.
  static List<ConsumptionSegment> consumptionSegments(List<FuelEntry> fuel) {
    final bounds = fuel.where((e) => e.odometer != null).toList()
      ..sort((a, b) => a.odometer!.compareTo(b.odometer!));
    final out = <ConsumptionSegment>[];
    for (var i = 1; i < bounds.length; i++) {
      final to = bounds[i];
      // Chaîne rompue : il manque des litres dont on ignore le nombre.
      if (to.missedFillBefore) continue;
      final from = bounds[i - 1];
      final km = to.odometer! - from.odometer!;
      final liters = to.volumeLiters;
      if (km <= 0 || liters == null || liters <= 0) continue;
      out.add((from: from, to: to, km: km, liters: liters));
    }
    return out;
  }

  /// Consommation L/100 km par segment, datée du plein qui le ferme. Un segment
  /// sans date reste dans la moyenne mais ne peut pas être placé sur un axe de
  /// temps — il coupe la ligne au lieu de la faire mentir.
  static List<ConsumptionPoint> consumptionSeries(List<FuelEntry> fuel) {
    final out = <ConsumptionPoint>[];
    FuelEntry? previousTo;
    for (final s in consumptionSegments(fuel)) {
      final date = s.to.date;
      if (date == null) {
        previousTo = null;
        continue;
      }
      out.add((
        date: date,
        value: s.liters / s.km * 100,
        cutBefore: out.isNotEmpty && s.from != previousTo,
      ));
      previousTo = s.to;
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
  ///
  /// Volontairement insensible à `missedFillBefore` : un plein non saisi fausse
  /// les litres, jamais le compteur — ces kilomètres-là ont bien été parcourus.
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
