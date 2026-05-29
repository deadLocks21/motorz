import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/application/services/due_status.service.dart';
import 'package:motorz/core/application/services/maintenance_derivation.service.dart';
import 'package:motorz/core/application/services/vehicle_stats.service.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/maintenance_operation_line.dart';
import 'package:motorz/core/domain/model/tire_pressure_entry.dart';
import 'package:motorz/core/domain/model/vehicle.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/ui/pages/vehicle_detail/widgets/add_fuel_sheet.widget.dart';
import 'package:motorz/ui/pages/vehicle_detail/widgets/add_operation_sheet.widget.dart';
import 'package:motorz/ui/pages/vehicle_detail/widgets/add_plan_sheet.widget.dart';
import 'package:motorz/ui/pages/vehicle_detail/widgets/add_tire_sheet.widget.dart';
import 'package:motorz/ui/pages/vehicle_detail/widgets/documents_tab.widget.dart';
import 'package:motorz/ui/pages/finances/finances.page.dart';
import 'package:motorz/ui/pages/maintenance_detail/maintenance_detail.page.dart';
import 'package:motorz/ui/pages/stats/stats.page.dart';
import 'package:motorz/ui/pages/vehicle_form/vehicle_form.page.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';
import 'package:motorz/ui/utils/format.dart';
import 'package:motorz/ui/widgets/entry_card.widget.dart';

class VehicleDetailPage extends ConsumerWidget {
  const VehicleDetailPage({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(vehicleByIdProvider(vehicleId));

    return vehicleAsync.when(
      // Chaque save réinvalide les providers store → reload. Sans ceci, `.when`
      // rejoue `loading` (défaut skipLoadingOnReload=false), ce qui détruit
      // _VehicleDetailView et recrée son TabController → l'onglet repart sur
      // « Vue d'ensemble ». On garde l'écran monté avec les données précédentes.
      // Chaque save réinvalide les providers store → reload. Sans ceci, `.when`
      // rejoue `loading` (défaut skipLoadingOnReload=false), ce qui détruit
      // _VehicleDetailView et recrée son TabController → l'onglet repart sur
      // « Vue d'ensemble ». On garde l'écran monté avec les données précédentes.
      skipLoadingOnReload: true,
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erreur : $e'))),
      data: (vehicle) {
        if (vehicle == null) {
          return const Scaffold(body: Center(child: Text('Véhicule introuvable')));
        }
        return _VehicleDetailView(vehicle: vehicle);
      },
    );
  }
}

class _VehicleDetailView extends ConsumerStatefulWidget {
  const _VehicleDetailView({required this.vehicle});
  final Vehicle vehicle;

