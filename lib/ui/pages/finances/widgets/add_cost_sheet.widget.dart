import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/cost_entry.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/ui/utils/format.dart';

double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

/// Saisit un frais — ponctuel (un paiement daté) ou récurrent (« 800 € par an »,
/// décrit une fois pour toutes). Passe [existing] pour rouvrir en édition.
Future<void> showAddCostSheet(
  BuildContext context,
  WidgetRef ref, {
  required String vehicleId,
  CostEntry? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddCostSheet(vehicleId: vehicleId, existing: existing),
  );
}

class _AddCostSheet extends ConsumerStatefulWidget {
  const _AddCostSheet({required this.vehicleId, this.existing});
  final String vehicleId;
  final CostEntry? existing;

  @override
  ConsumerState<_AddCostSheet> createState() => _AddCostSheetState();
}

class _AddCostSheetState extends ConsumerState<_AddCostSheet> {
  late final TextEditingController _label;
  late final TextEditingController _amount;
  late String _category;
  // Défaut : l'assurance annuelle — le cas archétypal, celui qu'on veut décrire
  // une fois au lieu d'ajouter une ligne à chaque échéance.
  late CostRecurrence _recurrence;
  late DateTime _date;
  DateTime? _endDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = TextEditingController(text: e?.label ?? '');
    _amount = TextEditingController(text: e?.amount?.toString().replaceAll('.', ',') ?? '');
    _category = e?.category ?? 'assurance';
    _recurrence = e?.recurrence ?? CostRecurrence.annuel;
    _date = e?.date.toLocal() ?? DateTime.now();
    _endDate = e?.endDate?.toLocal();
  }

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isEnd ? _endDate : _date) ?? now,
      firstDate: DateTime(2000),
      // Une charge récurrente peut légitimement se terminer dans le futur (fin
      // de contrat déjà connue) ; un paiement ponctuel, non.
      lastDate: isEnd ? DateTime(now.year + 20) : now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => isEnd ? _endDate = picked : _date = picked);
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nomme la dépense.')));
      return;
    }
    final end = _recurrence.isRecurring ? _endDate : null;
    if (end != null && end.isBefore(_date)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('La fin précède le début.')));
      return;
    }
    setState(() => _saving = true);
    final base = widget.existing;
    final cost = CostEntry(
      id: base?.id ?? UuidValue.generate(),
      vehicleId: UuidValue.parse(widget.vehicleId),
      createdByUserId: base?.createdByUserId,
      label: label,
      category: _category,
      amount: _num(_amount.text),
      recurrence: _recurrence,
      date: _date.toUtc(),
      endDate: end?.toUtc(),
      notes: base?.notes,
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(costEntryRepositoryProvider).save(cost);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final recurring = _recurrence.isRecurring;
    final amount = _num(_amount.text);
    final monthly = (recurring && amount != null) ? amount / _recurrence.months : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'Dépense' : 'Modifier la dépense',
                style: Theme.of(context).textTheme.titleLarge),
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
            DropdownButtonFormField<CostRecurrence>(
              key: const Key('costRecurrenceField'),
              initialValue: _recurrence,
              decoration: const InputDecoration(labelText: 'Périodicité'),
              items: [
                for (final r in CostRecurrence.values)
                  DropdownMenuItem(value: r, child: Text(r.label)),
              ],
              onChanged: (v) => setState(() => _recurrence = v ?? CostRecurrence.ponctuel),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('costLabelField'),
              controller: _label,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Libellé',
                hintText: recurring ? 'Assurance tous risques' : 'Franchise sinistre',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('costAmountField'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              // Le suffixe porte la périodicité : « 800 € /an » ne se confond
              // pas avec un versement unique de 800 €.
              decoration: InputDecoration(
                labelText: recurring ? 'Montant par période' : 'Montant',
                suffixText: '€${_recurrence.suffix}',
                helperText: (monthly != null && _recurrence != CostRecurrence.mensuel)
                    ? 'Soit ${formatEur(monthly)} par mois'
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _pickDate(isEnd: false),
              child: InputDecorator(
                decoration: InputDecoration(labelText: recurring ? 'Depuis le' : 'Date'),
                child: Text(formatDate(_date)),
              ),
            ),
            if (recurring) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _pickDate(isEnd: true),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Jusqu\'au',
                    helperText: 'Laisse vide tant que la charge court',
                    suffixIcon: _endDate == null
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _endDate = null),
                          ),
                  ),
                  child: Text(_endDate == null ? 'En cours' : formatDate(_endDate!)),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('saveCostButton'),
              onPressed: _saving ? null : _save,
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
