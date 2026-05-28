import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/application/services/catalog_defaults.dart';
import 'package:motorz/core/domain/model/maintenance_catalog_item.dart';
import 'package:motorz/core/domain/model/maintenance_operation.dart';
import 'package:motorz/core/domain/model/maintenance_operation_line.dart';
import 'package:motorz/core/domain/model/maintenance_plan.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/utils/format.dart';

double? _num(String s) {
  final t = s.trim();
  return t.isEmpty ? null : double.tryParse(t.replaceAll(',', '.'));
}

/// Saisie / édition d'une **opération d'entretien** : un en-tête (date, km,
/// prestataire, note) + un **panier de lignes** (postes faits). Chaque ligne est
/// soit un poste du catalogue, soit un libellé libre. Le coût total = Σ lignes.
Future<void> showAddOperationSheet(
  BuildContext context,
  WidgetRef ref, {
  required String vehicleId,
  int? lastOdometer,
  Operation? existing,
  List<OperationLine> existingLines = const [],
  Map<String, CatalogItem> catalogById = const {},
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddOperationSheet(
      vehicleId: vehicleId,
      lastOdometer: lastOdometer,
      existing: existing,
      existingLines: existingLines,
      catalogById: catalogById,
    ),
  );
}

/// Brouillon d'une ligne en cours de saisie.
class _LineDraft {
  _LineDraft({
    this.existingId,
    String name = '',
    this.freeMode = false,
    double? parts,
    double? labor,
  })  : nameCtrl = TextEditingController(text: name),
        partsCtrl = TextEditingController(text: parts?.toString() ?? ''),
        laborCtrl = TextEditingController(text: labor?.toString() ?? '');

  final UuidValue? existingId;
  final TextEditingController nameCtrl;
  final TextEditingController partsCtrl;
  final TextEditingController laborCtrl;
  bool freeMode;

  void dispose() {
    nameCtrl.dispose();
    partsCtrl.dispose();
    laborCtrl.dispose();
  }
}

class _AddOperationSheet extends ConsumerStatefulWidget {
  const _AddOperationSheet({
    required this.vehicleId,
    this.lastOdometer,
    this.existing,
    this.existingLines = const [],
    this.catalogById = const {},
  });

  final String vehicleId;
  final int? lastOdometer;
  final Operation? existing;
  final List<OperationLine> existingLines;
  final Map<String, CatalogItem> catalogById;

  @override
  ConsumerState<_AddOperationSheet> createState() => _AddOperationSheetState();
}

class _AddOperationSheetState extends ConsumerState<_AddOperationSheet> {
  late final TextEditingController _odo;
  late final TextEditingController _title;
  late final TextEditingController _provider;
  late final TextEditingController _note;
  late DateTime _date;
  final List<_LineDraft> _lines = [];
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _odo = TextEditingController(text: (e?.odometer ?? widget.lastOdometer)?.toString() ?? '');
    _title = TextEditingController(text: e?.title ?? '');
    _provider = TextEditingController(text: e?.provider ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _date = e?.date.toLocal() ?? DateTime.now();
    for (final l in widget.existingLines) {
      final free = l.label != null;
      _lines.add(_LineDraft(
        existingId: l.id,
        name: free ? l.label! : (widget.catalogById[l.catalogItemId!.value]?.name ?? ''),
        freeMode: free,
        parts: l.partsCost,
        labor: l.laborCost,
      ));
    }
    if (_lines.isEmpty) _lines.add(_LineDraft());
  }

