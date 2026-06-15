import 'package:flutter/material.dart';
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

double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

/// `YYYY-MM-DD` → `dd/MM/yyyy` (repli sur la valeur brute si non parsable).
String _fmtYmd(String ymd) {
  final d = DateTime.tryParse(ymd);
  return d != null ? formatDate(d) : ymd;
}

String _todayYmd() => DateTime.now().toIso8601String().substring(0, 10);

/// Feuille de création/édition d'un pneu de l'inventaire. Passe [existing] pour
/// l'édition (même id). La suppression efface aussi le journal de montages du
/// pneu (tombstones).
Future<void> showTireSheet(
  BuildContext context,
  WidgetRef ref, {
  required String vehicleId,
  Tire? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TireSheet(vehicleId: vehicleId, existing: existing),
  );
}

class _TireSheet extends ConsumerStatefulWidget {
  const _TireSheet({required this.vehicleId, this.existing});
  final String vehicleId;
  final Tire? existing;

  @override
  ConsumerState<_TireSheet> createState() => _TireSheetState();
}

class _TireSheetState extends ConsumerState<_TireSheet> {
  final _brand = TextEditingController();
  final _brandFocus = FocusNode();
  final _model = TextEditingController();
  final _size = TextEditingController();
  final _sizeFocus = FocusNode();
  final _rimSpec = TextEditingController();
  final _price = TextEditingController();
  final _notes = TextEditingController();
  RimMaterial? _rimMaterial;
  TireSeason? _season;
  TireCondition _condition = TireCondition.neuf;
  DateTime? _purchaseDate;

