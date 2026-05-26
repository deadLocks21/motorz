import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/maintenance_event.dart';
import 'package:motorz/core/domain/model/maintenance_quote.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/ui/pages/maintenance_detail/widgets/add_quote_sheet.widget.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';
import 'package:motorz/ui/utils/format.dart';

/// Détail d'une opération d'entretien + devis comparatifs (§5.5).
class MaintenanceEventDetailPage extends ConsumerStatefulWidget {
  const MaintenanceEventDetailPage({super.key, required this.event});
  final MaintenanceEvent event;

  @override
  ConsumerState<MaintenanceEventDetailPage> createState() => _MaintenanceEventDetailPageState();
}

class _MaintenanceEventDetailPageState extends ConsumerState<MaintenanceEventDetailPage> {
  late MaintenanceEvent _event;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
  }

  Future<void> _toggleCount(bool value) async {
    setState(() => _event = _event.copyWith(countQuoteInEstimate: value, updatedAt: DateTime.now().toUtc()));
    await ref.read(maintenanceEventRepositoryProvider).save(_event);
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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final quotes = ref.watch(quotesForEventProvider(_event.id.value)).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(_event.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${formatDate(_event.date)} · ${formatKm(_event.odometer)}',
                      style: TextStyle(color: colors.textMuted)),
                  if (_event.category != null) ...[
                    const SizedBox(height: 4),
                    Text('Catégorie : ${_event.category}'),
                  ],
                  if (_event.provider != null) Text('Prestataire : ${_event.provider}'),
                  if (_event.description != null) ...[
                    const SizedBox(height: 8),
                    Text(_event.description!),
                  ],
                  const SizedBox(height: 8),
                  Text('Coût réel : ${formatEur(_event.effectiveCost)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Compter le devis retenu dans l\'estimatif'),
            subtitle: const Text('Alimente l\'estimatif « tout en garage » et les économies DIY.'),
            value: _event.countQuoteInEstimate,
            onChanged: _toggleCount,
          ),
          const Divider(),
          Row(
            children: [
              Expanded(child: Text('Devis comparatifs', style: Theme.of(context).textTheme.titleMedium)),
              TextButton.icon(
                onPressed: () => showAddQuoteSheet(context, ref, eventId: _event.id.value),
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
                              style: TextStyle(color: colors.onAccentSoft, fontWeight: FontWeight.w700, fontSize: 12)),
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
