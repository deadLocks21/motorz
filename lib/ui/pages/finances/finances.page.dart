import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/application/services/finance.service.dart';
import 'package:motorz/core/domain/model/ownership.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/ui/pages/finances/widgets/add_cost_sheet.widget.dart';
import 'package:motorz/ui/pages/finances/widgets/add_ownership_sheet.widget.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';
import 'package:motorz/ui/utils/format.dart';

/// Écran Finances : TCO, mon achat, postes de coût, historique de possession.
class FinancesPage extends ConsumerWidget {
  const FinancesPage({super.key, required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final tco = ref.watch(financeSummaryProvider(vehicleId)).value;
    final ownerships = ref.watch(ownershipsProvider(vehicleId)).value ?? const [];
    final costs = ref.watch(costEntriesProvider(vehicleId)).value ?? const [];
    final mine = FinanceService.myOwnership(ownerships);
    final past = ownerships.where((o) => !o.isCurrent).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Finances & possession')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (tco != null) _TcoCard(tco: tco, colors: colors),
          const SizedBox(height: 24),
          _header(context, 'Mon achat', onAdd: () => showOwnershipSheet(context, ref, vehicleId: vehicleId, isMine: true, existing: mine)),
          if (mine == null)
            Text('Renseigne ton achat (prix, km, date) pour calculer le TCO.',
                style: TextStyle(color: colors.textMuted))
          else
            Card(
              child: ListTile(
                title: Text(formatEur(mine.purchasePrice)),
                subtitle: Text([
                  if (mine.acquiredOdometer != null) formatKm(mine.acquiredOdometer),
                  if (mine.acquiredDate != null) mine.acquiredDate,
                ].whereType<String>().join(' · ')),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => showOwnershipSheet(context, ref, vehicleId: vehicleId, isMine: true, existing: mine),
              ),
            ),
          const SizedBox(height: 24),
          _header(context, 'Assurance & autres frais',
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
          const SizedBox(height: 24),
          _header(context, 'Historique de possession',
              onAdd: () => showOwnershipSheet(context, ref, vehicleId: vehicleId, isMine: false)),
          if (ownerships.isEmpty)
            Text('Aucune période enregistrée.', style: TextStyle(color: colors.textMuted))
          else
            ...ownerships.map((o) => _OwnershipTile(o: o, colors: colors)),
          if (past.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Ajoute les anciens propriétaires (nom, km, prix) jusqu\'à l\'achat initial.',
                  style: TextStyle(color: colors.textMuted, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String label, {required VoidCallback onAdd}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
        TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 18), label: const Text('Ajouter')),
      ],
    ),
  );
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
          if (tco.garageEstimate > 0) ...[
            const Divider(),
            _line('Estimatif tout-en-garage', formatEur(tco.garageEstimate)),
            _line('Économies DIY', formatEur(tco.diySavings), highlight: tco.diySavings > 0),
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

class _OwnershipTile extends StatelessWidget {
  const _OwnershipTile({required this.o, required this.colors});
  final Ownership o;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final who = o.isCurrent
        ? 'Moi'
        : [o.firstName, o.lastName].whereType<String>().join(' ').trim().isEmpty
            ? 'Ancien propriétaire'
            : '${o.firstName ?? ''} ${o.lastName ?? ''}'.trim();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(o.isCurrent ? Icons.person : Icons.person_outline, color: colors.textMuted),
      title: Text(who, style: TextStyle(fontWeight: o.isCurrent ? FontWeight.w700 : FontWeight.w400)),
      subtitle: Text([
        if (o.acquiredOdometer != null) formatKm(o.acquiredOdometer),
        if (o.purchasePrice != null) formatEur(o.purchasePrice),
        if (o.acquiredDate != null) o.acquiredDate,
      ].whereType<String>().join(' · ')),
    );
  }
}
