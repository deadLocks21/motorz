import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/maintenance_catalog_item.dart';
import 'package:motorz/core/domain/model/maintenance_plan.dart';
import 'package:motorz/ui/pages/vehicle_detail/widgets/add_plan_sheet.widget.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';

/// Gestion de toutes les échéances d'un véhicule (récurrentes + à-venir).
/// Surface secondaire : on y édite les intervalles et on crée des rappels.
class PlanListPage extends ConsumerWidget {
  const PlanListPage({super.key, required this.vehicleId});
  final String vehicleId;

  String _describe(Plan p, Map<String, CatalogItem> catalogById) {
    if (p.catalogItemId != null) {
      final bits = <String>[];
      if (p.intervalKm != null) bits.add('${p.intervalKm} km');
      if (p.intervalMonths != null) bits.add('${p.intervalMonths} mois');
      return bits.isEmpty ? 'Récurrent (aucun intervalle)' : 'Tous les ${bits.join(' / ')}';
    }
    final bits = <String>[];
    if (p.dueOdometer != null) bits.add('avant ${p.dueOdometer} km');
    if (p.dueDate != null) bits.add('avant le ${p.dueDate}');
    return bits.isEmpty ? 'Échéance ponctuelle' : 'À faire ${bits.join(' · ')}';
  }

  String _name(Plan p, Map<String, CatalogItem> catalogById) {
    if (p.catalogItemId != null) {
      return catalogById[p.catalogItemId!.value]?.name ?? 'Poste';
    }
    return p.title ?? 'Échéance';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final plans = ref.watch(plansProvider(vehicleId)).value ?? const [];
    final catalog = ref.watch(catalogItemsProvider).value ?? const [];
    final catalogById = {for (final c in catalog) c.id.value: c};

    return Scaffold(
      appBar: AppBar(title: const Text('Échéances')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPlanSheet(context, ref, vehicleId: vehicleId),
        icon: const Icon(Icons.add_alarm),
        label: const Text('Rappel'),
      ),
      body: plans.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Aucune échéance. Les rappels récurrents apparaissent en saisissant une opération ; '
                  'touche « Rappel » pour une échéance à venir (CT, distribution…).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textMuted),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
              children: [
                for (final p in plans)
                  ListTile(
                    leading: Icon(
                      p.catalogItemId != null ? Icons.autorenew : Icons.event_outlined,
                      color: colors.accent,
                    ),
                    title: Text(_name(p, catalogById)),
                    subtitle: Text(_describe(p, catalogById)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        showPlanSheet(context, ref, vehicleId: vehicleId, existing: p, catalogById: catalogById),
                  ),
              ],
            ),
    );
  }
}