  /// Date de mise au rebut (YYYY-MM-DD) ; null = en service. Préservée au save.
  String? _disposedDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _brand.text = e.brand ?? '';
      _model.text = e.model ?? '';
      _size.text = e.size ?? '';
      _rimSpec.text = e.rimSpec ?? '';
      if (e.purchasePrice != null) _price.text = _fmtInput(e.purchasePrice!);
      _notes.text = e.notes ?? '';
      _rimMaterial = e.rimMaterial;
      _season = e.season;
      _condition = e.condition;
      _purchaseDate = e.purchaseDate != null ? DateTime.tryParse(e.purchaseDate!) : null;
      _disposedDate = e.disposedDate;
    }
  }

  static String _fmtInput(double v) {
    var s = v.toString();
    if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
    return s.replaceAll('.', ',');
  }

  @override
  void dispose() {
    for (final c in [_brand, _model, _size, _rimSpec, _price, _notes]) {
      c.dispose();
    }
    _brandFocus.dispose();
    _sizeFocus.dispose();
    super.dispose();
  }

  String? _emptyToNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? now,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    if (picked != null) setState(() => _purchaseDate = picked);
  }

  /// Construit le pneu depuis les champs du formulaire, en conservant l'identité
  /// et le statut au rebut courant ([_disposedDate]).
  Tire _buildTire() {
    final base = widget.existing;
    return Tire(
      id: base?.id ?? UuidValue.generate(),
      vehicleId: base?.vehicleId ?? UuidValue.parse(widget.vehicleId),
      createdByUserId: base?.createdByUserId,
      brand: _emptyToNull(_brand),
      model: _emptyToNull(_model),
      size: _emptyToNull(_size),
      rimMaterial: _rimMaterial,
      rimSpec: _emptyToNull(_rimSpec),
      season: _season,
      condition: _condition,
      purchaseDate: _purchaseDate?.toIso8601String().substring(0, 10),
      purchasePrice: _num(_price.text),
      notes: _emptyToNull(_notes),
      disposedDate: _disposedDate,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(tireRepositoryProvider).save(_buildTire());
    if (mounted) Navigator.of(context).pop();
  }

  /// Met le pneu au rebut : le démonte d'abord s'il roule (fige ses km au km
  /// courant), puis pose la date de mise au rebut. Les montages sont conservés
  /// (pas de tombstone) → le pneu reste dans l'historique.
  Future<void> _retire() async {
    final ex = widget.existing;
    if (ex == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mettre ce pneu au rebut ?'),
        content: const Text(
            'Il quitte l\'inventaire actif (et la monte) mais reste dans l\'historique. Réversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Au rebut')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    // Démonte s'il est encore monté, pour clore son dernier intervalle.
    final mountRepo = ref.read(tireMountRepositoryProvider);
    final mounts = await mountRepo.listForVehicle(widget.vehicleId);
    final open = TireService.currentMountFor(ex.id.value, mounts);
    if (open != null) {
      final odo =
          await ref.read(currentOdometerProvider(widget.vehicleId).future) ?? open.mountedOdometer;
      for (final w in TireService.planDismount(
        position: open.position,
        odometer: odo,
        date: _todayYmd(),
        mounts: mounts,
        now: DateTime.now().toUtc(),
      )) {
        await mountRepo.save(w);
      }
    }
    _disposedDate = _todayYmd();
    await ref.read(tireRepositoryProvider).save(_buildTire());
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _reinstate() async {
    setState(() => _saving = true);
    _disposedDate = null;
    await ref.read(tireRepositoryProvider).save(_buildTire());
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ex = widget.existing;
    if (ex == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce pneu ?'),
        content: const Text('Le pneu et son historique de montage seront retirés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    // Tombstone aussi le journal de montages du pneu pour ne pas laisser
    // d'intervalle orphelin (et libérer la position s'il était monté).
    final mountRepo = ref.read(tireMountRepositoryProvider);
    final mounts = await mountRepo.listForVehicle(widget.vehicleId);
    for (final m in mounts.where((m) => m.tireId == ex.id)) {
      await mountRepo.delete(m);
    }
    await ref.read(tireRepositoryProvider).delete(ex);
    if (mounted) Navigator.of(context).pop();
  }

  /// Champ texte libre avec autocomplétion sur des valeurs déjà connues
  /// ([options]) — calque du champ « Station » des pleins.
  Widget _suggestField({
    required Key key,
    required TextEditingController controller,
    required FocusNode focus,
    required String label,
    String? hint,
    required List<String> options,
  }) {
    final decoration = InputDecoration(labelText: label, hintText: hint);
    if (options.isEmpty) {
      return TextField(
        key: key,
        controller: controller,
        focusNode: focus,
        textCapitalization: TextCapitalization.words,
        decoration: decoration,
      );
    }
    return Autocomplete<String>(
      textEditingController: controller,
      focusNode: focus,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return options;
        final matches = options.where((s) => s.toLowerCase().contains(q)).toList();
        if (matches.length == 1 && matches.first.toLowerCase() == q) {
          return const Iterable<String>.empty();
        }
        return matches;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextField(
        key: key,
        controller: controller,
        focusNode: focusNode,
        textCapitalization: TextCapitalization.words,
        decoration: decoration.copyWith(suffixIcon: const Icon(Icons.arrow_drop_down)),
        onSubmitted: (_) => onFieldSubmitted(),
      ),
    );
  }

  /// Historique de montage du pneu en cours d'édition (lecture seule) : où il a
  /// été monté et sur combien de km.
  Widget _tireHistory() {
    final tireId = widget.existing!.id.value;
    final mounts = (ref.watch(tireMountsProvider(widget.vehicleId)).value ?? const <TireMount>[])
        .where((m) => m.deletedAt == null && m.tireId.value == tireId)
        .toList()
      ..sort((a, b) => b.mountedOdometer.compareTo(a.mountedOdometer));
    if (mounts.isEmpty) return const SizedBox.shrink();
    final currentOdo = ref.watch(currentOdometerProvider(widget.vehicleId)).value;
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('HISTORIQUE',
            style: TextStyle(
                color: colors.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6)),
        const SizedBox(height: 4),
        for (final m in mounts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(_intervalLabel(m, currentOdo),
                style: TextStyle(color: colors.textMuted, fontSize: 13)),
          ),
      ],
    );
  }

  String _intervalLabel(TireMount m, int? currentOdo) {
    final where = m.position == spareWheelPosition ? 'Secours' : positionLabel(m.position);
    final end = m.dismountedOdometer;
    final endLabel = end != null ? formatKm(end) : 'en cours';
    final spanEnd = end ?? currentOdo;
    final span =
        (m.position != spareWheelPosition && spanEnd != null) ? spanEnd - m.mountedOdometer : null;
    final suffix = (span != null && span > 0) ? '  ·  ${formatKm(span)}' : '';
    return '$where : ${formatKm(m.mountedOdometer)} → $endLabel$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.existing != null;
    final brands = ref.watch(knownTireBrandsProvider).value ?? const <String>[];
    final sizes = ref.watch(knownTireSizesProvider).value ?? const <String>[];
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(isEditing ? 'Modifier le pneu' : 'Nouveau pneu',
                style: Theme.of(context).textTheme.titleLarge),
            if (_disposedDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Au rebut le ${_fmtYmd(_disposedDate!)}',
                    style: TextStyle(color: context.appColors.textMuted)),
              ),
            const SizedBox(height: 16),
            _suggestField(
              key: const Key('tireBrandField'),
              controller: _brand,
              focus: _brandFocus,
              label: 'Marque',
              hint: 'Michelin',
              options: brands,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('tireModelField'),
              controller: _model,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Modèle', hintText: 'Pilot Sport 4S'),
            ),
            const SizedBox(height: 12),
            _suggestField(
              key: const Key('tireSizeField'),
              controller: _size,
              focus: _sizeFocus,
              label: 'Taille',
              hint: '255/40 R19',
              options: sizes,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<RimMaterial?>(
                    initialValue: _rimMaterial,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Jante'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('—')),
                      ...RimMaterial.values
                          .map((m) => DropdownMenuItem(value: m, child: Text(m.label))),
                    ],
                    onChanged: (v) => setState(() => _rimMaterial = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _rimSpec,
                    decoration: const InputDecoration(labelText: 'Dim. jante', hintText: '8J×19 ET40'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TireSeason?>(
              initialValue: _season,
              decoration: const InputDecoration(labelText: 'Saison / usage'),
              items: [
                const DropdownMenuItem(value: null, child: Text('—')),
                ...TireSeason.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))),
              ],
              onChanged: (v) => setState(() => _season = v),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<TireCondition>(
                segments: const [
                  ButtonSegment(value: TireCondition.neuf, label: Text('Neuf')),
                  ButtonSegment(value: TireCondition.occasion, label: Text('Occasion')),
                ],
                selected: {_condition},
                onSelectionChanged: (s) => setState(() => _condition = s.first),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Acheté le (optionnel)'),
                    child: InkWell(
                      key: const Key('tirePurchaseDateField'),
                      onTap: _pickDate,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _purchaseDate == null ? 'Aucune' : formatDate(_purchaseDate!),
                            style: _purchaseDate == null
                                ? TextStyle(color: Theme.of(context).hintColor)
                                : null,
                          ),
                          if (_purchaseDate == null)
                            const Icon(Icons.calendar_today_outlined, size: 18)
                          else
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Effacer la date',
                              onPressed: () => setState(() => _purchaseDate = null),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Prix', suffixText: '€'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notes (optionnel)'),
            ),
            if (isEditing) _tireHistory(),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('saveTireButton'),
              onPressed: _saving ? null : _save,
              child: Text(isEditing ? 'Enregistrer les modifications' : 'Ajouter le pneu'),
            ),
            if (isEditing) ...[
              const SizedBox(height: 8),
              if (_disposedDate == null)
                OutlinedButton.icon(
                  key: const Key('disposeTireButton'),
                  onPressed: _saving ? null : _retire,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Mettre au rebut'),
                )
              else
                OutlinedButton.icon(
                  key: const Key('reinstateTireButton'),
                  onPressed: _saving ? null : _reinstate,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Remettre en service'),
                ),
              const SizedBox(height: 4),
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
