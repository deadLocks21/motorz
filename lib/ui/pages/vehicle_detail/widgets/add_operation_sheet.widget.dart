import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/maintenance_operation.dart';
import 'package:motorz/core/domain/model/maintenance_operation_line.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/utils/format.dart';

double? _num(String s) {
  final t = s.trim();
  return t.isEmpty ? null : double.tryParse(t.replaceAll(',', '.'));
}

/// Saisie / édition d'une **opération d'entretien** : un en-tête (date, km,
/// prestataire, note) + un **panier de lignes** (postes faits, en libellé libre
/// + coûts). Le coût total = Σ lignes. Une ligne au même intitulé qu'une échéance
/// la remet à zéro (rapprochement par intitulé, cf. À prévoir).
Future<void> showAddOperationSheet(
  BuildContext context,
  WidgetRef ref, {
  required String vehicleId,
  int? lastOdometer,
  Operation? existing,
  List<OperationLine> existingLines = const [],
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
    ),
  );
}

/// Brouillon d'une ligne en cours de saisie.
class _LineDraft {
  _LineDraft({this.existingId, String label = '', double? parts, double? labor})
      : labelCtrl = TextEditingController(text: label),
        partsCtrl = TextEditingController(text: parts?.toString() ?? ''),
        laborCtrl = TextEditingController(text: labor?.toString() ?? '');

  final UuidValue? existingId;
  final TextEditingController labelCtrl;

  /// Focus propre au champ « Pièce » de la ligne (requis par l'`Autocomplete` des
  /// suggestions d'échéances) : un par ligne pour que chaque liste s'ouvre seule.
  final FocusNode labelFocus = FocusNode();
  final TextEditingController partsCtrl;
  final TextEditingController laborCtrl;

  void dispose() {
    labelCtrl.dispose();
    labelFocus.dispose();
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
  });

  final String vehicleId;
  final int? lastOdometer;
  final Operation? existing;
  final List<OperationLine> existingLines;

  @override
  ConsumerState<_AddOperationSheet> createState() => _AddOperationSheetState();
}

class _AddOperationSheetState extends ConsumerState<_AddOperationSheet> {
  late final TextEditingController _odo;
  late final TextEditingController _title;
  late final TextEditingController _provider;
  final _providerFocus = FocusNode();
  late final TextEditingController _note;
  late DateTime _date;

