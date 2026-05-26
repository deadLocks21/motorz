import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/cost_entry.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';

double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

Future<void> showAddCostSheet(BuildContext context, WidgetRef ref, {required String vehicleId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddCostSheet(vehicleId: vehicleId),
  );
}

class _AddCostSheet extends ConsumerStatefulWidget {
  const _AddCostSheet({required this.vehicleId});
  final String vehicleId;

  @override
  ConsumerState<_AddCostSheet> createState() => _AddCostSheetState();
}

class _AddCostSheetState extends ConsumerState<_AddCostSheet> {
  final _label = TextEditingController();
  final _amount = TextEditingController();
  String _category = 'assurance';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nomme la dépense.')));
      return;
    }
    setState(() => _saving = true);
    final cost = CostEntry(
      id: UuidValue.generate(),
      vehicleId: UuidValue.parse(widget.vehicleId),
      label: label,
      category: _category,
      amount: _num(_amount.text),
      date: _date.toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(costEntryRepositoryProvider).save(cost);
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
          Text('Dépense', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Poste'),
            items: const [
              DropdownMenuItem(value: 'assurance', child: Text('Assurance')),
              DropdownMenuItem(value: 'autre', child: Text('Autre')),
            ],
            onChanged: (v) => setState(() => _category = v ?? 'autre'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _label,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Libellé', hintText: 'Prime annuelle 2026'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Montant', suffixText: '€'),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date'),
              child: Text('${_date.day}/${_date.month}/${_date.year}'),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Enregistrer')),
        ],
      ),
    );
  }
}
