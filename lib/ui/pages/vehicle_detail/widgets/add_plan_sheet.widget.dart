import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/maintenance_plan.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';

/// Crée ou édite une entrée de l'onglet *À prévoir*, de deux natures :
/// - **Échéance récurrente** : porte un intervalle (km et/ou mois) ; se remet à
///   zéro quand une opération porte une ligne au même intitulé que le titre ;
///   ne disparaît jamais (elle cycle).
/// - **Tâche ponctuelle** : à faire une fois (ex. changer un rétroviseur), sans
///   périodicité, cible date/km optionnelle ; **disparaît une fois faite** (une
///   opération du même intitulé). Peut être recréée plus tard.
///
/// [prefilledTitle] sert aux créations amorcées ailleurs — typiquement « prévoir
/// la réparation » depuis un code défaut (§5.11) : le titre arrive rempli, tout
/// le reste se saisit normalement.
Future<void> showPlanSheet(
  BuildContext context,
  WidgetRef ref, {
  required String vehicleId,
  Plan? existing,
  String? prefilledTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _PlanSheet(vehicleId: vehicleId, existing: existing, prefilledTitle: prefilledTitle),
  );
}

class _PlanSheet extends ConsumerStatefulWidget {
  const _PlanSheet({required this.vehicleId, this.existing, this.prefilledTitle});
  final String vehicleId;
  final Plan? existing;
  final String? prefilledTitle;

  @override
  ConsumerState<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends ConsumerState<_PlanSheet> {
  late final TextEditingController _title;
  late final TextEditingController _intervalKm;
  late final TextEditingController _intervalMonths;
  late final TextEditingController _dueOdometer;
  DateTime? _dueDate;
  late bool _oneShot; // true = tâche ponctuelle ; false = échéance récurrente
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _oneShot = e != null ? !e.isRecurring : true;
    _title = TextEditingController(text: e?.title ?? widget.prefilledTitle ?? '');
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
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Donne un titre.')));
      return;
    }
    final km = _oneShot ? null : int.tryParse(_intervalKm.text.trim());
    final months = _oneShot ? null : int.tryParse(_intervalMonths.text.trim());
    if (!_oneShot && km == null && months == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Renseigne un intervalle (km ou mois) pour une échéance récurrente.')),
      );
      return;
    }
    setState(() => _saving = true);
    final e = widget.existing;
    final plan = Plan(
      id: e?.id ?? UuidValue.generate(),
      vehicleId: UuidValue.parse(widget.vehicleId),
      title: title,
      priority: e?.priority,
      estimatedCost: e?.estimatedCost,
      intervalKm: km,
      intervalMonths: months,
      dueDate: _dueDate?.toIso8601String().substring(0, 10),
      dueOdometer: int.tryParse(_dueOdometer.text.trim()),
      updatedAt: DateTime.now().toUtc(),
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
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(isEdit ? 'Modifier' : 'Nouvelle entrée',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Ponctuelle'), icon: Icon(Icons.task_alt)),
                ButtonSegment(value: false, label: Text('Échéance'), icon: Icon(Icons.autorenew)),
              ],
              selected: {_oneShot},
              onSelectionChanged: (s) => setState(() => _oneShot = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Titre',
                hintText: _oneShot ? 'Changer le rétroviseur…' : 'Vidange, Contrôle technique…',
              ),
            ),
            if (!_oneShot) ...[
              const SizedBox(height: 16),
              Text('Récurrence', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
              const SizedBox(height: 8),
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
            ],
            const SizedBox(height: 16),
            Text(_oneShot ? 'À faire avant (optionnel)' : 'Échéance cible / amorce (optionnel)',
                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
            const SizedBox(height: 8),
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
            const SizedBox(height: 20),
            FilledButton(onPressed: _saving ? null : _save, child: const Text('Enregistrer')),
            if (isEdit) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