  /// Fait par moi-même. Par défaut à la création : c'est le cas courant ici, et
  /// c'est ce qui distingue une économie d'un simple changement de garage.
  late bool _isDiy;
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
    _isDiy = e?.isDiy ?? true;
    _date = e?.date.toLocal() ?? DateTime.now();
    for (final l in widget.existingLines) {
      _lines.add(_LineDraft(existingId: l.id, label: l.label, parts: l.partsCost, labor: l.laborCost));
    }
    if (_lines.isEmpty) _lines.add(_LineDraft());
  }

  @override
  void dispose() {
    for (final c in [_odo, _title, _provider, _note]) {
      c.dispose();
    }
    _providerFocus.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final odo = int.tryParse(_odo.text.trim());
    if (odo == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Kilométrage requis.')));
      return;
    }
    final drafts = _lines.where((d) => d.labelCtrl.text.trim().isNotEmpty).toList();
    if (drafts.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ajoute au moins un poste.')));
      return;
    }
    final provider = _provider.text.trim();
    if (!_isDiy && provider.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Indique le prestataire.')));
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now().toUtc();
    final opId = widget.existing?.id ?? UuidValue.generate();

    // Opération d'abord, puis ses lignes (ordre = contrat FK côté sync).
    final op = Operation(
      id: opId,
      vehicleId: UuidValue.parse(widget.vehicleId),
      createdByUserId: widget.existing?.createdByUserId,
      date: _date.toUtc(),
      odometer: odo,
      title: _title.text.trim().isEmpty ? null : _title.text.trim(),
      // « Moi-même » ne se saisit plus en texte libre : c'est le switch qui le dit.
      provider: _isDiy ? null : provider,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      isDiy: _isDiy,
      updatedAt: now,
    );
    await ref.read(operationRepositoryProvider).save(op);

    final keptLineIds = <String>{};
    for (final d in drafts) {
      final line = OperationLine(
        id: d.existingId ?? UuidValue.generate(),
        operationId: opId,
        label: d.labelCtrl.text.trim(),
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

    if (mounted) Navigator.of(context).pop();
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
    final providers = ref.watch(knownProvidersProvider).value ?? const <String>[];
    final partLabels =
        ref.watch(knownPartLabelsProvider(widget.vehicleId)).value ?? const <String>[];
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
                    key: const Key('operationOdometerField'),
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
            SwitchListTile(
              key: const Key('operationDiySwitch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Fait par moi-même'),
              value: _isDiy,
              onChanged: (v) => setState(() => _isDiy = v),
            ),
            // Un prestataire n'a de sens que si ce n'est pas moi qui l'ai faite.
            if (!_isDiy) ...[
              const SizedBox(height: 4),
              _providerField(providers),
            ],
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
            const SizedBox(height: 4),
            Text(
              'Un poste au même intitulé qu\'une échéance la remet à zéro.',
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _lines.length; i++) _lineCard(i, partLabels),
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
              key: const Key('saveOperationButton'),
              onPressed: _saving ? null : _save,
              child: Text(_isEdit ? 'Enregistrer' : 'Enregistrer l\'opération'),
            ),
          ],
        ),
      ),
    );
  }

  /// Champ « Prestataire », affiché seulement hors DIY et alors **obligatoire**.
  /// Tant qu'aucun prestataire n'a été saisi, simple champ
  /// texte. Dès qu'on en a, autocomplétion sur les prestataires déjà connus
  /// ([providers]) : la liste s'ouvre au focus (chevron) et se filtre à la frappe,
  /// tout en laissant taper un prestataire inédit. Même contrôleur et même focus
  /// dans les deux cas pour que [_save] lise toujours la valeur. Calque du champ
  /// « Station » d'un plein ; ici le champ est en haut de la feuille, la liste
  /// s'ouvre donc vers le bas (défaut).
  Widget _providerField(List<String> providers) {
    const decoration = InputDecoration(labelText: 'Prestataire', hintText: 'Garage Dupont');
    if (providers.isEmpty) {
      return TextField(
        key: const Key('operationProviderField'),
        controller: _provider,
        focusNode: _providerFocus,
        textCapitalization: TextCapitalization.words,
        decoration: decoration,
      );
    }
    return Autocomplete<String>(
      textEditingController: _provider,
      focusNode: _providerFocus,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return providers; // focus champ vide → tout proposer
        final matches = providers.where((s) => s.toLowerCase().contains(q)).toList();
        // Après une sélection, la saisie == l'option : inutile de garder un menu
        // d'un seul item identique.
        if (matches.length == 1 && matches.first.toLowerCase() == q) {
          return const Iterable<String>.empty();
        }
        return matches;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          key: const Key('operationProviderField'),
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          decoration: decoration.copyWith(suffixIcon: const Icon(Icons.arrow_drop_down)),
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
    );
  }

  /// Champ « Pièce » d'une ligne. Tant qu'aucune échéance n'est « À prévoir »,
  /// simple champ texte. Dès qu'il y en a, autocomplétion sur leurs intitulés
  /// ([partLabels], déjà ordonnés comme l'onglet À prévoir) : la liste s'ouvre au
  /// focus (chevron) et se filtre à la frappe, tout en laissant saisir un poste
  /// inédit. Saisir une ligne au même intitulé qu'une échéance la remet à zéro,
  /// d'où la proposition directe des échéances en attente. Calque des champs
  /// « Station »/« Prestataire » ; un contrôleur et un focus par ligne.
  Widget _partLabelField(_LineDraft d, List<String> partLabels) {
    const decoration = InputDecoration(
      labelText: 'Pièce',
      hintText: 'Vidange, Plaquettes…',
    );
    if (partLabels.isEmpty) {
      return TextField(
        controller: d.labelCtrl,
        focusNode: d.labelFocus,
        textCapitalization: TextCapitalization.sentences,
        decoration: decoration,
      );
    }
    return Autocomplete<String>(
      textEditingController: d.labelCtrl,
      focusNode: d.labelFocus,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return partLabels; // focus champ vide → tout proposer
        final matches = partLabels.where((s) => s.toLowerCase().contains(q)).toList();
        // Après une sélection, la saisie == l'option : inutile de garder un menu
        // d'un seul item identique.
        if (matches.length == 1 && matches.first.toLowerCase() == q) {
          return const Iterable<String>.empty();
        }
        return matches;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.sentences,
          decoration: decoration.copyWith(suffixIcon: const Icon(Icons.arrow_drop_down)),
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
    );
  }

  Widget _lineCard(int i, List<String> partLabels) {
    final d = _lines[i];
    return Padding(
      // Clé d'identité : chaque carte suit son brouillon (et donc l'état de son
      // Autocomplete) lors des ajouts/retraits de lignes.
      key: ValueKey(d),
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _partLabelField(d, partLabels)),
              IconButton(
                tooltip: 'Retirer',
                icon: const Icon(Icons.close),
                onPressed:
                    _lines.length > 1 ? () => setState(() => _lines.removeAt(i).dispose()) : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: d.partsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Prix', suffixText: '€'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: d.laborCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Main d\'œuvre', suffixText: '€'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
