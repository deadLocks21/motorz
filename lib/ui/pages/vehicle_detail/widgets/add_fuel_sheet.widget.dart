import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/fuel_entry.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';

double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

/// Feuille modale de saisie rapide d'un plein (chemin critique §6.2).
Future<void> showAddFuelSheet(
  BuildContext context,
  WidgetRef ref, {
  required String vehicleId,
  int? lastOdometer,
  FuelType? defaultFuelType,
  FuelEntry? duplicateOf,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddFuelSheet(
      vehicleId: vehicleId,
      lastOdometer: lastOdometer,
      defaultFuelType: defaultFuelType,
      duplicateOf: duplicateOf,
    ),
  );
}

class _AddFuelSheet extends ConsumerStatefulWidget {
  const _AddFuelSheet({
    required this.vehicleId,
    this.lastOdometer,
    this.defaultFuelType,
    this.duplicateOf,
  });

  final String vehicleId;
  final int? lastOdometer;
  final FuelType? defaultFuelType;

  /// Pré-remplit volume/prix/station « comme la dernière fois » (§5.8).
  final FuelEntry? duplicateOf;

  @override
  ConsumerState<_AddFuelSheet> createState() => _AddFuelSheetState();
}

class _AddFuelSheetState extends ConsumerState<_AddFuelSheet> {
  late final TextEditingController _odo;
  final _volume = TextEditingController();
  final _price = TextEditingController();
  final _total = TextEditingController();
  final _station = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _odo = TextEditingController(text: widget.lastOdometer?.toString() ?? '');
    final dup = widget.duplicateOf;
    if (dup != null) {
      if (dup.volumeLiters != null) _volume.text = dup.volumeLiters!.toStringAsFixed(2);
      if (dup.pricePerLiter != null) _price.text = dup.pricePerLiter!.toStringAsFixed(3);
      if (dup.station != null) _station.text = dup.station!;
    }
    _volume.addListener(_recompute);
    _price.addListener(_recompute);
  }

  // Deux des trois (volume / prix au litre / total) suffisent.
  void _recompute() {
    final v = _num(_volume.text);
    final p = _num(_price.text);
    if (v != null && p != null) {
      final t = (v * p);
      _total.text = t.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    for (final c in [_odo, _volume, _price, _total, _station]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final odo = int.tryParse(_odo.text.trim());
    if (odo == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Indique le kilométrage.')));
      return;
    }
    setState(() => _saving = true);
    final entry = FuelEntry(
      id: UuidValue.generate(),
      vehicleId: UuidValue.parse(widget.vehicleId),
      date: DateTime.now().toUtc(),
      odometer: odo,
      volumeLiters: _num(_volume.text),
      pricePerLiter: _num(_price.text),
      totalCost: _num(_total.text),
      fuelType: widget.defaultFuelType,
      station: _station.text.trim().isEmpty ? null : _station.text.trim(),
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(fuelRepositoryProvider).save(entry);
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
          Text('Nouveau plein', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            key: const Key('fuelOdometerField'),
            controller: _odo,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Kilométrage', suffixText: 'km'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('fuelVolumeField'),
                  controller: _volume,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Volume', suffixText: 'L'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Prix/L', suffixText: '€'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _total,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Total', suffixText: '€'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _station,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Station (optionnel)'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('saveFuelButton'),
            onPressed: _saving ? null : _save,
            child: const Text('Enregistrer le plein'),
          ),
        ],
      ),
    );
  }
}