  @override
  ConsumerState<_VehicleDetailView> createState() => _VehicleDetailViewState();
}

class _VehicleDetailViewState extends ConsumerState<_VehicleDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  static const _tabs = ['Vue d\'ensemble', 'Pleins', 'Entretien', 'À prévoir', 'Pneus', 'Docs'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String get _id => widget.vehicle.id.value;

  Future<void> _onFab() async {
    final odo = await ref.read(currentOdometerProvider(_id).future);
    if (!mounted) return;
    switch (_tab.index) {
      case 1:
        await showAddFuelSheet(context, ref,
            vehicleId: _id, lastOdometer: odo, defaultFuelType: widget.vehicle.fuelType);
      case 2:
        await showAddOperationSheet(context, ref, vehicleId: _id, lastOdometer: odo);
      case 3:
        await showPlanSheet(context, ref, vehicleId: _id);
      case 4:
        await showAddTireSheet(context, ref,
            vehicleId: _id, wheelCount: widget.vehicle.wheelCount, lastOdometer: odo);
      case 5:
        await uploadDocument(context, ref, ownerType: 'vehicle', ownerId: _id);
      default:
        await showAddFuelSheet(context, ref,
            vehicleId: _id, lastOdometer: odo, defaultFuelType: widget.vehicle.fuelType);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vehicle;
    final isOwner = ref.watch(currentSessionProvider)?.user.id == v.ownerUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(v.nickname),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      floatingActionButton: _tab.index == 0
          ? null
          : FloatingActionButton(
              key: const Key('detailFab'),
              onPressed: _onFab,
              child: const Icon(Icons.add),
            ),
      body: TabBarView(
        controller: _tab,
        children: [
          _OverviewTab(vehicle: v, isOwner: isOwner),
          _FuelTab(vehicleId: _id),
          _MaintenanceTab(vehicleId: _id),
          _TasksTab(vehicleId: _id),
          _TiresTab(vehicle: v),
          DocumentsTab(vehicleId: _id),
        ],
      ),
    );
  }
}

// ── Onglets ─────────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.vehicle, required this.isOwner});
  final Vehicle vehicle;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final id = vehicle.id.value;
    final odo = ref.watch(currentOdometerProvider(id)).value;
    final conso = ref.watch(averageConsumptionProvider(id)).value;
    final fuel = ref.watch(fuelEntriesProvider(id)).value ?? const [];
    final due = ref.watch(duePlansProvider(id)).value ?? const [];
    final upcoming = due.where((d) => d.due.hasTrigger).take(3).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: _StatTile(label: 'Km courant', value: formatKm(odo), colors: colors)),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(label: 'Conso moy.', value: formatConsumption(conso), colors: colors),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StatTile(
          label: 'Total carburant',
          value: formatEur(VehicleStatsService.totalFuelCost(fuel)),
          colors: colors,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => FinancesPage(vehicleId: id)),
                ),
                icon: const Icon(Icons.savings_outlined),
                label: const Text('Finances'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => StatsPage(vehicleId: id)),
                ),
                icon: const Icon(Icons.bar_chart),
                label: const Text('Stats'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Identité', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _kv('Type', vehicle.type.label),
        _kv('Description', vehicle.descriptor),
        if (vehicle.licensePlate != null) _kv('Plaque', vehicle.licensePlate!),
        if (vehicle.fuelType != null) _kv('Carburant', vehicle.fuelType!.label),
        const SizedBox(height: 24),
        Text('Prochaines échéances', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (upcoming.isEmpty)
          Text('Rien à prévoir.', style: TextStyle(color: colors.textMuted))
        else
          ...upcoming.map((d) => _DueRow(label: d.plan.title, due: d.due, colors: colors)),
        if (isOwner) ...[
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Code de partage'),
                content: Text(vehicle.shareCode ?? 'Disponible après synchronisation.'),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
              ),
            ),
            icon: const Icon(Icons.share_outlined),
            label: const Text('Partager ce véhicule'),
          ),
        ],
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(width: 120, child: Text(k)),
        Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
      ],
    ),
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.colors});
  final String label;
  final String value;
  final AppColors colors;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: colors.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: colors.textMuted, fontSize: 12)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _DueRow extends StatelessWidget {
  const _DueRow({required this.label, required this.due, required this.colors});
  final String label;
  final DueInfo due;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final color = switch (due.status) {
      DueStatus.overdue => colors.statusOverdue,
      DueStatus.dueSoon => colors.statusSoon,
      DueStatus.upcoming => colors.statusOk,
    };
    final bits = <String>[];
    if (due.remainingKm != null) {
      bits.add(due.remainingKm! <= 0 ? 'dépassé de ${-due.remainingKm!} km' : 'dans ~${due.remainingKm} km');
    }
    if (due.remainingDays != null) {
      bits.add(due.remainingDays! < 0 ? 'en retard de ${-due.remainingDays!} j' : 'dans ~${due.remainingDays} j');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(bits.join(' · '), style: TextStyle(color: colors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}


class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

/// Échéance concrète d'un plan en texte court (km et/ou délai). `null` si aucun
/// déclencheur (ponctuelle sans cible).
String? _dueDetail(DueInfo due) {
  final bits = <String>[];
  final km = due.remainingKm;
  if (km != null) {
    bits.add(km <= 0 ? 'dépassé de ${formatKm(-km)}' : 'dans ~${formatKm(km)}');
  }
  final d = due.remainingDays;
  if (d != null) {
    String human(int days) => days >= 60 ? '~${(days / 30).round()} mois' : '~$days j';
    bits.add(d < 0 ? 'en retard de ${human(-d)}' : 'dans ${human(d)}');
  }
  return bits.isEmpty ? null : bits.join(' · ');
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(message, textAlign: TextAlign.center, style: TextStyle(color: context.appColors.textMuted)),
    ),
  );
}

class _FuelTab extends ConsumerWidget {
  const _FuelTab({required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final fuelAsync = ref.watch(fuelEntriesProvider(vehicleId));
    return fuelAsync.when(
      skipLoadingOnReload: true, // save → reload : garde la liste, pas de flash spinner
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (entries) {
        if (entries.isEmpty) return const _EmptyTab('Aucun plein. Touche + pour en ajouter un.');
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final e = entries[i];
            // Tap → édition (la suppression vit dans la feuille d'édition).
            return EntryCard(
              icon: Icons.local_gas_station,
              iconColor: colors.accent,
              title: '${formatKm(e.odometer)} · ${formatLiters(e.volumeLiters)}',
              subtitle: '${formatDateOrNull(e.date)}${e.station != null ? ' · ${e.station}' : ''}',
              trailing: Text(formatEur(e.totalCost), style: const TextStyle(fontWeight: FontWeight.w700)),
              colors: colors,
              onTap: () => showAddFuelSheet(context, ref, vehicleId: vehicleId, existing: e),
            );
          },
        );
      },
    );
  }
}

