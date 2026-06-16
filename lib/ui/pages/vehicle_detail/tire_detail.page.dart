import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/application/services/tire.service.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/tire.dart';
import 'package:motorz/core/domain/model/tire_mount.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/ui/pages/vehicle_detail/widgets/tire_inventory_sheet.widget.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';
import 'package:motorz/ui/utils/format.dart';
import 'package:motorz/ui/widgets/section_header.widget.dart';

String _fmtYmd(String? ymd) {
  if (ymd == null) return '—';
  final d = DateTime.tryParse(ymd);
  return d != null ? formatDate(d) : ymd;
}

/// Page récapitulative d'un pneu : statut (monté / en stock / au rebut), km
/// roulés, infos d'inventaire et historique de ses montages. La modification
/// (et mise au rebut / suppression) passe par l'icône ✏️ → feuille d'édition.
class TireDetailPage extends ConsumerStatefulWidget {
  const TireDetailPage({super.key, required this.tire, required this.vehicleId});

  final Tire tire;
  final String vehicleId;

  @override
  ConsumerState<TireDetailPage> createState() => _TireDetailPageState();
}

class _TireDetailPageState extends ConsumerState<TireDetailPage> {
  late Tire _tire;

  @override
  void initState() {
    super.initState();
    _tire = widget.tire;
  }

  Future<void> _edit() async {
    await showTireSheet(context, ref, vehicleId: widget.vehicleId, existing: _tire);
    final updated = await ref.read(tireRepositoryProvider).getById(_tire.id.value);
    if (!mounted) return;
    if (updated == null) {
      Navigator.of(context).pop(); // supprimé depuis la feuille
    } else {
      setState(() => _tire = updated);
    }
  }

  Widget _kv(String k, String v, AppColors colors) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(k, style: TextStyle(color: colors.textMuted))),
            Expanded(child: Text(v)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final mounts = ref.watch(tireMountsProvider(widget.vehicleId)).value ?? const <TireMount>[];
    final currentOdo = ref.watch(currentOdometerProvider(widget.vehicleId)).value;
    final t = _tire;
    final open = TireService.currentMountFor(t.id.value, mounts);
    final km = TireService.kmRolled(t.id.value, mounts, currentOdo);

    final String status;
    final IconData statusIcon;
    if (t.isDisposed) {
      status = 'Au rebut le ${_fmtYmd(t.disposedDate)}';
      statusIcon = Icons.delete_sweep_outlined;
    } else if (open != null) {
      status =
          'Monté · ${open.position == spareWheelPosition ? 'Secours' : positionLabel(open.position)}';
      statusIcon = Icons.trip_origin;
    } else {
      status = 'En stock';
      statusIcon = Icons.inventory_2_outlined;
    }

    final jante = [
      if (t.rimMaterial != null) t.rimMaterial!.label,
      if (t.rimSpec != null && t.rimSpec!.isNotEmpty) t.rimSpec!,
    ].join(' · ');
    final achat = [
      if (t.purchaseDate != null) _fmtYmd(t.purchaseDate),
      if (t.purchasePrice != null) formatEur(t.purchasePrice),
    ].join(' · ');

    final intervals = mounts
        .where((m) => m.deletedAt == null && m.tireId.value == t.id.value)
        .toList()
      ..sort((a, b) => b.mountedOdometer.compareTo(a.mountedOdometer));

    return Scaffold(
      appBar: AppBar(
        title: Text(t.descriptor),
        actions: [
          IconButton(
            key: const Key('tireEditButton'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier',
            onPressed: _edit,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(statusIcon, color: t.isDisposed ? colors.textMuted : colors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(status,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      if (km != null)
                        Text('${formatKm(km)} roulés', style: TextStyle(color: colors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _kv('Taille', t.size ?? '—', colors),
                  _kv('Jante', jante.isEmpty ? '—' : jante, colors),
                  _kv('Saison', t.season?.label ?? '—', colors),
                  _kv('État', t.condition.label, colors),
                  _kv('Achat', achat.isEmpty ? '—' : achat, colors),
                  if (t.notes != null && t.notes!.isNotEmpty) _kv('Notes', t.notes!, colors),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader('Historique'),
          if (intervals.isEmpty)
            Text('Jamais monté.', style: TextStyle(color: colors.textMuted))
          else
            ...intervals.map((m) {
              final where =
                  m.position == spareWheelPosition ? 'Secours' : positionLabel(m.position);
              final end = m.dismountedOdometer;
              final endLabel = end != null ? formatKm(end) : 'en cours';
              final spanEnd = end ?? currentOdo;
              final span = (m.position != spareWheelPosition && spanEnd != null)
                  ? spanEnd - m.mountedOdometer
                  : null;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  leading: Icon(Icons.trip_origin, color: m.isOpen ? colors.accent : colors.textMuted),
                  title: Text(where, style: const TextStyle(fontWeight: FontWeight.w700)),
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
