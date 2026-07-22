import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/application/services/stats.service.dart';
import 'package:motorz/core/application/services/vehicle_stats.service.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';
import 'package:motorz/ui/utils/format.dart';

/// Statistiques d'un véhicule : conso, prix au litre, km parcourus (§5.9).
/// Les dépenses n'apparaissent pas ici — elles vivent dans l'onglet Finances,
/// qui les ventile déjà (carburant / entretien / assurance & frais).
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key, required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final fuel = ref.watch(fuelEntriesProvider(vehicleId)).value ?? const [];

    final conso = StatsService.consumptionSeries(fuel);
    final prices = StatsService.pricePerLiterSeries(fuel);
    final monthlyKm = StatsService.kmPerMonth(fuel);
    final average = VehicleStatsService.consumptionAverage(fuel);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ChartCard(
            title: 'Consommation',
            subtitle: _averageLabel(average),
            colors: colors,
            child: _LineChart(
              points: [for (final p in conso) (date: p.date, value: p.value)],
              cutBefore: {
                for (var i = 0; i < conso.length; i++)
                  if (conso[i].cutBefore) i,
              },
              unit: 'L/100',
              color: colors.accent,
              colors: colors,
            ),
          ),
          const SizedBox(height: 16),
          _ChartCard(
            title: 'Prix au litre',
            colors: colors,
            child: _LineChart(
              points: prices,
              unit: '€/L',
              color: colors.statusOk,
              colors: colors,
            ),
          ),
          const SizedBox(height: 16),
          _ChartCard(
            title: 'Km parcourus',
            subtitle: _monthlyKmLabel(monthlyKm),
            colors: colors,
            child: _MonthlyKmChart(points: monthlyKm, colors: colors),
          ),
        ],
      ),
    );
  }
}

/// « moy. 6,42 L/100 · au 14/07/2026 » : la moyenne est un instantané calculé
/// sur les pleins connus, on affiche donc la date à laquelle elle est arrêtée.
String? _averageLabel(ConsumptionAverage? average) {
  if (average == null) return null;
  final value = 'moy. ${formatDecimal2(average.value)} L/100';
  return average.asOf == null ? value : '$value · au ${formatDate(average.asOf!)}';
}

String? _monthlyKmLabel(List<MonthlyDistance> points) {
  if (points.isEmpty) return null;
  final total = points.fold<int>(0, (s, p) => s + p.km);
  return 'moy. ${formatKm((total / points.length).round())}/mois';
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.colors,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final AppColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: TextStyle(color: colors.textMuted, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          SizedBox(height: 150, child: child),
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({
    required this.points,
    required this.unit,
    this.cutBefore = const {},
    required this.color,
    required this.colors,
  });

  final List<SeriesPoint> points;
  final String unit;
  /// Index devant lesquels la ligne est rompue (segments non mesurables).
  final Set<int> cutBefore;
  final Color color;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return _EmptyChart(colors: colors);

    // Tout l'axe se calcule en **centièmes, en entiers**. Avec un pas
    // fractionnaire (0,05), la dernière graduation retombe un epsilon à côté de
    // maxY et fl_chart ajoute alors une étiquette de fin en doublon (« 2,00 »
    // deux fois) — ce que le graphe des km, entier par nature, n'a jamais eu.
    final spots = [
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].value * 100),
    ];
    final values = points.map((p) => p.value * 100).toList();
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    // Graduations calées sur un pas rond englobant la plage : au pas libre, une
    // conso entre 2,84 et 2,97 sortait « 2,9 » trois fois de suite.
    final interval = _valueInterval(maxV - minV);
    var lo = (minV / interval).floor();
    var hi = (maxV / interval).ceil();
    if (hi - lo < 3) {
      // Plage quasi plate — tous les pleins au même prix, p. ex. Sans marge, le
      // bas et le haut de l'axe tombent sur la même graduation.
      final grow = 3 - (hi - lo);
      lo -= (grow / 2).ceil();
      hi += grow ~/ 2;
    }
    final minY = (lo * interval).toDouble();
    final maxY = (hi * interval).toDouble();
    // Une date sur [step] en abscisse, la plus récente toujours étiquetée.
    final step = (points.length / 4).ceil();

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colors.textPrimary,
            // Points de bord et sommets de courbe : l'infobulle reste dedans.
            fitInsideVertically: true,
            fitInsideHorizontally: true,
            // Toucher un point donne sa valeur *et* sa date : c'est là que se
            // lit « cette moyenne-là, ce jour-là ».
            getTooltipItems: (touched) => [
              for (final spot in touched)
                LineTooltipItem(
                  '${formatDecimal2(spot.y / 100)} $unit\n${formatDate(points[spot.x.round()].date)}',
                  TextStyle(color: colors.surface, fontSize: 11, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                if ((points.length - 1 - i) % step != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    formatMonthShort(points[i].date),
                    maxLines: 1,
                    style: TextStyle(color: colors.textMuted, fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval.toDouble(),
              getTitlesWidget: (v, _) => Text(
                formatDecimal2(v / 100),
                maxLines: 1,
                style: TextStyle(color: colors.textMuted, fontSize: 10),
              ),
            ),
          ),
        ),
        lineBarsData: _bars(spots),
      ),
    );
  }

  /// Une barre par tronçon continu. Un segment écarté (plein manqué, cf. §5.3)
  /// laisse un **trou** dans la courbe : relier les deux bords prétendrait avoir
  /// mesuré ce qu'on ne sait justement pas. Un tronçon isolé se réduit à un
  /// point — on rallume donc la pastille, sinon il serait invisible.
  List<LineChartBarData> _bars(List<FlSpot> spots) {
    final bars = <LineChartBarData>[];
    var start = 0;
    for (var i = 1; i <= spots.length; i++) {
      if (i < spots.length && !cutBefore.contains(i)) continue;
      final run = spots.sublist(start, i);
      bars.add(LineChartBarData(
        spots: run,
        isCurved: true,
        color: color,
        barWidth: 3,
        dotData: FlDotData(show: run.length == 1),
        belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
      ));
      start = i;
    }
    return bars;
  }
}

