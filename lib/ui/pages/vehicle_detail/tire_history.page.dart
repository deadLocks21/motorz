import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/application/services/tire.service.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/tire.dart';
import 'package:motorz/core/domain/model/tire_mount.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';
import 'package:motorz/ui/utils/format.dart';

/// Historique des changements de pneus d'un véhicule, dérivé du journal de
/// montages. Filtre **Tous** → timeline des changements (groupés par km/date) ;
/// une **position** → intervalles successifs de cette roue.
class TireHistoryPage extends ConsumerStatefulWidget {
  const TireHistoryPage({super.key, required this.vehicleId, required this.wheelCount});

  final String vehicleId;
  final int wheelCount;

  @override
  ConsumerState<TireHistoryPage> createState() => _TireHistoryPageState();
}

class _TireHistoryPageState extends ConsumerState<TireHistoryPage> {
  String? _position; // null = Tous

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tires = ref.watch(tiresProvider(widget.vehicleId)).value ?? const <Tire>[];
    final mounts = ref.watch(tireMountsProvider(widget.vehicleId)).value ?? const <TireMount>[];
    final currentOdo = ref.watch(currentOdometerProvider(widget.vehicleId)).value;

    // Positions présentes dans l'historique, dans l'ordre canonique (+ secours).
    final present = <String>{
      for (final m in mounts)
        if (m.deletedAt == null) m.position,
    };
    final positions =
        [...wheelPositions(widget.wheelCount), spareWheelPosition].where(present.contains).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Historique des pneus')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (positions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Tous'),
                    selected: _position == null,
                    onSelected: (_) => setState(() => _position = null),
                  ),
                  for (final p in positions)
                    ChoiceChip(
                      label: Text(p == spareWheelPosition ? 'Secours' : p),
                      selected: _position == p,
                      onSelected: (_) => setState(() => _position = p),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _position == null
                ? _Timeline(tires: tires, mounts: mounts, colors: colors)
                : _PositionHistory(
                    position: _position!,
                    tires: tires,
                    mounts: mounts,
                    currentOdometer: currentOdo,
                    colors: colors,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Timeline véhicule : un changement par carte (km/date), avec les pneus montés
/// et déposés à ce moment (la position est nommée sur chaque ligne).
class _Timeline extends StatelessWidget {
  const _Timeline({required this.tires, required this.mounts, required this.colors});

  final List<Tire> tires;
  final List<TireMount> mounts;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final changes = TireService.vehicleChanges(tires, mounts);
    if (changes.isEmpty) {
      return Center(
        child: Text('Aucun changement enregistré.', style: TextStyle(color: colors.textMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: changes.length,
      itemBuilder: (context, i) {
        final c = changes[i];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 5),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${formatKm(c.odometer)}${_dateSuffix(c.date)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 6),
                for (final e in c.mounted) _line(Icons.arrow_upward, colors.accent, 'Monté', e),
                for (final e in c.dismounted)
                  _line(Icons.arrow_downward, colors.textMuted, 'Déposé', e),
              ],
            ),
          ),
        );
      },
    );
  }

  String _dateSuffix(String? date) {
    if (date == null) return '';
    final d = DateTime.tryParse(date);
    return d == null ? '' : ' · ${formatDate(d)}';
  }

  Widget _line(IconData icon, Color color, String verb, TireChangeEntry e) {
    final where = e.position == spareWheelPosition ? 'Secours' : positionLabel(e.position);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$verb · ', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              TextSpan(text: e.tire.descriptor),
              TextSpan(text: '  ·  $where', style: TextStyle(color: colors.textMuted)),
            ])),
          ),
        ],
      ),
    );
  }
}

/// Historique d'une position : les pneus qui s'y sont succédé (du plus récent),
/// avec la plage de km et les km roulés (sauf secours).
class _PositionHistory extends StatelessWidget {
  const _PositionHistory({
    required this.position,
    required this.tires,
    required this.mounts,
    required this.currentOdometer,
    required this.colors,
  });

  final String position;
  final List<Tire> tires;
  final List<TireMount> mounts;
  final int? currentOdometer;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final tireById = {for (final t in tires) t.id.value: t};
    final intervals = mounts
        .where((m) => m.deletedAt == null && m.position == position)
        .toList()
      ..sort((a, b) => b.mountedOdometer.compareTo(a.mountedOdometer));
    if (intervals.isEmpty) {
      return Center(
        child: Text('Aucun montage à cette position.', style: TextStyle(color: colors.textMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: intervals.length,
      itemBuilder: (context, i) {
        final m = intervals[i];
        final tire = tireById[m.tireId.value];
        final end = m.dismountedOdometer;
        final endLabel = end != null ? formatKm(end) : 'en cours';
        final spanEnd = end ?? currentOdometer;
        final span =
            (position != spareWheelPosition && spanEnd != null) ? spanEnd - m.mountedOdometer : null;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 5),
          child: ListTile(
            leading: Icon(Icons.trip_origin, color: m.isOpen ? colors.accent : colors.textMuted),
            title: Text(tire?.descriptor ?? 'Pneu',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${formatKm(m.mountedOdometer)} → $endLabel'
                '${span != null && span > 0 ? '  ·  ${formatKm(span)} roulés' : ''}'),
          ),
        );
      },
    );
  }
}
