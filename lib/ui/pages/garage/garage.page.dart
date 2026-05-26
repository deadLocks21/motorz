import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/ui/pages/dashboard/dashboard.page.dart';
import 'package:motorz/ui/pages/garage/widgets/vehicle_card.widget.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/router/app_router.dart';
import 'package:motorz/ui/theme/app_colors.dart';
import 'package:motorz/ui/widgets/motorz_wordmark.widget.dart';

/// Accueil/garage : mes véhicules + ceux partagés avec moi, badges d'échéance.
class GaragePage extends ConsumerWidget {
  const GaragePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final session = ref.watch(currentSessionProvider);
    final online = ref.watch(connectivityStatusProvider).value ?? true;
    final myId = session?.user.id.value;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const MotorzWordmark(fontSize: 24),
        actions: [
          IconButton(
            tooltip: 'Tableau de bord',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DashboardPage())),
          ),
          IconButton(
            tooltip: 'Rejoindre un véhicule',
            icon: const Icon(Icons.group_add_outlined),
            onPressed: () => _showJoinDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addVehicleFab'),
        onPressed: () => context.push(AppRoutes.newVehicle),
        icon: const Icon(Icons.add),
        label: const Text('Véhicule'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(syncServiceProvider).syncNow(),
        child: vehiclesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur : $e')),
          data: (vehicles) {
            final owned = vehicles.where((v) => v.ownerUserId.value == myId).toList();
            final shared = vehicles.where((v) => v.ownerUserId.value != myId).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                if (!online)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _OfflineBanner(color: colors.textMuted),
                  ),
                if (vehicles.isEmpty)
                  _EmptyGarage(colors: colors)
                else ...[
                  _SectionHeader('Mes véhicules', colors: colors),
                  if (owned.isEmpty)
                    _MutedLine('Aucun véhicule. Ajoute ton premier véhicule.', colors: colors),
                  ...owned.map((v) => _spaced(VehicleCard(vehicle: v))),
                  if (shared.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionHeader('Partagés avec moi', colors: colors),
                    ...shared.map((v) => _spaced(VehicleCard(vehicle: v))),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _spaced(Widget child) =>
      Padding(padding: const EdgeInsets.only(bottom: 10), child: child);

  Future<void> _showJoinDialog(BuildContext context, WidgetRef ref) async {
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, {required this.colors});
  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 0, 10),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        color: colors.textMuted,
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _MutedLine extends StatelessWidget {
  const _MutedLine(this.text, {required this.colors});
  final String text;
  final AppColors colors;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(4), child: Text(text, style: TextStyle(color: colors.textMuted)));
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.cloud_off, size: 16, color: color),
      const SizedBox(width: 6),
      Text('Hors-ligne — synchro au retour du réseau', style: TextStyle(color: color, fontSize: 12)),
    ],
  );
}

class _EmptyGarage extends StatelessWidget {
  const _EmptyGarage({required this.colors});
  final AppColors colors;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.garage_outlined, size: 64, color: colors.textMuted),
          const SizedBox(height: 16),
          Text('Ton garage est vide', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Ajoute un véhicule pour suivre pleins, entretien et échéances.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}
