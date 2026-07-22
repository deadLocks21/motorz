import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/maintenance_quote.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/ui/pages/vehicle_detail/widgets/documents_tab.widget.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';

double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

/// Saisie / édition d'un **devis comparatif** : prestataire + montant (les deux
/// requis — un devis sans montant n'alimenterait rien), notes et documents.
/// [existing] nul = création.
Future<void> showQuoteSheet(
  BuildContext context,
  WidgetRef ref, {
  required String operationId,
  MaintenanceQuote? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _QuoteSheet(operationId: operationId, existing: existing),
  );
}

class _QuoteSheet extends ConsumerStatefulWidget {
  const _QuoteSheet({required this.operationId, this.existing});
  final String operationId;
  final MaintenanceQuote? existing;

  @override
  ConsumerState<_QuoteSheet> createState() => _QuoteSheetState();
}

class _QuoteSheetState extends ConsumerState<_QuoteSheet> {
  late final TextEditingController _provider;
  final _providerFocus = FocusNode();
  late final TextEditingController _amount;
  late final TextEditingController _notes;

  /// Id posé dès l'ouverture (UUID client) : les documents s'y rattachent avant
  /// même le premier enregistrement.
  late final UuidValue _id;

  /// Le devis existe-t-il déjà en base ? Vrai en édition, et dès qu'une pièce
  /// jointe a forcé l'enregistrement (cf. [_ensureSaved]).
  late bool _persisted;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _id = e?.id ?? UuidValue.generate();
    _persisted = e != null;
    _provider = TextEditingController(text: e?.provider ?? '');
    _amount = TextEditingController(text: e?.amount?.toString() ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
  }

  @override
  void dispose() {
    for (final c in [_provider, _amount, _notes]) {
      c.dispose();
    }
    _providerFocus.dispose();
    super.dispose();
  }

  /// Devis à enregistrer, ou `null` si la saisie est incomplète (message à
  /// l'appui). Le premier devis d'une opération est **retenu d'office** : c'est
  /// la référence tant qu'on n'en désigne pas une autre.
  Future<MaintenanceQuote?> _draft() async {
    final provider = _provider.text.trim();
    final amount = _num(_amount.text);
    final messenger = ScaffoldMessenger.of(context);
    if (provider.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Indique le prestataire (garage).')));
      return null;
    }
    if (amount == null || amount <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('Indique le montant du devis.')));
      return null;
    }
    final siblings = await ref.read(quotesForOperationProvider(widget.operationId).future);
    final isFirst = siblings.every((q) => q.id == _id);
    final notes = _notes.text.trim();
    final now = DateTime.now().toUtc();
    return MaintenanceQuote(
      id: _id,
      operationId: UuidValue.parse(widget.operationId),
      provider: provider,
      amount: amount,
      isSelected: widget.existing?.isSelected ?? isFirst,
      notes: notes.isEmpty ? null : notes,
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  /// Enregistre le devis puis attend la synchro : l'upload d'un document exige
  /// que le devis existe **côté serveur** (le média y est rattaché). Renvoie
  /// faux si la saisie est incomplète.
  Future<bool> _ensureSaved() async {
    final quote = await _draft();
    if (quote == null) return false;
    await ref.read(maintenanceQuoteRepositoryProvider).save(quote);
    if (!_persisted) {
      await ref.read(syncServiceProvider).syncNow();
      if (mounted) setState(() => _persisted = true);
    }
    return true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await _ensureSaved();
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  /// Supprime le devis et, s'il faisait référence, promeut le suivant — sans
  /// quoi l'opération garderait des devis dont aucun ne compte.
  Future<void> _delete() async {
    final quote = widget.existing;
    if (quote == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce devis ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(maintenanceQuoteRepositoryProvider);
    await repo.delete(quote);
    if (quote.isSelected) {
      final remaining = MaintenanceQuote.ordered(
        (await ref.read(quotesForOperationProvider(widget.operationId).future))
            .where((q) => q.id != quote.id),
      );
      if (remaining.isNotEmpty) {
        await repo.save(remaining.first
            .copyWith(isSelected: true, updatedAt: DateTime.now().toUtc()));
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final providers = ref.watch(knownProvidersProvider).value ?? const <String>[];
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'Modifier le devis' : 'Devis comparatif',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _providerField(providers),
            const SizedBox(height: 12),
            TextField(
              key: const Key('quoteAmountField'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Montant', suffixText: '€'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Détails du chiffrage (optionnel)',
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Documents', style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            MediaGrid(
              ownerType: 'maintenance_quote',
              ownerId: _id.value,
              // Un document ne peut se rattacher qu'à un devis déjà enregistré :
              // on enregistre d'abord (et la saisie doit donc être complète).
              beforeUpload: _ensureSaved,
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('saveQuoteButton'),
              onPressed: _saving ? null : _save,
              child: Text(_isEdit ? 'Enregistrer' : 'Ajouter le devis'),
            ),
            if (_isEdit)
              TextButton(
                onPressed: _saving ? null : _delete,
                child: const Text('Supprimer le devis'),
              ),
          ],
        ),
      ),
    );
  }

  /// Champ « Prestataire », calqué sur celui de l'opération : mêmes garages
  /// proposés (on fait chiffrer là où on fait réparer). Simple champ texte tant
  /// qu'aucun prestataire n'est connu.
  Widget _providerField(List<String> providers) {
    const decoration = InputDecoration(labelText: 'Prestataire', hintText: 'Garage Dupont');
    if (providers.isEmpty) {
      return TextField(
        key: const Key('quoteProviderField'),
        controller: _provider,
        focusNode: _providerFocus,
        textCapitalization: TextCapitalization.words,
        decoration: decoration,
      );
    }
    return Autocomplete<String>(
      textEditingController: _provider,
      focusNode: _providerFocus,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return providers; // focus champ vide → tout proposer
        final matches = providers.where((s) => s.toLowerCase().contains(q)).toList();
        if (matches.length == 1 && matches.first.toLowerCase() == q) {
          return const Iterable<String>.empty();
        }
        return matches;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          key: const Key('quoteProviderField'),
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          decoration: decoration.copyWith(suffixIcon: const Icon(Icons.arrow_drop_down)),
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
    );
  }
}