class _MaintenanceTab extends ConsumerWidget {
  const _MaintenanceTab({required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final async = ref.watch(operationsProvider(vehicleId));
    final lines = ref.watch(linesForVehicleProvider(vehicleId)).value ?? const <OperationLine>[];
    final linesByOp = <String, List<OperationLine>>{};
    for (final l in lines) {
      (linesByOp[l.operationId.value] ??= []).add(l);
    }

    return async.when(
      skipLoadingOnReload: true, // save → reload : garde la liste, pas de flash spinner
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (operations) {
        if (operations.isEmpty) return const _EmptyTab('Aucune opération d\'entretien enregistrée.');
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: operations.length,
          itemBuilder: (_, i) {
            final op = operations[i];
            final opLines = linesByOp[op.id.value] ?? const [];
            final title = op.title ?? MaintenanceDerivationService.deriveTitle(opLines);
            return EntryCard(
              icon: Icons.build,
              iconColor: colors.accent,
              title: title,
              subtitle: '${formatDate(op.date)} · ${formatKm(op.odometer)}'
                  '${op.provider != null ? ' · ${op.provider}' : ''}',
              trailing: Text(
                formatEur(MaintenanceDerivationService.operationCost(opLines)),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              showChevron: true,
              colors: colors,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => MaintenanceOperationDetailPage(operation: op)),
              ),
            );
          },
        );
      },
    );
  }
}

