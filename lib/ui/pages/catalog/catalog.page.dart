import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/maintenance_catalog_item.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';

/// Catalogue d'entretien de l'utilisateur (§5.6). Le catalogue s'enrichit surtout
/// à la saisie d'opération ; cette page sert à renommer/régler les intervalles
/// par défaut/supprimer les postes.
class CatalogPage extends ConsumerWidget {
  const CatalogPage({super.key});

  String _intervals(CatalogItem c) {
    final bits = <String>[];
    if (c.defaultIntervalKm != null) bits.add('${c.defaultIntervalKm} km');
    if (c.defaultIntervalMonths != null) bits.add('${c.defaultIntervalMonths} mois');
    return bits.isEmpty ? 'Sans intervalle par défaut' : 'Défaut : ${bits.join(' / ')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final items = ref.watch(catalogItemsProvider).value ?? const [];
    final userId = ref.watch(currentSessionProvider)?.user.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Catalogue d\'entretien')),
      floatingActionButton: userId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showCatalogItemSheet(context, ref, userId: userId),
              icon: const Icon(Icons.add),
              label: const Text('Poste'),
            ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Catalogue vide. Les postes s\'ajoutent en saisissant une opération d\'entretien.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textMuted),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
              children: [
                for (final c in items)
                  ListTile(
                    leading: Icon(Icons.bookmark_added_outlined, color: colors.accent),
                    title: Text(c.name),
                    subtitle: Text(_intervals(c)),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: colors.textMuted),
                      onPressed: () => ref.read(catalogItemRepositoryProvider).delete(c),
                    ),
                    onTap: () => showCatalogItemSheet(context, ref, userId: c.userId, existing: c),
                  ),
              ],
            ),
    );
  }
}

/// Crée ou édite un poste de catalogue (nom + intervalles par défaut).
Future<void> showCatalogItemSheet(
  BuildContext context,
  WidgetRef ref, {
  required UuidValue userId,
  CatalogItem? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CatalogSheet(userId: userId, existing: existing),
  );
}

class _CatalogSheet extends ConsumerStatefulWidget {
  const _CatalogSheet({required this.userId, this.existing});
  final UuidValue userId;
  final CatalogItem? existing;

  @override
  ConsumerState<_CatalogSheet> createState() => _CatalogSheetState();
}

class _CatalogSheetState extends ConsumerState<_CatalogSheet> {
  late final TextEditingController _name;
  late final TextEditingController _km;
  late final TextEditingController _months;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _km = TextEditingController(text: e?.defaultIntervalKm?.toString() ?? '');
    _months = TextEditingController(text: e?.defaultIntervalMonths?.toString() ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _km, _months]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Donne un nom au poste.')));
      return;
    }
    setState(() => _saving = true);
    final item = CatalogItem(
      id: widget.existing?.id ?? UuidValue.generate(),
      userId: widget.userId,
      name: name,
      defaultIntervalKm: int.tryParse(_km.text.trim()),
      defaultIntervalMonths: int.tryParse(_months.text.trim()),
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(catalogItemRepositoryProvider).save(item);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existing == null ? 'Nouveau poste' : 'Modifier le poste',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nom', hintText: 'Vidange, Filtre à gasoil…'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _km,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Intervalle', suffixText: 'km'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _months,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'ou', suffixText: 'mois'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Enregistrer')),
        ],
      ),
    );
  }
}
