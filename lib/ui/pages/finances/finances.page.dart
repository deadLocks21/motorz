import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/application/services/finance.service.dart';
import 'package:motorz/core/domain/model/cost_entry.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/ui/pages/finances/widgets/add_cost_sheet.widget.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';
import 'package:motorz/ui/utils/format.dart';
import 'package:motorz/ui/widgets/section_header.widget.dart';

/// Écran Finances : coût d'usage, coût total de possession, frais récurrents et
/// ponctuels.
class FinancesPage extends ConsumerWidget {
  const FinancesPage({super.key, required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final tco = ref.watch(financeSummaryProvider(vehicleId)).value;
    final costs = ref.watch(costEntriesProvider(vehicleId)).value ?? const [];
    final recurring = costs.where((c) => c.recurrence.isRecurring).toList();
    final oneOff = costs.where((c) => !c.recurrence.isRecurring).toList();

    void add() => showAddCostSheet(context, ref, vehicleId: vehicleId);

    return Scaffold(
      appBar: AppBar(title: const Text('Finances')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (tco != null) ...[
            _UsageCard(tco: tco, colors: colors),
            const SizedBox(height: 12),
            _OwnershipCard(tco: tco, colors: colors),
          ],
          const SizedBox(height: 24),
          SectionHeader('Frais récurrents', onAdd: add),
          if (recurring.isEmpty)
            Text(
              'Rien de récurrent. Saisis ton assurance une bonne fois : montant '
              'et périodicité, sans une ligne par échéance.',
              style: TextStyle(color: colors.textMuted),
            )
          else ...[
            ...recurring.map((c) => _CostTile(cost: c, vehicleId: vehicleId, colors: colors)),
            if (tco != null && tco.recurringMonthly > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Charge fixe actuelle : ${formatEur(tco.recurringMonthly)} par mois',
                  style: TextStyle(color: colors.textMuted, fontStyle: FontStyle.italic),
                ),
              ),
          ],
          const SizedBox(height: 24),
          SectionHeader('Frais ponctuels', onAdd: add),
          if (oneOff.isEmpty)
            Text('Aucun frais ponctuel.', style: TextStyle(color: colors.textMuted))
          else
            ...oneOff.map((c) => _CostTile(cost: c, vehicleId: vehicleId, colors: colors)),
        ],
      ),
    );
  }
}

/// Une ligne de frais. Le tap rouvre la feuille en édition — sur une charge
/// perpétuelle, corriger la prime doit être moins coûteux que supprimer/ressaisir.
class _CostTile extends ConsumerWidget {
  const _CostTile({required this.cost, required this.vehicleId, required this.colors});
  final CostEntry cost;
  final String vehicleId;
  final AppColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = cost.recurrence;
    final monthly = cost.monthlyAmount;
    final subtitle = r.isRecurring
        ? [
            'Depuis le ${formatDate(cost.date)}',
            if (cost.endDate != null) 'jusqu\'au ${formatDate(cost.endDate!)}',
            if (monthly != null && r.months > 1) '≈ ${formatEur(monthly)}/mois',
          ].join(' · ')
        : formatDate(cost.date);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      onTap: () => showAddCostSheet(context, ref, vehicleId: vehicleId, existing: cost),
      leading: Icon(
        cost.category == 'assurance' ? Icons.shield_outlined : Icons.receipt_long_outlined,
        color: colors.textMuted,
      ),
      title: Text(cost.label),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Un montant absent s'affiche « — » : lui coller « /an » n'aurait
          // aucun sens.
          Text('${formatEur(cost.amount)}${cost.amount == null ? '' : r.suffix}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            icon: Icon(Icons.delete_outline, color: colors.textMuted),
            onPressed: () => ref.read(costEntryRepositoryProvider).delete(cost),
          ),
        ],
      ),
    );
  }
}

/// Ce que le véhicule coûte à rouler — prix d'achat exclu, pour que le €/mois et
/// le €/km restent lisibles (cf. [TcoSummary]).
class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.tco, required this.colors});
  final TcoSummary tco;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return _Card(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Coût d\'usage', style: TextStyle(color: colors.textMuted, fontSize: 13)),
          const SizedBox(height: 4),
          Text(formatEur(tco.usageCost),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _line('Carburant', formatEur(tco.fuelCost), colors),
          _line('Entretien', formatEur(tco.maintenanceCost), colors),
          _line('Assurance & frais', formatEur(tco.otherCost), colors),
          const Divider(),
          if (tco.monthlyCost != null) _line('Par mois', formatEur(tco.monthlyCost), colors),
          if (tco.costPerKm != null) _line('Par km', formatEur(tco.costPerKm), colors),
          if (tco.kmSinceAcquisition != null)
            _line('Km depuis l\'achat', formatKm(tco.kmSinceAcquisition), colors),
          // Sans devis, l'estimatif ne ferait que répéter le coût d'entretien.
          if (tco.quotedOperationCount > 0) ...[
            const Divider(),
            _line('Estimatif tout-en-garage', formatEur(tco.garageEstimate), colors),
            _line('Économisé en le faisant moi-même', formatEur(tco.diySavings), colors,
                highlight: tco.diySavings > 0),
          ],
        ],
      ),
    );
  }
}

/// Le capital : prix d'achat et coût total de possession, tenus à l'écart des
/// ratios d'usage.
class _OwnershipCard extends StatelessWidget {
  const _OwnershipCard({required this.tco, required this.colors});
  final TcoSummary tco;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return _Card(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Coût total de possession',
              style: TextStyle(color: colors.textMuted, fontSize: 13)),
          const SizedBox(height: 4),
          Text(formatEur(tco.tco), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _line('Prix d\'achat', formatEur(tco.purchasePrice), colors),
          _line('Coût d\'usage', formatEur(tco.usageCost), colors),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, required this.colors});
  final Widget child;
  final AppColors colors;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: colors.outline),
    ),
    child: child,
  );
}

Widget _line(String k, String v, AppColors colors, {bool highlight = false}) => Padding(
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
