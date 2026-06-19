import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/application/services/tire.service.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/tire.dart';
import 'package:motorz/core/domain/model/tire_mount.dart';
import 'package:motorz/ui/pages/vehicle_detail/tire_detail.page.dart';
import 'package:motorz/ui/pages/vehicle_detail/widgets/mount_tire_sheet.widget.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';
import 'package:motorz/ui/utils/format.dart';
import 'package:motorz/ui/widgets/section_header.widget.dart';

/// Page récapitulative d'une position de roue : pneu actuellement monté (résumé,
/// vers son détail) ou « Vide », action monter/changer-démonter, et historique
/// des pneus qui s'y sont succédé.
class PositionDetailPage extends ConsumerWidget {
  const PositionDetailPage({super.key, required this.vehicleId, required this.position});

  final String vehicleId;
  final String position;

  void _openTire(BuildContext context, Tire tire) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TireDetailPage(tire: tire, vehicleId: vehicleId)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final tires = ref.watch(tiresProvider(vehicleId)).value ?? const <Tire>[];
    final mounts = ref.watch(tireMountsProvider(vehicleId)).value ?? const <TireMount>[];
    final currentOdo = ref.watch(currentOdometerProvider(vehicleId)).value;
    final tireById = {for (final t in tires) t.id.value: t};
    final isSpare = position == spareWheelPosition;

    final open = TireService.mountAtPosition(position, mounts);
    final mountedTire = open != null ? tireById[open.tireId.value] : null;

    final intervals = mounts
        .where((m) => m.deletedAt == null && m.position == position)
        .toList()
      ..sort((a, b) => b.mountedOdometer.compareTo(a.mountedOdometer));

    return Scaffold(
      appBar: AppBar(title: Text(isSpare ? 'Roue de secours' : positionLabel(position))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: mountedTire == null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.circle_outlined, color: colors.textMuted),
                        const SizedBox(width: 12),
                        Text('Aucun pneu monté ici',
                            style: TextStyle(color: colors.textMuted, fontSize: 15)),
                      ],
                    ),
                  )
                : ListTile(
                    leading: Icon(Icons.trip_origin, color: colors.accent),
                    title: Text(mountedTire.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      if (mountedTire.size != null && mountedTire.size!.isNotEmpty) mountedTire.size!,
                      if (!isSpare &&
                          TireService.kmRolled(mountedTire.id.value, mounts, currentOdo) != null)
                        '${formatKm(TireService.kmRolled(mountedTire.id.value, mounts, currentOdo))} roulés',
                    ].join('  ·  ')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openTire(context, mountedTire),
                  ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('positionActionButton'),
            onPressed: () => showMountTireSheet(context, ref,
                vehicleId: vehicleId, position: position, lastOdometer: currentOdo),
            icon: Icon(mountedTire != null ? Icons.swap_horiz : Icons.add),
            label: Text(mountedTire != null ? 'Changer / démonter' : 'Monter un pneu'),
          ),
          const SizedBox(height: 20),
          const SectionHeader('Historique'),
          if (intervals.isEmpty)
            Text('Aucun montage à cette position.', style: TextStyle(color: colors.textMuted))
          else
            ...intervals.map((m) {
              final tire = tireById[m.tireId.value];
              final end = m.dismountedOdometer;
              final endLabel = end != null ? formatKm(end) : 'en cours';
              final spanEnd = end ?? currentOdo;
              final span =
                  (!isSpare && spanEnd != null) ? spanEnd - m.mountedOdometer : null;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  leading:
                      Icon(Icons.trip_origin, color: m.isOpen ? colors.accent : colors.textMuted),
                  title: Text(tire?.displayName ?? 'Pneu',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${formatKm(m.mountedOdometer)} → $endLabel'
                      '${span != null && span > 0 ? '  ·  ${formatKm(span)} roulés' : ''}'),
                ),
              );
            }),
        ],
      ),
    );
  }
}
