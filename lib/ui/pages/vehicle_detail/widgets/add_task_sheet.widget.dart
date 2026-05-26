import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/maintenance_task.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';

Future<void> showAddTaskSheet(
  BuildContext context,
  WidgetRef ref, {
  required String vehicleId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddTaskSheet(vehicleId: vehicleId),
  );
}

class _AddTaskSheet extends ConsumerStatefulWidget {
  const _AddTaskSheet({required this.vehicleId});
  final String vehicleId;

  @override
  ConsumerState<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<_AddTaskSheet> {
  final _title = TextEditingController();
  final _intervalKm = TextEditingController();
  final _intervalMonths = TextEditingController();
  final _dueOdometer = TextEditingController();
  TaskKind _kind = TaskKind.periodic;
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _intervalKm, _intervalMonths, _dueOdometer]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Donne un titre à l\'échéance.')));
      return;
    }
    setState(() => _saving = true);
    final task = MaintenanceTask(
      id: UuidValue.generate(),
      vehicleId: UuidValue.parse(widget.vehicleId),
      title: title,
      kind: _kind,
      intervalKm: _kind == TaskKind.periodic ? int.tryParse(_intervalKm.text) : null,
      intervalMonths: _kind == TaskKind.periodic ? int.tryParse(_intervalMonths.text) : null,
      dueOdometer: int.tryParse(_dueOdometer.text),
      dueDate: _dueDate?.toIso8601String().substring(0, 10),
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(maintenanceTaskRepositoryProvider).save(task);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final periodic = _kind == TaskKind.periodic;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('À prévoir', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Titre', hintText: 'Vidange'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TaskKind>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Type'),
            items: TaskKind.values
                .map((k) => DropdownMenuItem(value: k, child: Text(k.label)))
                .toList(),
            onChanged: (k) => setState(() => _kind = k ?? TaskKind.periodic),
          ),
          const SizedBox(height: 12),
          if (periodic)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _intervalKm,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Tous les', suffixText: 'km'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _intervalMonths,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'ou tous les', suffixText: 'mois'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dueOdometer,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Avant', suffixText: 'km'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: now,
                        firstDate: now.subtract(const Duration(days: 365)),
                        lastDate: now.add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null) setState(() => _dueDate = picked);
                    },
                    child: Text(_dueDate == null
                        ? 'Avant le…'
                        : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Ajouter')),
        ],
      ),
    );
  }
}
