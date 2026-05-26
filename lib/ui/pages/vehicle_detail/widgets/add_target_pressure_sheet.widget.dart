import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/target_pressure.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';

double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

Future<void> showAddTargetPressureSheet(
  BuildContext context,
  WidgetRef ref, {
  required String vehicleId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddTargetPressureSheet(vehicleId: vehicleId),
  );
}

class _AddTargetPressureSheet extends ConsumerStatefulWidget {
  const _AddTargetPressureSheet({required this.vehicleId});
  final String vehicleId;

  @override
  ConsumerState<_AddTargetPressureSheet> createState() => _AddTargetPressureSheetState();
}

class _AddTargetPressureSheetState extends ConsumerState<_AddTargetPressureSheet> {
  final _label = TextEditingController();
  final _front = TextEditingController();
  final _rear = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_label, _front, _rear]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nomme la cible (ex. « à vide »).')));
      return;
    }
    setState(() => _saving = true);
    final target = TargetPressure(
      id: UuidValue.generate(),
      vehicleId: UuidValue.parse(widget.vehicleId),
      label: label,
      front: _num(_front.text),
      rear: _num(_rear.text),
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(targetPressureRepositoryProvider).save(target);
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
          Text('Pression cible', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _label,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nom', hintText: 'À vide / En charge'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _front,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Avant', suffixText: 'bar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _rear,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Arrière', suffixText: 'bar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Enregistrer la cible')),
        ],
      ),
    );
  }
}
