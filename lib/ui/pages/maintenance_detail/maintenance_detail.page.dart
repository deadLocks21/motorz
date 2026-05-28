import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/application/services/maintenance_derivation.service.dart';
import 'package:motorz/core/domain/model/maintenance_operation.dart';
import 'package:motorz/core/domain/model/maintenance_quote.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/ui/pages/maintenance_detail/widgets/add_quote_sheet.widget.dart';
import 'package:motorz/ui/pages/vehicle_detail/widgets/add_operation_sheet.widget.dart';
import 'package:motorz/ui/pages/vehicle_detail/widgets/documents_tab.widget.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';
import 'package:motorz/ui/utils/format.dart';

/// Détail d'une opération d'entretien : lignes (postes faits), coût total,
/// documents (factures) et devis comparatifs (§5.5).
class MaintenanceOperationDetailPage extends ConsumerStatefulWidget {
  const MaintenanceOperationDetailPage({super.key, required this.operation});
  final Operation operation;

  @override
  ConsumerState<MaintenanceOperationDetailPage> createState() =>
      _MaintenanceOperationDetailPageState();
}

class _MaintenanceOperationDetailPageState
    extends ConsumerState<MaintenanceOperationDetailPage> {
  late Operation _operation;

  @override
  void initState() {
    super.initState();
    _operation = widget.operation;
  }

  Future<void> _toggleCount(bool value) async {
    setState(() =>
        _operation = _operation.copyWith(countQuoteInEstimate: value, updatedAt: DateTime.now().toUtc()));
    await ref.read(operationRepositoryProvider).save(_operation);
  }

  Future<void> _retain(List<MaintenanceQuote> quotes, MaintenanceQuote target) async {
    final repo = ref.read(maintenanceQuoteRepositoryProvider);
    for (final q in quotes) {
      final shouldSelect = q.id == target.id;
      if (q.isSelected != shouldSelect) {
        await repo.save(q.copyWith(isSelected: shouldSelect, updatedAt: DateTime.now().toUtc()));
      }
    }
  }

  Future<void> _edit() async {
    final lines = await ref.read(operationLinesProvider(_operation.id.value).future);
    if (!mounted) return;
    await showAddOperationSheet(
      context,
      ref,
      vehicleId: _operation.vehicleId.value,
      existing: _operation,
      existingLines: lines,
    );
    final updated = await ref.read(operationRepositoryProvider).getById(_operation.id.value);
    if (mounted && updated != null) setState(() => _operation = updated);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final lines = ref.watch(operationLinesProvider(_operation.id.value)).value ?? const [];
    final quotes = ref.watch(quotesForOperationProvider(_operation.id.value)).value ?? const [];
    final total = MaintenanceDerivationService.operationCost(lines);
    final title = _operation.title ?? MaintenanceDerivationService.deriveTitle(lines);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier',
            onPressed: _edit,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${formatDate(_operation.date)} · ${formatKm(_operation.odometer)}',
                      style: TextStyle(color: colors.textMuted)),
                  if (_operation.provider != null) Text('Prestataire : ${_operation.provider}'),
                  if (_operation.note != null) ...[
                    const SizedBox(height: 8),
                    Text(_operation.note!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Postes', style: Theme.of(context).textTheme.titleMedium),
          if (lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Aucun poste.', style: TextStyle(color: colors.textMuted)),
            )
          else
            ...lines.map((l) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(Icons.build_outlined, color: colors.textMuted),
                  title: Text(l.label),
                  trailing: Text(formatEur(l.cost)),
                )),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Coût réel', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(formatEur(total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          Text('Documents', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          MediaGrid(ownerType: 'maintenance_operation', ownerId: _operation.id.value),
          const SizedBox(height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Compter le devis retenu dans l\'estimatif'),
            subtitle: const Text('Alimente l\'estimatif « tout en garage » et les économies DIY.'),
            value: _operation.countQuoteInEstimate,
            onChanged: _toggleCount,
          ),
          const Divider(),
          Row(
            children: [
              Expanded(child: Text('Devis comparatifs', style: Theme.of(context).textTheme.titleMedium)),
              TextButton.icon(
                onPressed: () => showAddQuoteSheet(context, ref, operationId: _operation.id.value),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Devis'),
              ),
            ],
          ),
          if (quotes.isEmpty)
            Text('Aucun devis. Ajoute le tarif d\'un garage pour comparer.',
                style: TextStyle(color: colors.textMuted))
          else
            ...quotes.map((q) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(q.source ?? 'Devis'),
                  subtitle: Text(formatEur(q.amount)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (q.isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.accentSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Retenu',
                              style: TextStyle(
                                  color: colors.onAccentSoft, fontWeight: FontWeight.w700, fontSize: 12)),
                        )
                      else
                        TextButton(onPressed: () => _retain(quotes, q), child: const Text('Retenir')),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: colors.textMuted),
                        onPressed: () => ref.read(maintenanceQuoteRepositoryProvider).delete(q),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