class _TasksTab extends ConsumerWidget {
  const _TasksTab({required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final async = ref.watch(duePlansProvider(vehicleId));
    return async.when(
      skipLoadingOnReload: true, // save → reload : garde la liste, pas de flash spinner
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (items) {
        // « À réaliser » : en retard / bientôt dû, ou tâche sans déclencheur
        // (ponctuelle à faire). « Prochaines échéances » : à venir (informatif).
        // Même partition que `rankDueTitles` (suggestions du champ « Pièce ») :
        // garder les deux synchronisées.
        final aRealiser = items
            .where((d) =>
                d.due.status == DueStatus.overdue ||
                d.due.status == DueStatus.dueSoon ||
                !d.due.hasTrigger)
            .toList();
        final prochaines =
            items.where((d) => d.due.status == DueStatus.upcoming && d.due.hasTrigger).toList();

        Widget row(DuePlan d) {
          final (statusColor, statusLabel) = switch (d.due.status) {
            DueStatus.overdue => (colors.statusOverdue, 'En retard'),
            DueStatus.dueSoon => (colors.statusSoon, 'Bientôt'),
            DueStatus.upcoming => (colors.statusOk, d.due.hasTrigger ? 'À venir' : 'À faire'),
          };
          return EntryCard(
            icon: d.plan.isRecurring ? Icons.autorenew : Icons.task_alt,
            iconColor: statusColor,
            title: d.plan.title,
            subtitle: _dueDetail(d.due),
            trailing: _StatusPill(label: statusLabel, color: statusColor),
            colors: colors,
            onTap: () => showPlanSheet(context, ref, vehicleId: vehicleId, existing: d.plan),
          );
        }

        Widget sectionHeader(String label, int count) => Padding(
              padding: const EdgeInsets.fromLTRB(2, 16, 2, 6),
              child: Row(
                children: [
                  Text(label.toUpperCase(),
                      style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$count',
                        style: TextStyle(
                            color: colors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );

        if (items.isEmpty) {
          return const _EmptyTab(
            'Rien à prévoir. Touche + pour une échéance récurrente ou une tâche ponctuelle.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            if (aRealiser.isNotEmpty) ...[
              sectionHeader('À réaliser', aRealiser.length),
              ...aRealiser.map(row),
            ],
            if (prochaines.isNotEmpty) ...[
              sectionHeader('Prochaines échéances', prochaines.length),
              ...prochaines.map(row),
            ],
          ],
        );
      },
    );
  }
}

class _TiresTab extends ConsumerWidget {
  const _TiresTab({required this.vehicle});
  final Vehicle vehicle;

  String get vehicleId => vehicle.id.value;
  int get wheelCount => vehicle.wheelCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final targets = ref.watch(targetPressuresProvider(vehicleId)).value ?? const [];
    final entriesAsync = ref.watch(tirePressuresProvider(vehicleId));
    final targetById = {for (final t in targets) t.id.value: t};
    final lossPerMonth = vehicle.tireMonthlyLoss;

    // Rappel non-éditable des cibles : l'édition vit dans la fiche
    // (« Modifier le véhicule »), pas dans le journal des relevés.
    void openVehicleForm() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => VehicleFormPage(existing: vehicle)),
        );

    return entriesAsync.when(
      skipLoadingOnReload: true, // save → reload : garde la liste, pas de flash spinner
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (entries) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (targets.isEmpty)
              OutlinedButton.icon(
                onPressed: openVehicleForm,
                icon: const Icon(Icons.adjust, size: 18),
                label: const Text('Définir une pression cible'),
              )
            else ...[
              Text('Pressions cibles', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              ...targets.map((t) => EntryCard(
                    icon: Icons.adjust,
                    iconColor: colors.accent,
                    title: t.label,
                    subtitle: 'AV ${formatBar(t.front)} · AR ${formatBar(t.rear)}',
                    showChevron: true,
                    colors: colors,
                    onTap: openVehicleForm,
                  )),
            ],
            const SizedBox(height: 16),
            Text('Relevés', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            if (entries.isEmpty)
              Text('Aucun relevé. Touche + pour en ajouter.', style: TextStyle(color: colors.textMuted))
            else
              ...entries.asMap().entries.map((me) {
                final i = me.key;
                final e = me.value;
                // Le relevé est un « remplissage » s'il porte la cible gonflée.
                final fillTarget = targetById[e.targetPressureId?.value];
                // Dernier remplissage antérieur (relevés triés du + récent au +
                // ancien) : sert de référence « pression du précédent remplissage ».
                TirePressureEntry? prevFill;
                for (var j = i + 1; j < entries.length; j++) {
                  if (entries[j].targetPressureId != null) {
                    prevFill = entries[j];
                    break;
                  }
                }
                // Roue la plus gonflée du relevé : référence « interne ».
                final maxBar = e.pressures.values.isEmpty
                    ? null
                    : e.pressures.values.reduce((a, b) => a > b ? a : b);
                // Perte normale attendue depuis le dernier remplissage (selon le
                // temps écoulé et le taux mensuel du véhicule).
                final months = prevFill == null
                    ? null
                    : e.date.difference(prevFill.date).inDays / 30.0;
                return EntryCard(
                  icon: Icons.tire_repair,
                  iconColor: colors.accent,
                  title: '${formatDate(e.date)} · ${formatKm(e.odometer)}',
                  subtitle: fillTarget != null ? 'Gonflé à « ${fillTarget.label} »' : null,
                  subtitleWidget: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: e.pressures.entries.map((p) {
                      // Problème (rouge) si la roue est sous la plus gonflée du
                      // relevé OU sous la pression attendue au dernier
                      // remplissage (perte plus rapide que la normale). Sans marge.
                      final lowVsMax = maxBar != null && p.value < maxBar;
                      final prevBar = prevFill?.pressures[p.key];
                      final expected =
                          prevBar != null && months != null ? prevBar - lossPerMonth * months : null;
                      final lowVsFill = expected != null && p.value < expected;
                      final low = lowVsMax || lowVsFill;
                      final color = low ? colors.statusOverdue : colors.textPrimary;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (low ? colors.statusOverdue : colors.outline)
                              .withValues(alpha: low ? 0.12 : 0.35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${p.key} ${formatBar(p.value)}',
                            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                  ),
                  colors: colors,
                  onTap: () => showAddTireSheet(context, ref,
                      vehicleId: vehicleId, wheelCount: wheelCount, existing: e),
                );
              }),
          ],
        );
      },
    );
  }
}

