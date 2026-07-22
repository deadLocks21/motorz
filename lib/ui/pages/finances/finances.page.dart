import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/application/services/finance.service.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/ui/pages/finances/widgets/add_cost_sheet.widget.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';
import 'package:motorz/ui/utils/format.dart';
import 'package:motorz/ui/widgets/section_header.widget.dart';

/// Écran Finances : TCO, mon achat, postes de coût, historique de possession.
class FinancesPage extends ConsumerWidget {
  const FinancesPage({super.key, required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final tco = ref.watch(financeSummaryProvider(vehicleId)).value;
    final costs = ref.watch(costEntriesProvider(vehicleId)).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Finances')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (tco != null) _TcoCard(tco: tco, colors: colors),
          const SizedBox(height: 24),
          SectionHeader('Assurance & autres frais',
              onAdd: () => showAddCostSheet(context, ref, vehicleId: vehicleId)),
          if (costs.isEmpty)
            Text('Aucun frais. Ajoute l\'assurance ou un poste libre.',
                style: TextStyle(color: colors.textMuted))
          else
            ...costs.map((c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    c.category == 'assurance' ? Icons.shield_outlined : Icons.receipt_long_outlined,
                    color: colors.textMuted,
                  ),
                  title: Text(c.label),
                  subtitle: Text(formatDate(c.date)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatEur(c.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: colors.textMuted),
                        onPressed: () => ref.read(costEntryRepositoryProvider).delete(c),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

}

class _TcoCard extends StatelessWidget {
  const _TcoCard({required this.tco, required this.colors});
  final TcoSummary tco;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Coût total de possession', style: TextStyle(color: colors.textMuted, fontSize: 13)),
          const SizedBox(height: 4),
          Text(formatEur(tco.tco),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _line('Achat', formatEur(tco.purchasePrice)),
          _line('Carburant', formatEur(tco.fuelCost)),
          _line('Entretien', formatEur(tco.maintenanceCost)),
          _line('Assurance & autres', formatEur(tco.otherCost)),
          const Divider(),
          if (tco.costPerKm != null) _line('Coût au km', formatEur(tco.costPerKm)),
          if (tco.monthlyCost != null) _line('Coût mensuel', formatEur(tco.monthlyCost)),
          if (tco.kmSinceAcquisition != null) _line('Km depuis l\'achat', formatKm(tco.kmSinceAcquisition)),
          // Sans devis, l'estimatif ne ferait que répéter le coût d'entretien.
          if (tco.quotedOperationCount > 0) ...[
            const Divider(),
            _line('Estimatif tout-en-garage', formatEur(tco.garageEstimate)),
            _line('Économisé en le faisant moi-même', formatEur(tco.diySavings),
                highlight: tco.diySavings > 0),
          ],
        ],
      ),
    );
  }

  Widget _line(String k, String v, {bool highlight = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: TextStyle(color: colors.textMuted)),
        Text(v,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: highlight ? colors.statusOk : colors.textPrimary,
            )),
      ],
    ),
  );
}
