import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/fuel_entry.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/ui/utils/format.dart';

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

  /// Pré-remplit la station « comme la dernière fois » (§5.8) ; le volume et le
  /// prix changent à chaque plein, on les laisse à saisir.
  final FuelEntry? duplicateOf;

  @override
  ConsumerState<_AddFuelSheet> createState() => _AddFuelSheetState();
}

class _AddFuelSheetState extends ConsumerState<_AddFuelSheet> {
  late final TextEditingController _odo;
  final _volume = TextEditingController();
  final _price = TextEditingController();
  final _station = TextEditingController();

  /// Date du plein — par défaut aujourd'hui, modifiable (saisie a posteriori).
  DateTime _date = DateTime.now();

  /// Total calculé (volume × prix/L), affiché en lecture seule — jamais saisi.
  double? _total;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _odo = TextEditingController(text: widget.lastOdometer?.toString() ?? '');
    // On garde uniquement la station de la dernière fois ; volume et prix se
    // tapent à chaque plein.
    if (widget.duplicateOf?.station != null) _station.text = widget.duplicateOf!.station!;
    _volume.addListener(_recompute);
    _price.addListener(_recompute);
  }

  void _recompute() {
    final v = _num(_volume.text);
    final p = _num(_price.text);
    setState(() => _total = (v != null && p != null) ? v * p : null);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  void dispose() {
    for (final c in [_odo, _volume, _price, _station]) {
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
    final volume = _num(_volume.text);
    final price = _num(_price.text);
    // Midi local pour éviter qu'un décalage de fuseau ne change le jour saisi.
    final date = DateTime(_date.year, _date.month, _date.day, 12);
    final entry = FuelEntry(
      id: UuidValue.generate(),
      vehicleId: UuidValue.parse(widget.vehicleId),
      date: date.toUtc(),
      odometer: odo,
      volumeLiters: volume,
      pricePerLiter: price,
      totalCost: (volume != null && price != null) ? volume * price : null,
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
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Date'),
            child: InkWell(
              key: const Key('fuelDateField'),
              onTap: _pickDate,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatDate(_date)),
                  const Icon(Icons.calendar_today_outlined, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Total : ${formatEur(_total)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
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
