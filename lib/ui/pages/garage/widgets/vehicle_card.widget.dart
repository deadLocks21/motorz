import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/vehicle.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/router/app_router.dart';
import 'package:motorz/ui/theme/app_colors.dart';
import 'package:motorz/ui/utils/format.dart';

class VehicleCard extends ConsumerWidget {
  const VehicleCard({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final id = vehicle.id.value;
    final odo = ref.watch(currentOdometerProvider(id)).value;
    final due = ref.watch(dueTasksProvider(id)).value ?? const [];
    final overdue = due.where((d) => d.due.status == DueStatus.overdue).length;
    final soon = due.where((d) => d.due.status == DueStatus.dueSoon).length;

    return Card(
      child: InkWell(
        key: Key('vehicleCard_$id'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(AppRoutes.vehicle(id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  vehicle.type.wheelCount == 2 ? Icons.two_wheeler : Icons.directions_car,
                  color: colors.onAccentSoft,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.nickname,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${vehicle.descriptor} · ${formatKm(odo)}',
                      style: TextStyle(color: colors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (overdue > 0)
                _Pill(label: '$overdue en retard', color: colors.statusOverdue)
              else if (soon > 0)
                _Pill(label: '$soon bientôt', color: colors.statusSoon)
              else
                Icon(Icons.chevron_right, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
