import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/sync/sync_service.dart';

/// Action d'AppBar qui matérialise l'état de synchro :
/// - un spinner pendant une synchro en cours ;
/// - une pastille d'alerte (nombre de saisies refusées) quand la dead-letter
///   n'est pas vide, ouvrant une boîte « réessayer / ignorer » ;
/// - rien quand tout est synchronisé (le hors-ligne a déjà sa bannière).
class SyncStatusAction extends ConsumerWidget {
  const SyncStatusAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider).value;
    if (status == null) return const SizedBox.shrink();

    if (status.phase == SyncPhase.syncing) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (status.rejected > 0) {
      return IconButton(
        tooltip: 'Synchronisation incomplète',
        icon: Badge(
          label: Text('${status.rejected}'),
          child: const Icon(Icons.sync_problem_outlined),
        ),
        onPressed: () => _showRejectedDialog(context, ref, status.rejected),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _showRejectedDialog(BuildContext context, WidgetRef ref, int count) async {
    final messenger = ScaffoldMessenger.of(context);
    final action = await showDialog<_RejectedAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Synchronisation incomplète'),
        content: Text(
          '$count saisie(s) ont été refusées par le serveur (invalides ou non '
          'autorisées) et ne sont pas synchronisées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _RejectedAction.discard),
            child: const Text('Ignorer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _RejectedAction.retry),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
    if (action == null) return;

    final sync = ref.read(syncServiceProvider);
    switch (action) {
      case _RejectedAction.retry:
        await sync.retryRejected();
      case _RejectedAction.discard:
        await sync.discardRejected();
        messenger.showSnackBar(
          const SnackBar(content: Text('Saisies non synchronisées abandonnées.')),
        );
    }
  }
}

enum _RejectedAction { retry, discard }
