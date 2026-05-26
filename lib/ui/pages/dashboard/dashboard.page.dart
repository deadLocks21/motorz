import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/vehicle.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';
import 'package:motorz/ui/utils/format.dart';

/// Tableau de bord multi-véhicules : comparaison coûts & consos (§5.9).
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final vehiclesAsync = ref.watch(vehiclesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord')),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return Center(child: Text('Aucun véhicule.', style: TextStyle(color: colors.textMuted)));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Coût total de possession et consommation par véhicule.',
                  style: TextStyle(color: colors.textMuted)),
              const SizedBox(height: 12),
              ...vehicles.map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DashboardRow(vehicle: v, colors: colors),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardRow extends ConsumerWidget {
  const _DashboardRow({required this.vehicle, required this.colors});
  final Vehicle vehicle;
  final AppColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = vehicle.id.value;
    final tco = ref.watch(financeSummaryProvider(id)).value;
    final conso = ref.watch(averageConsumptionProvider(id)).value;

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
          Text(vehicle.nickname, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              _metric('TCO', formatEur(tco?.tco), colors),
              _metric('Coût/km', formatEur(tco?.costPerKm), colors),
              _metric('Conso', formatConsumption(conso), colors),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, AppColors colors) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: colors.textMuted, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
