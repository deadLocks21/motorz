import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/application/services/maintenance_derivation.service.dart';
import 'package:motorz/core/domain/model/maintenance_operation.dart';
import 'package:motorz/core/domain/model/maintenance_quote.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/ui/pages/maintenance_detail/widgets/quote_sheet.widget.dart';
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

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cet entretien ?'),
        content: const Text('L\'opération et ses postes seront supprimés. Cette action est définitive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    final lines = await ref.read(operationLinesProvider(_operation.id.value).future);
    for (final l in lines) {
      await ref.read(operationLineRepositoryProvider).delete(l);
    }
    await ref.read(operationRepositoryProvider).delete(_operation);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final lines = ref.watch(operationLinesProvider(_operation.id.value)).value ?? const [];
    final quotes = MaintenanceQuote.ordered(
        ref.watch(quotesForOperationProvider(_operation.id.value)).value ?? const []);
    final retained = MaintenanceQuote.retainedIn(quotes);
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
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Supprimer',
            onPressed: _delete,
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
                  if (_operation.isDiy)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.handyman_outlined, size: 16, color: colors.textMuted),
                        const SizedBox(width: 6),
                        const Text('Fait par moi-même'),
                      ],
                    )
                  else if (_operation.provider != null)
                    Text('Prestataire : ${_operation.provider}'),
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
          const Divider(),
          Row(
            children: [
              Expanded(
                  child: Text('Devis garage', style: Theme.of(context).textTheme.titleMedium)),
              TextButton.icon(
                key: const Key('addQuoteButton'),
                onPressed: () => showQuoteSheet(context, ref, operationId: _operation.id.value),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Devis'),
              ),
            ],
          ),
          if (quotes.isEmpty)
            Text(
              _operation.isDiy
                  ? 'Aucun devis. Ajoute ce qu\'un garage t\'aurait pris pour mesurer ce que tu économises.'
                  : 'Aucun devis. Ajoute le chiffrage d\'un garage pour le comparer.',
              style: TextStyle(color: colors.textMuted),
            )
          else ...[
            if (quotes.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('Le devis coché fait référence pour l\'estimatif.',
                    style: TextStyle(color: colors.textMuted, fontSize: 12)),
              ),
            RadioGroup<String>(
              groupValue: retained?.id.value,
              onChanged: (id) {
                if (id == null) return;
                _retain(quotes, quotes.firstWhere((q) => q.id.value == id));
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final q in quotes) _quoteTile(q, quotes, retained, total, colors),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Ligne de devis. Le sélecteur n'apparaît qu'à partir de **deux** devis :
  /// avec un seul, la question « lequel compte ? » ne se pose pas.
  Widget _quoteTile(
    MaintenanceQuote quote,
    List<MaintenanceQuote> quotes,
    MaintenanceQuote? retained,
    double? realCost,
    AppColors colors,
  ) {
    final isRetained = quote.id == retained?.id;
    final effect = isRetained ? _quoteEffect(quote, realCost) : null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: quotes.length > 1 ? Radio<String>(value: quote.id.value) : null,
      title: Text(quote.provider ?? 'Devis'),
      subtitle: effect == null ? null : Text(effect, style: TextStyle(color: colors.textMuted)),
      trailing: Text(formatEur(quote.amount),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isRetained ? colors.textPrimary : colors.textMuted,
          )),
      onTap: () => showQuoteSheet(context, ref, operationId: _operation.id.value, existing: quote),
    );
  }

  /// Ce que le devis de référence change concrètement — la réponse à « à quoi
  /// ça sert ? » qu'on ne lisait nulle part avant.
  String? _quoteEffect(MaintenanceQuote quote, double? realCost) {
    final amount = quote.amount;
    if (amount == null) return null;
    // Hors DIY (ou sans coût réel à comparer), le devis ne dit rien d'une
    // économie : il ne fait que remplacer le coût réel dans l'estimatif.
    if (!_operation.isDiy || realCost == null) return 'Compté dans l\'estimatif tout-en-garage';
    final saved = amount - realCost;
    if (saved > 0) return 'Économie de ${formatEur(saved)} en le faisant moi-même';
    if (saved < 0) return '${formatEur(-saved)} de plus qu\'en le confiant au garage';
    return 'Autant qu\'en le confiant au garage';
  }
}
