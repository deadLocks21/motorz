import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/maintenance_quote.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';

double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

Future<void> showAddQuoteSheet(BuildContext context, WidgetRef ref, {required String eventId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddQuoteSheet(eventId: eventId),
  );
}

class _AddQuoteSheet extends ConsumerStatefulWidget {
  const _AddQuoteSheet({required this.eventId});
  final String eventId;

  @override
  ConsumerState<_AddQuoteSheet> createState() => _AddQuoteSheetState();
}

class _AddQuoteSheetState extends ConsumerState<_AddQuoteSheet> {
  final _source = TextEditingController();
  final _amount = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _source.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final source = _source.text.trim();
    if (source.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Indique la source du devis (garage).')));
      return;
    }
    setState(() => _saving = true);
    final quote = MaintenanceQuote(
      id: UuidValue.generate(),
      maintenanceEventId: UuidValue.parse(widget.eventId),
      source: source,
      amount: _num(_amount.text),
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(maintenanceQuoteRepositoryProvider).save(quote);
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
          Text('Devis comparatif', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _source,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Source', hintText: 'Garage Dupont'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Montant', suffixText: '€'),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Ajouter le devis')),
        ],
      ),
    );
  }
}
