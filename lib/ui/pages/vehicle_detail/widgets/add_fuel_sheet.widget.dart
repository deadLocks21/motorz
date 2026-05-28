import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/fuel_entry.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/utils/format.dart';

double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

/// Représentation compacte d'un nombre pour pré-remplir un champ de saisie :
/// sépare en virgule (locale FR) et sans zéros décimaux superflus. On garde la
/// précision telle quelle (ex. prix 1,859 €/L) — `_num` reparse les deux séparateurs.
String _fmtInput(double v) {
  var s = v.toString();
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s.replaceAll('.', ',');
}

/// Feuille modale de saisie rapide d'un plein (chemin critique §6.2).
///
/// Passe [existing] pour rouvrir la feuille en mode édition : les champs sont
/// pré-remplis et l'enregistrement met à jour l'entrée (même id) au lieu d'en
/// créer une nouvelle.
Future<void> showAddFuelSheet(
  BuildContext context,
  WidgetRef ref, {
  required String vehicleId,
  int? lastOdometer,
  FuelType? defaultFuelType,
  FuelEntry? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddFuelSheet(
      vehicleId: vehicleId,
      lastOdometer: lastOdometer,
      defaultFuelType: defaultFuelType,
      existing: existing,
    ),
  );
}

class _AddFuelSheet extends ConsumerStatefulWidget {
  const _AddFuelSheet({
    required this.vehicleId,
    this.lastOdometer,
    this.defaultFuelType,
    this.existing,
  });

  final String vehicleId;
  final int? lastOdometer;
  final FuelType? defaultFuelType;

  /// Plein à modifier (mode édition). Null → création d'un nouveau plein.
  final FuelEntry? existing;

  @override
  ConsumerState<_AddFuelSheet> createState() => _AddFuelSheetState();
}

class _AddFuelSheetState extends ConsumerState<_AddFuelSheet> {
  late final TextEditingController _odo;
  final _volume = TextEditingController();
  final _price = TextEditingController();
  final _station = TextEditingController();
  final _stationFocus = FocusNode();

  /// Date du plein — par défaut aujourd'hui, modifiable (saisie a posteriori) et
  /// effaçable : un plein peut être saisi avec seulement le kilométrage.
  DateTime? _date = DateTime.now();

  /// Total calculé (volume × prix/L), affiché en lecture seule — jamais saisi.
  double? _total;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _odo = TextEditingController(text: (ex?.odometer ?? widget.lastOdometer)?.toString() ?? '');
    if (ex != null) {
      // Mode édition : on repart de toutes les valeurs de l'entrée.
      _date = ex.date?.toLocal();
      if (ex.volumeLiters != null) _volume.text = _fmtInput(ex.volumeLiters!);
      if (ex.pricePerLiter != null) _price.text = _fmtInput(ex.pricePerLiter!);
      if (ex.station != null) _station.text = ex.station!;
    }
    // Nouveau plein : champs vides — la station se choisit dans la liste
    // déroulante des stations déjà saisies (pas de préremplissage automatique).
    // Total initial (mode édition) — calcul direct, setState interdit ici.
    final v0 = _num(_volume.text);
    final p0 = _num(_price.text);
    if (v0 != null && p0 != null) _total = v0 * p0;
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
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 5),
      // Fin de journée : autorise aujourd'hui quelle que soit l'heure, et évite
      // qu'en édition une date stockée à midi ne dépasse `lastDate` avant midi.
      lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  void dispose() {
    for (final c in [_odo, _volume, _price, _station]) {
      c.dispose();
    }
    _stationFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final odo = int.tryParse(_odo.text.trim());
    // Au moins le kilométrage OU la date doit être renseigné.
    if (odo == null && _date == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Indique au moins le kilométrage ou la date.')));
      return;
    }
    setState(() => _saving = true);
    final volume = _num(_volume.text);
    final price = _num(_price.text);
    // Midi local pour éviter qu'un décalage de fuseau ne change le jour saisi.
    final d = _date;
    final date = d == null ? null : DateTime(d.year, d.month, d.day, 12);
    final ex = widget.existing;
    // En édition on conserve l'identité (id, véhicule, créateur) et les champs
    // non éditables ici (type de carburant, notes) ; sinon on génère un plein neuf.
    final entry = FuelEntry(
      id: ex?.id ?? UuidValue.generate(),
      vehicleId: ex?.vehicleId ?? UuidValue.parse(widget.vehicleId),
      createdByUserId: ex?.createdByUserId,
      date: date?.toUtc(),
      odometer: odo,
      volumeLiters: volume,
      pricePerLiter: price,
      totalCost: (volume != null && price != null) ? volume * price : null,
      fuelType: ex?.fuelType ?? widget.defaultFuelType,
      station: _station.text.trim().isEmpty ? null : _station.text.trim(),
      notes: ex?.notes,
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(fuelRepositoryProvider).save(entry);
    if (mounted) Navigator.of(context).pop();
  }

  /// Champ « Station ». Tant qu'aucune station n'a été saisie, simple champ
  /// texte. Dès qu'on en a, autocomplétion sur les stations déjà connues
  /// ([stations]) : la liste s'ouvre au focus (chevron) et se filtre à la
  /// frappe, tout en laissant taper une station inédite. Même contrôleur et même
  /// focus dans les deux cas pour que [_save] lise toujours la valeur.
  Widget _stationField(List<String> stations) {
    const decoration = InputDecoration(labelText: 'Station (optionnel)');
    if (stations.isEmpty) {
      return TextField(
        key: const Key('fuelStationField'),
        controller: _station,
        focusNode: _stationFocus,
        textCapitalization: TextCapitalization.words,
        decoration: decoration,
      );
    }
    return Autocomplete<String>(
      textEditingController: _station,
      focusNode: _stationFocus,
      // Le champ est en bas de la feuille : la liste s'ouvre vers le haut pour
      // ne pas passer sous le clavier.
      optionsViewOpenDirection: OptionsViewOpenDirection.up,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return stations; // focus champ vide → tout proposer
        final matches = stations.where((s) => s.toLowerCase().contains(q)).toList();
        // Après une sélection, la saisie == l'option : inutile de garder un menu
        // d'un seul item identique.
        if (matches.length == 1 && matches.first.toLowerCase() == q) {
          return const Iterable<String>.empty();
        }
        return matches;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          key: const Key('fuelStationField'),
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          decoration: decoration.copyWith(suffixIcon: const Icon(Icons.arrow_drop_down)),
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.existing != null;
    final stations = ref.watch(knownStationsProvider).value ?? const <String>[];
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(isEditing ? 'Modifier le plein' : 'Nouveau plein',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Date (optionnel)'),
            child: InkWell(
              key: const Key('fuelDateField'),
              onTap: _pickDate,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _date == null ? 'Aucune (km seul)' : formatDate(_date!),
                    style: _date == null
                        ? TextStyle(color: Theme.of(context).hintColor)
                        : null,
                  ),
                  if (_date == null)
                    const Icon(Icons.calendar_today_outlined, size: 18)
                  else
                    IconButton(
                      key: const Key('fuelDateClearButton'),
                      icon: const Icon(Icons.clear, size: 18),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Effacer la date',
                      onPressed: () => setState(() => _date = null),
                    ),
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
          _stationField(stations),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('saveFuelButton'),
            onPressed: _saving ? null : _save,
            child: Text(isEditing ? 'Enregistrer les modifications' : 'Enregistrer le plein'),
          ),
        ],
      ),
    );
  }
}
