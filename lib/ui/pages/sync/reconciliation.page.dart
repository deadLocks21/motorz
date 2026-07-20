import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/application/sync/sync_conflict.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';

/// Arbitrage des entités modifiées des deux côtés pendant la déconnexion.
///
/// Le choix par défaut est « ma version » : l'utilisateur arrive ici parce que
/// ses saisies risquaient de disparaître, et c'est ce qu'il vient de faire qu'il
/// a le plus de chances de vouloir garder. La version serveur reste visible
/// champ par champ pour que le choix soit informé.
class ReconciliationPage extends ConsumerStatefulWidget {
  const ReconciliationPage({super.key});

  @override
  ConsumerState<ReconciliationPage> createState() => _ReconciliationPageState();
}

class _ReconciliationPageState extends ConsumerState<ReconciliationPage> {
  final Map<String, ConflictChoice> _choices = {};
  bool _applying = false;

  String _key(SyncConflict c) => '${c.resource}/${c.entityId}';

  ConflictChoice _choiceFor(SyncConflict c) =>
      _choices[_key(c)] ?? ConflictChoice.keepLocal;

  Future<void> _apply(List<SyncConflict> conflicts) async {
    setState(() => _applying = true);
    final messenger = ScaffoldMessenger.of(context);
    final resolved = {for (final c in conflicts) _key(c): _choiceFor(c)};
    final keptLocal = resolved.values.where((v) => v == ConflictChoice.keepLocal).length;
    try {
      await ref.read(syncServiceProvider).resolveConflicts(resolved);
      ref.read(pendingConflictsProvider.notifier).clear();
      messenger.showSnackBar(SnackBar(
        content: Text(keptLocal == 0
            ? 'Modifications locales abandonnées.'
            : '$keptLocal modification(s) envoyée(s) au serveur.'),
      ));
    } catch (_) {
      if (mounted) setState(() => _applying = false);
      messenger.showSnackBar(const SnackBar(
        content: Text('Synchronisation impossible. Réessaie plus tard.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final conflicts = ref.watch(pendingConflictsProvider);
    if (conflicts.isEmpty) return const SizedBox.shrink();

    final keptLocal =
        conflicts.where((c) => _choiceFor(c) == ConflictChoice.keepLocal).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifications en attente'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                conflicts.length == 1
                    ? 'Un élément a changé ici et sur le serveur pendant ta déconnexion. '
                        'Choisis la version à garder.'
                    : '${conflicts.length} éléments ont changé ici et sur le serveur pendant '
                        'ta déconnexion. Choisis la version à garder pour chacun.',
                style: TextStyle(color: colors.textMuted, fontSize: 13),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: conflicts.length,
                itemBuilder: (_, i) {
                  final c = conflicts[i];
                  return _ConflictCard(
                    conflict: c,
                    choice: _choiceFor(c),
                    onChanged: _applying
                        ? null
                        : (v) => setState(() => _choices[_key(c)] = v),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('applyReconciliationButton'),
                  onPressed: _applying ? null : () => _apply(conflicts),
                  child: _applying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(keptLocal == 0
                          ? 'Tout abandonner'
                          : 'Envoyer $keptLocal modification(s)'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  final SyncConflict conflict;
  final ConflictChoice choice;
  final ValueChanged<ConflictChoice>? onChanged;

  const _ConflictCard({
    required this.conflict,
    required this.choice,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final title = entityLabel(conflict.resource, conflict.server, conflict.local.data);
    final fields = conflict.changedFields;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                const SizedBox(width: 8),
                Text(resourceLabel(conflict.resource),
                    style: TextStyle(color: colors.textMuted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              conflict.localDeletes
                  ? 'Supprimé ici, modifié sur le serveur'
                  : '+${fields.length} champ(s) différent(s)',
              style: TextStyle(color: colors.textMuted, fontSize: 13),
            ),
            if (fields.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...fields.take(5).map((f) => _FieldRow(
                    label: fieldLabel(f),
                    local: conflict.local.data[f],
                    server: conflict.server[f],
                  )),
              if (fields.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('… et ${fields.length - 5} autre(s)',
                      style: TextStyle(color: colors.textMuted, fontSize: 12)),
                ),
            ],
            const SizedBox(height: 12),
            SegmentedButton<ConflictChoice>(
              segments: const [
                ButtonSegment(
                  value: ConflictChoice.keepLocal,
                  label: Text('Ma version'),
                  icon: Icon(Icons.smartphone_outlined, size: 16),
                ),
                ButtonSegment(
                  value: ConflictChoice.keepServer,
                  label: Text('Serveur'),
                  icon: Icon(Icons.cloud_outlined, size: 16),
                ),
              ],
              selected: {choice},
              showSelectedIcon: false,
              onSelectionChanged:
                  onChanged == null ? null : (s) => onChanged!(s.first),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final Object? local;
  final Object? server;

  const _FieldRow({required this.label, required this.local, required this.server});

  static String _fmt(Object? v) {
    if (v == null) return '—';
    final s = v.toString();
    return s.isEmpty ? '—' : (s.length > 40 ? '${s.substring(0, 39)}…' : s);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: TextStyle(color: colors.textMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(_fmt(local),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward, size: 12, color: colors.textMuted),
          ),
          Expanded(
            child: Text(_fmt(server),
                style: TextStyle(fontSize: 12, color: colors.textMuted)),
          ),
        ],
      ),
    );
  }
}
