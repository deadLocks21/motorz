import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/model/vehicle.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/ui/pages/vehicle_detail/widgets/add_target_pressure_sheet.widget.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';
import 'package:motorz/ui/utils/format.dart';
import 'package:motorz/ui/widgets/entry_card.widget.dart';
import 'package:motorz/ui/widgets/section_header.widget.dart';

/// Création (ou édition) d'un véhicule. La saisie est locale-first : le
/// véhicule apparaît immédiatement, le code de partage arrive à la synchro.
class VehicleFormPage extends ConsumerStatefulWidget {
  const VehicleFormPage({super.key, this.existing});

  final Vehicle? existing;

  @override
  ConsumerState<VehicleFormPage> createState() => _VehicleFormPageState();
}

class _VehicleFormPageState extends ConsumerState<VehicleFormPage>
    with SingleTickerProviderStateMixin {
  TabController? _tab;
  late final TextEditingController _nickname;
  late final TextEditingController _make;
  late final TextEditingController _model;
  late final TextEditingController _year;
  late final TextEditingController _trim;
  late final TextEditingController _plate;
  late final TextEditingController _vin;
  late final TextEditingController _engineCc;
  late final TextEditingController _powerHp;
  late final TextEditingController _color;
  late VehicleType _type;
  FuelType? _fuelType;
  DateTime? _firstReg;
  late double _lossRate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.existing;
    _nickname = TextEditingController(text: v?.nickname ?? '');
    _make = TextEditingController(text: v?.make ?? '');
    _model = TextEditingController(text: v?.model ?? '');
    _year = TextEditingController(text: v?.year?.toString() ?? '');
    _trim = TextEditingController(text: v?.trim ?? '');
    _plate = TextEditingController(text: v?.licensePlate ?? '');
    _vin = TextEditingController(text: v?.vin ?? '');
    _engineCc = TextEditingController(text: v?.engineCc?.toString() ?? '');
    _powerHp = TextEditingController(text: v?.powerHp?.toString() ?? '');
    _color = TextEditingController(text: v?.color ?? '');
    _type = v?.type ?? VehicleType.voiture;
    _fuelType = v?.fuelType;
    _firstReg = v?.firstRegistrationDate != null ? DateTime.tryParse(v!.firstRegistrationDate!) : null;
    _lossRate = v?.tireMonthlyLossBar ?? Vehicle.defaultTireMonthlyLossBar;
    // Onglets uniquement en édition : en création, les cibles n'ont pas encore
    // de véhicule auquel se rattacher.
    if (v != null) {
      _tab = TabController(length: 2, vsync: this)
        ..addListener(() => setState(() {})); // affiche le FAB seulement sur Pneus
    }
  }

  @override
  void dispose() {
    _tab?.dispose();
    for (final c in [_nickname, _make, _model, _year, _trim, _plate, _vin, _engineCc, _powerHp, _color]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final nickname = _nickname.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Donne un surnom au véhicule.')));
      return;
    }
    final session = ref.read(currentSessionProvider);
    if (session == null) return;

    setState(() => _saving = true);
    final base = widget.existing;
    final vehicle = Vehicle(
      id: base?.id ?? UuidValue.generate(),
      ownerUserId: base?.ownerUserId ?? session.user.id,
      shareCode: base?.shareCode,
      type: _type,
      nickname: nickname,
      make: _emptyToNull(_make.text),
      model: _emptyToNull(_model.text),
      year: int.tryParse(_year.text),
      trim: _emptyToNull(_trim.text),
      vin: _emptyToNull(_vin.text),
      licensePlate: _emptyToNull(_plate.text),
      fuelType: _fuelType,
      engineCc: int.tryParse(_engineCc.text),
      powerHp: int.tryParse(_powerHp.text),
      color: _emptyToNull(_color.text),
      firstRegistrationDate: _firstReg?.toIso8601String().substring(0, 10),
      photoMediaId: base?.photoMediaId,
      tireMonthlyLossBar: _lossRate,
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(vehicleRepositoryProvider).save(vehicle);
    if (mounted) context.pop();
  }

  String? _emptyToNull(String s) => s.trim().isEmpty ? null : s.trim();

  /// Taux de perte : enregistrement immédiat (comme les cibles), indépendant du
  /// bouton « Enregistrer » de l'identité.
  Future<void> _setLossRate(double v) async {
    final clamped = double.parse(v.clamp(0.0, 1.0).toStringAsFixed(2));
    setState(() => _lossRate = clamped);
    final base = widget.existing;
    if (base != null) {
      await ref
          .read(vehicleRepositoryProvider)
          .save(base.copyWith(tireMonthlyLossBar: clamped, updatedAt: DateTime.now().toUtc()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Modifier le véhicule' : 'Nouveau véhicule'),
        bottom: _tab == null
            ? null
            : TabBar(
                controller: _tab,
                tabs: const [Tab(text: 'Identité'), Tab(text: 'Pneus')],
              ),
      ),
      floatingActionButton: _tab != null && _tab!.index == 1
          ? FloatingActionButton(
              onPressed: () => showAddTargetPressureSheet(context, ref,
                  vehicleId: widget.existing!.id.value),
              child: const Icon(Icons.add),
            )
          : null,
      body: _tab == null
          ? _identityTab(editing)
          : TabBarView(
              controller: _tab,
              children: [
                _identityTab(editing),
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    const SectionHeader('Perte de pression normale'),
                    Text(
                      'Perte attendue avec le temps. Une roue qui se dégonfle plus '
                      'vite est signalée en rouge sur les relevés.',
                      style: TextStyle(color: context.appColors.textMuted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 8),
                    _LossRateStepper(
                      value: _lossRate,
                      onChanged: _setLossRate,
                      colors: context.appColors,
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    _TargetPressuresSection(vehicleId: widget.existing!.id.value),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _identityTab(bool editing) {
    return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('nicknameField'),
            controller: _nickname,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Surnom *', hintText: 'La 308'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<VehicleType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: VehicleType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? VehicleType.voiture),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _make,
                  decoration: const InputDecoration(labelText: 'Marque'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _model,
                  decoration: const InputDecoration(labelText: 'Modèle'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _year,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Année'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _plate,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Plaque'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<FuelType?>(
            initialValue: _fuelType,
            decoration: const InputDecoration(labelText: 'Carburant'),
            items: [
              const DropdownMenuItem(value: null, child: Text('—')),
              ...FuelType.values.map((f) => DropdownMenuItem(value: f, child: Text(f.label))),
            ],
            onChanged: (v) => setState(() => _fuelType = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _engineCc,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Cylindrée', suffixText: 'cm³'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _powerHp,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Puissance', suffixText: 'ch'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _trim,
                  decoration: const InputDecoration(labelText: 'Finition'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _color,
                  decoration: const InputDecoration(labelText: 'Couleur'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _vin,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'VIN (n° de série)'),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _firstReg ?? now,
                firstDate: DateTime(1950),
                lastDate: now,
              );
              if (picked != null) setState(() => _firstReg = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: '1ʳᵉ mise en circulation'),
              child: Text(
                _firstReg == null
                    ? 'Choisir une date'
                    : '${_firstReg!.day}/${_firstReg!.month}/${_firstReg!.year}',
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('saveVehicleButton'),
            onPressed: _saving ? null : _save,
            child: Text(editing ? 'Enregistrer' : 'Ajouter au garage'),
          ),
        ],
      );
  }
}

/// Réglage du taux de perte mensuel par pas de 0,05 bar.
class _LossRateStepper extends StatelessWidget {
  const _LossRateStepper({required this.value, required this.onChanged, required this.colors});

  final double value;
  final ValueChanged<double> onChanged;
  final AppColors colors;

  static const _step = 0.05;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('${formatBar(value)} / mois',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: value <= 0 ? null : () => onChanged(value - _step),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: value >= 1 ? null : () => onChanged(value + _step),
          ),
        ],
      ),
    );
  }
}

/// Sous-éditeur des pressions cibles, à enregistrement immédiat (chaque ajout /
/// modification / suppression est persisté tout de suite, indépendamment du
/// bouton « Enregistrer » de l'identité). Ces valeurs ne se saisissent qu'une
/// fois : leur place est ici, dans la fiche, plutôt que mêlées au journal des
/// relevés (onglet Pneus du détail).
class _TargetPressuresSection extends ConsumerWidget {
  const _TargetPressuresSection({required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final targets = ref.watch(targetPressuresProvider(vehicleId)).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Pressions cibles'),
        if (targets.isEmpty)
          Text('Aucune cible. Ajoute « à vide », « en charge »…',
              style: TextStyle(color: colors.textMuted))
        else
          ...targets.map((t) => EntryCard(
                icon: Icons.adjust,
                iconColor: colors.accent,
                title: t.label,
                subtitle: 'AV ${formatBar(t.front)} · AR ${formatBar(t.rear)}',
                colors: colors,
                onTap: () =>
                    showAddTargetPressureSheet(context, ref, vehicleId: vehicleId, existing: t),
              )),
      ],
    );
  }
}

