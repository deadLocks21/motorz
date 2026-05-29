import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/tire_pressure_entry.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/utils/format.dart';

double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

Future<void> showAddTireSheet(
  BuildContext context,
  WidgetRef ref, {
  required String vehicleId,
  required int wheelCount,
  int? lastOdometer,
  TirePressureEntry? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddTireSheet(
      vehicleId: vehicleId,
      wheelCount: wheelCount,
      lastOdometer: lastOdometer,
      existing: existing,
    ),
  );
}

class _AddTireSheet extends ConsumerStatefulWidget {
  const _AddTireSheet({
    required this.vehicleId,
    required this.wheelCount,
    this.lastOdometer,
    this.existing,
  });
  final String vehicleId;
  final int wheelCount;
  final int? lastOdometer;

  /// Relevé à modifier (mode édition). Null → nouveau relevé.
  final TirePressureEntry? existing;

  @override
  ConsumerState<_AddTireSheet> createState() => _AddTireSheetState();
}

class _AddTireSheetState extends ConsumerState<_AddTireSheet> {
  late final TextEditingController _odo;
  late final List<String> _positions;
  late final Map<String, TextEditingController> _fields;
  String? _targetId;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _odo = TextEditingController(
        text: ex?.odometer.toString() ?? widget.lastOdometer?.toString() ?? '');
    _positions = widget.wheelCount == 2 ? ['AV', 'AR'] : ['AVG', 'AVD', 'ARG', 'ARD'];
    _fields = {
      for (final p in _positions)
        p: TextEditingController(text: ex?.pressures[p]?.toString() ?? ''),
    };
    _targetId = ex?.targetPressureId?.value;
    _date = ex?.date.toLocal() ?? DateTime.now();
  }

  @override
  void dispose() {
    _odo.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final odo = int.tryParse(_odo.text.trim());
    final pressures = <String, double>{};
    for (final p in _positions) {
      final v = _num(_fields[p]!.text);
      if (v != null) pressures[p] = v;
    }
    if (odo == null || pressures.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Km et au moins une pression requis.')));
      return;
    }
    setState(() => _saving = true);
    final ex = widget.existing;
    final entry = TirePressureEntry(
      id: ex?.id ?? UuidValue.generate(),
      vehicleId: ex?.vehicleId ?? UuidValue.parse(widget.vehicleId),
      date: _date.toUtc(),
      odometer: odo,
      pressures: pressures,
      targetPressureId: _targetId != null ? UuidValue.parse(_targetId!) : null,
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(tirePressureRepositoryProvider).save(entry);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ex = widget.existing;
    if (ex == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce relevé ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(tirePressureRepositoryProvider).delete(ex);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final targets = ref.watch(targetPressuresProvider(widget.vehicleId)).value ?? const [];
    // La cible mémorisée a pu être supprimée : on ne la pré-sélectionne que si
    // elle existe encore.
    final selectableId =
        targets.any((t) => t.id.value == _targetId) ? _targetId : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existing != null ? 'Modifier le relevé' : 'Relevé de pression',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _odo,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Kilométrage', suffixText: 'km'),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date'),
              child: Text(formatDate(_date)),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _positions
                .map((p) => SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _fields[p],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: p, suffixText: 'bar'),
                      ),
                    ))
                .toList(),
          ),
          if (targets.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: selectableId,
              decoration: const InputDecoration(
                labelText: 'Gonflé à',
                helperText: 'La pression à laquelle tu viens de remplir (= un remplissage).',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('— (simple relevé)')),
                ...targets.map((t) => DropdownMenuItem(
                      value: t.id.value,
                      child: Text('${t.label} · AV ${formatBar(t.front)} · AR ${formatBar(t.rear)}'),
                    )),
              ],
              onChanged: (v) => setState(() => _targetId = v),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Enregistrer')),
          if (widget.existing != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Supprimer'),
            ),
          ],
        ],
      ),
    );
  }
}
