import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/vehicle.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/ui/pages/vehicle_form/vehicle_form.page.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';

/// Section « Véhicules » des réglages : la gestion des véhicules vit ici.
/// Reprend l'ajout et la jonction par code (autrefois sur l'écran garage) et y
/// ajoute modification, partage et suppression par véhicule. Les actions
/// réservées au propriétaire (partage, suppression) reprennent celles du menu
/// de l'écran détail — garder les deux cohérentes.
class VehiclesSection extends ConsumerWidget {
  const VehiclesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final myId = ref.watch(currentSessionProvider)?.user.id.value;
    final vehiclesAsync = ref.watch(vehiclesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Véhicules', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        vehiclesAsync.when(
          skipLoadingOnReload: true, // save/sync → reload : pas de flash spinner
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) =>
              Text('Erreur : $e', style: TextStyle(color: colors.textMuted)),
          data: (vehicles) => Column(
            children: [
              if (vehicles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Aucun véhicule pour le moment.',
                        style: TextStyle(color: colors.textMuted)),
                  ),
                )
              else
                ...vehicles.map((v) => _VehicleTile(
                      vehicle: v,
                      isOwner: v.ownerUserId.value == myId,
                    )),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('addVehicleButton'),
                      onPressed: () => _addVehicle(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _join(context, ref),
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('Rejoindre'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addVehicle(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const VehicleFormPage()));

  /// Rejoindre un véhicule partagé via son code permanent (REST direct, puis
  /// synchro pour le faire descendre en local). Calque de l'ancien dialogue du
  /// garage.
  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejoindre un véhicule'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Code du véhicule'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Rejoindre'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.isEmpty || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(vehicleRemoteApiProvider).join(code);
      await ref.read(syncServiceProvider).syncNow();
      messenger.showSnackBar(
        const SnackBar(content: Text('Véhicule ajouté à « Partagés avec moi ».')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Code invalide ou serveur indisponible.')),
      );
    }
  }
}

class _VehicleTile extends ConsumerWidget {
  const _VehicleTile({required this.vehicle, required this.isOwner});

  final Vehicle vehicle;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final error = Theme.of(context).colorScheme.error;
    // Au-delà de ce viewport (tablette/desktop), les boutons d'action portent
    // leur libellé ; en dessous (téléphone), on ne garde que les icônes pour que
    // les actions tiennent sur la même ligne que l'identité du véhicule.
    final showLabels = MediaQuery.sizeOf(context).width >= 600;

    Widget action(IconData icon, String label, VoidCallback onPressed, {Color? color}) {
      if (showLabels) {
        return TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: color == null ? null : TextButton.styleFrom(foregroundColor: color),
        );
      }
      return IconButton(
        tooltip: label,
        onPressed: onPressed,
        color: color,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 20),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: colors.accentSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                vehicle.type.wheelCount == 2 ? Icons.two_wheeler : Icons.directions_car,
                color: colors.onAccentSoft,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(vehicle.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    isOwner ? vehicle.descriptor : 'Partagé · ${vehicle.descriptor}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            // Partage et suppression sont réservés au propriétaire (le backend
            // les refuse aux invités d'un véhicule partagé).
            action(Icons.edit_outlined, 'Modifier', () => _edit(context)),
            if (isOwner) action(Icons.share_outlined, 'Partager', () => _share(context)),
            if (isOwner)
              action(Icons.delete_outline, 'Supprimer', () => _delete(context, ref), color: error),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VehicleFormPage(existing: vehicle)),
      );

  Future<void> _share(BuildContext context) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Code de partage'),
          content: Text(
            vehicle.shareCode == null
                ? 'Le code sera disponible après la prochaine synchronisation.'
                : 'Communique ce code à la personne, elle le saisit depuis « Rejoindre un véhicule » :\n\n${vehicle.shareCode}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le véhicule ?'),
        content: Text(
          '« ${vehicle.nickname} » et tout son historique seront supprimés. '
          'Cette action est définitive.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(vehicleRepositoryProvider).delete(vehicle);
    }
  }
}
