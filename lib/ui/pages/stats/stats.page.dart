import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/application/services/maintenance_derivation.service.dart';
import 'package:motorz/core/application/services/stats.service.dart';
import 'package:motorz/core/application/services/vehicle_stats.service.dart';
import 'package:motorz/core/domain/model/maintenance_operation_line.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';
import 'package:motorz/ui/utils/format.dart';

/// Statistiques d'un véhicule : conso, prix au litre, dépenses (§5.9).
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key, required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final fuel = ref.watch(fuelEntriesProvider(vehicleId)).value ?? const [];
    final operations = ref.watch(operationsProvider(vehicleId)).value ?? const [];
    final lines = ref.watch(linesForVehicleProvider(vehicleId)).value ?? const <OperationLine>[];
    final costs = ref.watch(costEntriesProvider(vehicleId)).value ?? const [];

    final conso = StatsService.consumptionSeries(fuel);
    final prices = StatsService.pricePerLiterSeries(fuel);

    final linesByOp = <String, List<OperationLine>>{};
    for (final l in lines) {
      (linesByOp[l.operationId.value] ??= []).add(l);
    }
    final totalFuel = fuel.fold<double>(0, (s, e) => s + (e.totalCost ?? 0));
    final totalMaint = operations.fold<double>(
        0, (s, o) => s + (MaintenanceDerivationService.operationCost(linesByOp[o.id.value] ?? const []) ?? 0));
    final totalOther = costs.fold<double>(0, (s, e) => s + (e.amount ?? 0));
    final totalAll = totalFuel + totalMaint + totalOther;

    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LineCard(
            title: 'Consommation',
            unit: 'L/100',
            points: conso,
            average: VehicleStatsService.averageConsumption(fuel),
            color: colors.accent,
            colors: colors,
          ),
          const SizedBox(height: 16),
          _LineCard(
            title: 'Prix au litre',
            unit: '€/L',
            points: prices,
            color: colors.statusOk,
            colors: colors,
          ),
          const SizedBox(height: 16),
          Text('Dépenses', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _SpendBar(label: 'Carburant', value: totalFuel, total: totalAll, color: colors.accent, colors: colors),
          _SpendBar(label: 'Entretien', value: totalMaint, total: totalAll, color: colors.statusSoon, colors: colors),
          _SpendBar(label: 'Assurance & autres', value: totalOther, total: totalAll, color: colors.statusOk, colors: colors),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Total : ${formatEur(totalAll)}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.title,
    required this.unit,
    required this.points,
    required this.color,
    required this.colors,
    this.average,
  });

  final String title;
  final String unit;
  final List<SeriesPoint> points;
  final Color color;
  final AppColors colors;
  final double? average;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (average != null)
                Text('moy. ${average!.toStringAsFixed(1)} $unit',
                    style: TextStyle(color: colors.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: points.length < 2
                ? Center(
                    child: Text('Pas assez de données', style: TextStyle(color: colors.textMuted)))
                : LineChart(_chartData()),
          ),
        ],
      ),
    );
  }

  LineChartData _chartData() {
    final spots = [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].value)];
    final values = points.map((p) => p.value).toList();
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final pad = ((maxV - minV).abs() * 0.15) + 0.1;

    return LineChartData(
      minY: minV - pad,
      maxY: maxV + pad,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (v, _) =>
                Text(v.toStringAsFixed(1), style: TextStyle(color: colors.textMuted, fontSize: 10)),
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
        ),
      ],
    );
  }
}

class _SpendBar extends StatelessWidget {
  const _SpendBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
    required this.colors,
  });

  final String label;
  final double value;
  final double total;
  final Color color;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(formatEur(value), style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: colors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
