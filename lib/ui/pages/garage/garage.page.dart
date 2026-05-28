import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/infrastructure/sync/sync_service.dart';
import 'package:motorz/ui/pages/dashboard/dashboard.page.dart';
import 'package:motorz/ui/pages/garage/widgets/sync_status_action.widget.dart';
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

    // Alerte transitoire : nouvelle saisie refusée, ou synchro en échec réseau.
    // On ignore la 1ʳᵉ émission (prev null) pour ne pas spammer au démarrage.
    ref.listen(syncStatusProvider, (prev, next) {
      final p = prev?.value;
      final n = next.value;
      if (p == null || n == null) return;
      final messenger = ScaffoldMessenger.of(context);
      if (n.rejected > p.rejected) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Des saisies n\'ont pas pu être synchronisées.'),
        ));
      } else if (n.phase == SyncPhase.error && p.phase != SyncPhase.error) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Échec de synchronisation — nouvelle tentative au retour du réseau.'),
        ));
      }
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const MotorzWordmark(fontSize: 24),
        actions: [
          const SyncStatusAction(),
          IconButton(
            tooltip: 'Tableau de bord',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DashboardPage())),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(syncServiceProvider).syncNow(),
        child: vehiclesAsync.when(
          skipLoadingOnReload: true, // save/sync → reload : garde la liste, pas de flash spinner
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
                    _MutedLine('Aucun véhicule à toi. Ajoutes-en un depuis les réglages.',
                        colors: colors),
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
            'Ajoute un véhicule depuis les réglages pour suivre pleins, entretien et échéances.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Gérer mes véhicules'),
          ),
        ],
      ),
    );
  }
}
