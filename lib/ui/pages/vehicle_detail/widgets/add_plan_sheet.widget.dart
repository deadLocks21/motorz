import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/maintenance_catalog_item.dart';
import 'package:motorz/core/domain/model/maintenance_plan.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';

/// Crée ou édite un **plan** (échéance à prévoir).
/// - Sans [existing] : crée une **échéance à venir** (CT d'occasion, distribution
///   jamais faite, réparation ponctuelle) — titre + cible date/km.
/// - Avec un plan **récurrent** (poste de catalogue) : édite ses **intervalles**.
/// - Avec un plan **ponctuel** : édite titre + cible.
///
/// Les plans récurrents se créent par **émergence** (saisie d'opération), pas ici.
Future<void> showPlanSheet(
  BuildContext context,
  WidgetRef ref, {
  required String vehicleId,
  Plan? existing,
  Map<String, CatalogItem> catalogById = const {},
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PlanSheet(vehicleId: vehicleId, existing: existing, catalogById: catalogById),
  );
}

class _PlanSheet extends ConsumerStatefulWidget {
  const _PlanSheet({required this.vehicleId, this.existing, this.catalogById = const {}});
  final String vehicleId;
  final Plan? existing;
  final Map<String, CatalogItem> catalogById;

  @override
  ConsumerState<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends ConsumerState<_PlanSheet> {
  late final TextEditingController _title;
  late final TextEditingController _intervalKm;
  late final TextEditingController _intervalMonths;
  late final TextEditingController _dueOdometer;
  DateTime? _dueDate;
  bool _saving = false;

  bool get _recurring => widget.existing?.catalogItemId != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _intervalKm = TextEditingController(text: e?.intervalKm?.toString() ?? '');
    _intervalMonths = TextEditingController(text: e?.intervalMonths?.toString() ?? '');
    _dueOdometer = TextEditingController(text: e?.dueOdometer?.toString() ?? '');
    _dueDate = e?.dueDate != null ? DateTime.tryParse(e!.dueDate!) : null;
  }

  @override
  void dispose() {
    for (final c in [_title, _intervalKm, _intervalMonths, _dueOdometer]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final e = widget.existing;
    final now = DateTime.now().toUtc();
    if (!_recurring && _title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Donne un titre à l\'échéance.')));
      return;
    }
    setState(() => _saving = true);
    final plan = Plan(
      id: e?.id ?? UuidValue.generate(),
      vehicleId: UuidValue.parse(widget.vehicleId),
      catalogItemId: e?.catalogItemId,
      title: _recurring ? e?.title : (_title.text.trim().isEmpty ? null : _title.text.trim()),
      priority: e?.priority,
      estimatedCost: e?.estimatedCost,
      intervalKm: _recurring ? int.tryParse(_intervalKm.text.trim()) : e?.intervalKm,
      intervalMonths: _recurring ? int.tryParse(_intervalMonths.text.trim()) : e?.intervalMonths,
      dueDate: _recurring ? e?.dueDate : _dueDate?.toIso8601String().substring(0, 10),
      dueOdometer: _recurring ? e?.dueOdometer : int.tryParse(_dueOdometer.text.trim()),
      updatedAt: now,
    );
    await ref.read(planRepositoryProvider).save(plan);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final e = widget.existing;
    if (e == null) return;
    await ref.read(planRepositoryProvider).delete(e);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final e = widget.existing;
    final catalogName =
        e?.catalogItemId != null ? widget.catalogById[e!.catalogItemId!.value]?.name : null;
    final heading = _recurring
        ? 'Rappel récurrent${catalogName != null ? ' · $catalogName' : ''}'
        : (e == null ? 'Échéance à venir' : 'Modifier l\'échéance');

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(heading, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (_recurring) ...[
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
            ),
          ] else ...[
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Titre', hintText: 'Contrôle technique, distribution…'),
            ),
            const SizedBox(height: 12),
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
                        initialDate: _dueDate ?? now,
                        firstDate: now.subtract(const Duration(days: 365)),
                        lastDate: now.add(const Duration(days: 365 * 10)),
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
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Enregistrer')),
          if (e != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Supprimer cette échéance'),
            ),
          ],
        ],
      ),
    );
  }
}