  @override
  void dispose() {
    for (final c in [_odo, _title, _provider, _note]) {
      c.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<UuidValue?> _userId() async {
    final session = ref.read(currentSessionProvider);
    if (session != null) return session.user.id;
    final v = await ref.read(vehicleByIdProvider(widget.vehicleId).future);
    return v?.ownerUserId;
  }

  Future<CatalogItem> _resolveCatalog(String name, UuidValue userId) async {
    final items = await ref.read(catalogItemsProvider.future);
    final found = items.where((c) => c.name.toLowerCase() == name.toLowerCase()).firstOrNull;
    if (found != null) return found;
    final def =
        catalogDefaults.where((d) => d.name.toLowerCase() == name.toLowerCase()).firstOrNull;
    final item = CatalogItem(
      id: UuidValue.generate(),
      userId: userId,
      name: name,
      defaultIntervalKm: def?.defaultIntervalKm,
      defaultIntervalMonths: def?.defaultIntervalMonths,
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(catalogItemRepositoryProvider).save(item);
    return item;
  }

  Future<void> _save() async {
    final odo = int.tryParse(_odo.text.trim());
    if (odo == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Kilométrage requis.')));
      return;
    }
    final drafts = _lines.where((d) => d.nameCtrl.text.trim().isNotEmpty).toList();
    if (drafts.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ajoute au moins un poste.')));
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now().toUtc();
    final opId = widget.existing?.id ?? UuidValue.generate();

    // Opération d'abord, puis ses lignes (ordre = contrat FK côté sync, et la
    // dérivation lit les lignes via leur opération parente).
    final op = Operation(
      id: opId,
      vehicleId: UuidValue.parse(widget.vehicleId),
      createdByUserId: widget.existing?.createdByUserId,
      date: _date.toUtc(),
      odometer: odo,
      title: _title.text.trim().isEmpty ? null : _title.text.trim(),
      provider: _provider.text.trim().isEmpty ? null : _provider.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      countQuoteInEstimate: widget.existing?.countQuoteInEstimate ?? true,
      updatedAt: now,
    );
    await ref.read(operationRepositoryProvider).save(op);

    final userId = await _userId();
    final usedCatalog = <CatalogItem>[];
    final keptLineIds = <String>{};
    for (final d in drafts) {
      final name = d.nameCtrl.text.trim();
      UuidValue? catalogItemId;
      String? label;
      if (d.freeMode || userId == null) {
        label = name;
      } else {
        final item = await _resolveCatalog(name, userId);
        catalogItemId = item.id;
        usedCatalog.add(item);
      }
      final line = OperationLine(
        id: d.existingId ?? UuidValue.generate(),
        operationId: opId,
        catalogItemId: catalogItemId,
        label: label,
        partsCost: _num(d.partsCtrl.text),
        laborCost: _num(d.laborCtrl.text),
        updatedAt: now,
      );
      keptLineIds.add(line.id.value);
      await ref.read(operationLineRepositoryProvider).save(line);
    }
    // Édition : supprimer les lignes retirées.
    for (final old in widget.existingLines) {
      if (!keptLineIds.contains(old.id.value)) {
        await ref.read(operationLineRepositoryProvider).delete(old);
      }
    }

    if (!mounted) return;
    await _maybeEmerge(usedCatalog);
    if (mounted) Navigator.of(context).pop();
  }

  /// Émergence : pour chaque poste de catalogue sans plan existant, proposer de
  /// programmer un rappel (intervalles pré-suggérés par le catalogue).
  Future<void> _maybeEmerge(List<CatalogItem> used) async {
    if (used.isEmpty) return;
    final plans = await ref.read(plansProvider(widget.vehicleId).future);
    final planned = plans.map((p) => p.catalogItemId?.value).whereType<String>().toSet();
    final seen = <String>{};
    for (final item in used) {
      if (!seen.add(item.id.value)) continue;
      if (planned.contains(item.id.value)) continue;
      if (!mounted) return;
      await _promptPlan(item);
    }
  }

  Future<void> _promptPlan(CatalogItem item) async {
    final km = TextEditingController(text: item.defaultIntervalKm?.toString() ?? '');
    final mo = TextEditingController(text: item.defaultIntervalMonths?.toString() ?? '');
    final create = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Programmer un rappel ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Être prévenu pour « ${item.name} » à l\'avenir ?'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: km,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Tous les', suffixText: 'km'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: mo,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'ou tous les', suffixText: 'mois'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non merci')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Programmer')),
        ],
      ),
    );
    if (create == true) {
      final ikm = int.tryParse(km.text.trim());
      final imo = int.tryParse(mo.text.trim());
      if (ikm != null || imo != null) {
        await ref.read(planRepositoryProvider).save(Plan(
              id: UuidValue.generate(),
              vehicleId: UuidValue.parse(widget.vehicleId),
              catalogItemId: item.id,
              intervalKm: ikm,
              intervalMonths: imo,
              updatedAt: DateTime.now().toUtc(),
            ));
      }
    }
    km.dispose();
    mo.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'Modifier l\'opération' : 'Entretien réalisé',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _odo,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Km', suffixText: 'km'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(formatDate(_date)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Titre (optionnel)',
                hintText: 'Laisser vide pour un titre auto',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _provider,
              decoration: const InputDecoration(labelText: 'Prestataire', hintText: 'Garage / moi-même'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note', hintText: 'Détails (optionnel)'),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Postes', style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _lines.length; i++) _lineCard(i),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _lines.add(_LineDraft())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter une ligne'),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_isEdit ? 'Enregistrer' : 'Enregistrer l\'opération'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineCard(int i) {
    final d = _lines[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: d.freeMode ? 'Libellé libre (hors catalogue)' : 'Poste du catalogue',
                icon: Icon(d.freeMode ? Icons.edit_note : Icons.bookmark_added_outlined),
                onPressed: () => setState(() => d.freeMode = !d.freeMode),
              ),
              Expanded(
                child: TextField(
                  controller: d.nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Poste',
                    hintText: d.freeMode ? 'Libellé libre' : 'Vidange, filtres…',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Retirer',
                icon: const Icon(Icons.close),
                onPressed: _lines.length > 1 ? () => setState(() => _lines.removeAt(i).dispose()) : null,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: d.partsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Pièces', suffixText: '€', isDense: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: d.laborCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Main d\'œuvre', suffixText: '€', isDense: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