/// Pas de graduation rond, **en centièmes**, découpant [range] en ~3. Plancher
/// à 5 : sous cinq centièmes, deux graduations voisines s'arrondiraient au même
/// nombre à deux décimales.
int _valueInterval(double range) {
  const steps = [5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000];
  for (final s in steps) {
    if (range / s <= 3) return s;
  }
  return (range / 3).ceil();
}

class _MonthlyKmChart extends StatelessWidget {
  const _MonthlyKmChart({required this.points, required this.colors});

  final List<MonthlyDistance> points;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return _EmptyChart(colors: colors);

    final maxKm = points.map((p) => p.km).reduce((a, b) => a > b ? a : b).toDouble();
    // Le haut du graphe est calé sur un multiple de la graduation : sinon la
    // dernière étiquette n'est que le rembourrage (« 2,3k » collé à « 2,0k »).
    final interval = _axisInterval((maxKm <= 0 ? 1.0 : maxKm) * 1.15);
    final maxY = ((maxKm <= 0 ? 1.0 : maxKm) * 1.15 / interval).ceil() * interval;
    // Un mois sur [step] est étiqueté : au-delà de quatre libellés, « 03/26 »
    // et son voisin se touchent sur un écran étroit. On compte depuis la fin
    // pour que le mois le plus récent soit toujours de ceux-là.
    final step = (points.length / 4).ceil();

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colors.textPrimary,
            // Sans ça, l'infobulle de la barre la plus haute déborde du cadre
            // et se fait rogner.
            fitInsideVertically: true,
            fitInsideHorizontally: true,
            // Les mois étiquetés en abscisse sont espacés : sans ça, une barre
            // sur deux ne dit pas de quel mois elle parle.
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${formatKm(points[groupIndex].km)}\n${formatMonthShort(points[groupIndex].month)}',
              TextStyle(color: colors.surface, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                if ((points.length - 1 - i) % step != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    formatMonthShort(points[i].month),
                    maxLines: 1,
                    style: TextStyle(color: colors.textMuted, fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval,
              getTitlesWidget: (v, _) => Text(
                _compactKm(v),
                style: TextStyle(color: colors.textMuted, fontSize: 10),
              ),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].km.toDouble(),
                  color: colors.accent,
                  width: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Graduation ronde donnant au plus ~3 libellés sur la hauteur du graphe.
double _axisInterval(double maxY) {
  const steps = [100.0, 250.0, 500.0, 1000.0, 2000.0, 2500.0, 5000.0, 10000.0];
  for (final s in steps) {
    if (maxY / s <= 3) return s;
  }
  return maxY / 3;
}

/// Axe des km : « 1,5k » au-delà du millier, pour ne pas manger la largeur.
String _compactKm(double v) =>
    v >= 1000 ? '${formatDecimal1(v / 1000)}k' : v.toStringAsFixed(0);

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.colors});
  final AppColors colors;

  @override
  Widget build(BuildContext context) => Center(
        child: Text('Pas assez de données', style: TextStyle(color: colors.textMuted)),
      );
}
