import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/maintenance_event.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';

double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

Future<void> showAddMaintenanceSheet(
  BuildContext context,
  WidgetRef ref, {
  required String vehicleId,
  int? lastOdometer,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddMaintenanceSheet(vehicleId: vehicleId, lastOdometer: lastOdometer),
  );
}

class _AddMaintenanceSheet extends ConsumerStatefulWidget {
  const _AddMaintenanceSheet({required this.vehicleId, this.lastOdometer});
  final String vehicleId;
  final int? lastOdometer;

  @override
  ConsumerState<_AddMaintenanceSheet> createState() => _AddMaintenanceSheetState();
}

class _AddMaintenanceSheetState extends ConsumerState<_AddMaintenanceSheet> {
  late final TextEditingController _odo;
  final _title = TextEditingController();
  final _category = TextEditingController();
  final _total = TextEditingController();
  final _provider = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _odo = TextEditingController(text: widget.lastOdometer?.toString() ?? '');
  }

  @override
  void dispose() {
    for (final c in [_odo, _title, _category, _total, _provider]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final odo = int.tryParse(_odo.text.trim());
    final title = _title.text.trim();
    if (odo == null || title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Titre et kilométrage requis.')));
      return;
    }
    setState(() => _saving = true);
    final event = MaintenanceEvent(
      id: UuidValue.generate(),
      vehicleId: UuidValue.parse(widget.vehicleId),
      date: DateTime.now().toUtc(),
      odometer: odo,
      title: title,
      category: _category.text.trim().isEmpty ? null : _category.text.trim(),
      totalCost: _num(_total.text),
      provider: _provider.text.trim().isEmpty ? null : _provider.text.trim(),
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(maintenanceEventRepositoryProvider).save(event);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Entretien réalisé', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Titre', hintText: 'Vidange + filtres'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _odo,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Km', suffixText: 'km'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _total,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Coût total', suffixText: '€'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _category,
            decoration: const InputDecoration(labelText: 'Catégorie', hintText: 'Vidange, freins…'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _provider,
            decoration: const InputDecoration(labelText: 'Prestataire', hintText: 'Garage / moi-même'),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Enregistrer')),
        ],
      ),
    );
  }
}
