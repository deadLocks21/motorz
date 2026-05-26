import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/tire_pressure_entry.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';

double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

Future<void> showAddTireSheet(
  BuildContext context,
  WidgetRef ref, {
  required String vehicleId,
  required int wheelCount,
  int? lastOdometer,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddTireSheet(
      vehicleId: vehicleId,
      wheelCount: wheelCount,
      lastOdometer: lastOdometer,
    ),
  );
}

class _AddTireSheet extends ConsumerStatefulWidget {
  const _AddTireSheet({required this.vehicleId, required this.wheelCount, this.lastOdometer});
  final String vehicleId;
  final int wheelCount;
  final int? lastOdometer;

  @override
  ConsumerState<_AddTireSheet> createState() => _AddTireSheetState();
}

class _AddTireSheetState extends ConsumerState<_AddTireSheet> {
  late final TextEditingController _odo;
  late final List<String> _positions;
  late final Map<String, TextEditingController> _fields;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _odo = TextEditingController(text: widget.lastOdometer?.toString() ?? '');
    _positions = widget.wheelCount == 2 ? ['AV', 'AR'] : ['AVG', 'AVD', 'ARG', 'ARD'];
    _fields = {for (final p in _positions) p: TextEditingController()};
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
    final entry = TirePressureEntry(
      id: UuidValue.generate(),
      vehicleId: UuidValue.parse(widget.vehicleId),
      date: DateTime.now().toUtc(),
      odometer: odo,
      pressures: pressures,
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(tirePressureRepositoryProvider).save(entry);
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
          Text('Relevé de pression', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _odo,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Kilométrage', suffixText: 'km'),
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
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Enregistrer')),
        ],
      ),
    );
  }
}
