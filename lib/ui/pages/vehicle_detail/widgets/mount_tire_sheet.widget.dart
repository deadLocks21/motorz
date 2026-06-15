import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/application/services/tire.service.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/tire.dart';
import 'package:motorz/core/domain/model/tire_mount.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';
import 'package:motorz/ui/utils/format.dart';

/// Feuille de montage/démontage d'un pneu à une [position]. On y choisit un pneu
/// (du stock ou monté ailleurs → rotation) et l'odomètre du changement ; la
/// transition (fermeture des intervalles ouverts concernés + ouverture du
/// nouveau) est calculée par [TireService.planMount]. Permet aussi de démonter
/// le pneu présent (→ stock).
Future<void> showMountTireSheet(
  BuildContext context,
  WidgetRef ref, {
  required String vehicleId,
  required String position,
  int? lastOdometer,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _MountTireSheet(vehicleId: vehicleId, position: position, lastOdometer: lastOdometer),
  );
}

class _MountTireSheet extends ConsumerStatefulWidget {
  const _MountTireSheet({required this.vehicleId, required this.position, this.lastOdometer});
  final String vehicleId;
  final String position;
  final int? lastOdometer;

  @override
  ConsumerState<_MountTireSheet> createState() => _MountTireSheetState();
}

class _MountTireSheetState extends ConsumerState<_MountTireSheet> {
  late final TextEditingController _odo;
  DateTime _date = DateTime.now();
  String? _selectedTireId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _odo = TextEditingController(text: widget.lastOdometer?.toString() ?? '');
  }

  @override
  void dispose() {
    _odo.dispose();
    super.dispose();
  }

  String get _ymd => _date.toIso8601String().substring(0, 10);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    if (picked != null) setState(() => _date = picked);
  }

  int? _readOdo() {
    final odo = int.tryParse(_odo.text.trim());
    if (odo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Indique le kilométrage du changement.')));
    }
    return odo;
  }

  Future<void> _applyWrites(List<TireMount> writes) async {
    setState(() => _saving = true);
    final repo = ref.read(tireMountRepositoryProvider);
    for (final w in writes) {
      await repo.save(w);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _mount(String tireId) async {
    final odo = _readOdo();
    if (odo == null) return;
    final mounts = await ref.read(tireMountRepositoryProvider).listForVehicle(widget.vehicleId);
    await _applyWrites(TireService.planMount(
      vehicleId: UuidValue.parse(widget.vehicleId),
      tireId: tireId,
      position: widget.position,
      odometer: odo,
      date: _ymd,
      mounts: mounts,
      now: DateTime.now().toUtc(),
    ));
  }

  Future<void> _dismount() async {
    final odo = _readOdo();
    if (odo == null) return;
    final mounts = await ref.read(tireMountRepositoryProvider).listForVehicle(widget.vehicleId);
    await _applyWrites(TireService.planDismount(
      position: widget.position,
      odometer: odo,
      date: _ymd,
      mounts: mounts,
      now: DateTime.now().toUtc(),
    ));
  }

  String _tireLabel(Tire t, String? currentPos) {
    final bits = [t.descriptor, if (t.size != null && t.size!.isNotEmpty) t.size!].join(' · ');
    final where = currentPos == null ? 'en stock' : positionLabel(currentPos);
    return '$bits — $where';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final colors = context.appColors;
    final tires = ref.watch(tiresProvider(widget.vehicleId)).value ?? const <Tire>[];
    final mounts = ref.watch(tireMountsProvider(widget.vehicleId)).value ?? const <TireMount>[];
    final occupant = TireService.mountAtPosition(widget.position, mounts);
    final positionByTire = <String, String>{
      for (final m in mounts)
        if (m.isOpen) m.tireId.value: m.position,
    };
    Tire? occupantTire;
    if (occupant != null) {
      for (final t in tires) {
        if (t.id == occupant.tireId) {
          occupantTire = t;
          break;
        }
      }
    }
    // Candidats au montage : pneus non mis au rebut, sauf celui déjà ici.
    final candidates = tires
        .where((t) => !t.isDisposed && (occupant == null || t.id != occupant.tireId))
        .toList();
    final selected =
        _selectedTireId != null && candidates.any((t) => t.id.value == _selectedTireId)
            ? _selectedTireId
            : (candidates.isNotEmpty ? candidates.first.id.value : null);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Position ${positionLabel(widget.position)}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            if (occupantTire != null)
              Text('Actuellement : ${occupantTire.descriptor}'
                  '${occupantTire.size != null ? ' · ${occupantTire.size}' : ''}',
                  style: TextStyle(color: colors.textMuted))
            else
              Text('Vide', style: TextStyle(color: colors.textMuted)),
            const SizedBox(height: 16),
            TextField(
              key: const Key('mountOdometerField'),
              controller: _odo,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Kilométrage du changement', suffixText: 'km'),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date'),
                child: Text(formatDate(_date)),
              ),
            ),
            const SizedBox(height: 16),
            if (candidates.isEmpty)
              Text(
                occupant == null
                    ? 'Aucun pneu en inventaire. Ajoute d\'abord un pneu.'
                    : 'Aucun autre pneu disponible à monter ici.',
                style: TextStyle(color: colors.textMuted),
              )
            else ...[
              DropdownButtonFormField<String>(
                key: const Key('mountTireDropdown'),
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Pneu à monter'),
                items: candidates
                    .map((t) => DropdownMenuItem(
                          value: t.id.value,
                          child: Text(_tireLabel(t, positionByTire[t.id.value]),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedTireId = v),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('mountConfirmButton'),
                onPressed: _saving || selected == null ? null : () => _mount(selected),
                icon: const Icon(Icons.check),
                label: const Text('Monter ici'),
              ),
            ],
            if (occupant != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('dismountButton'),
                onPressed: _saving ? null : _dismount,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Démonter (→ stock)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
