import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/ownership.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';

double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

/// Édite « mon achat » (isMine) ou ajoute un ancien propriétaire descriptif.
Future<void> showOwnershipSheet(
  BuildContext context,
  WidgetRef ref, {
  required String vehicleId,
  required bool isMine,
  Ownership? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _OwnershipSheet(vehicleId: vehicleId, isMine: isMine, existing: existing),
  );
}

class _OwnershipSheet extends ConsumerStatefulWidget {
  const _OwnershipSheet({required this.vehicleId, required this.isMine, this.existing});
  final String vehicleId;
  final bool isMine;
  final Ownership? existing;

  @override
  ConsumerState<_OwnershipSheet> createState() => _OwnershipSheetState();
}

class _OwnershipSheetState extends ConsumerState<_OwnershipSheet> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _odo;
  late final TextEditingController _price;
  DateTime? _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _firstName = TextEditingController(text: e?.firstName ?? '');
    _lastName = TextEditingController(text: e?.lastName ?? '');
    _odo = TextEditingController(text: e?.acquiredOdometer?.toString() ?? '');
    _price = TextEditingController(text: e?.purchasePrice?.toString() ?? '');
    _date = e?.acquiredDate != null ? DateTime.tryParse(e!.acquiredDate!) : null;
  }

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _odo, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final base = widget.existing;
    final ownership = Ownership(
      id: base?.id ?? UuidValue.generate(),
      vehicleId: UuidValue.parse(widget.vehicleId),
      userId: widget.isMine ? ref.read(currentSessionProvider)?.user.id : null,
      firstName: widget.isMine ? null : (_firstName.text.trim().isEmpty ? null : _firstName.text.trim()),
      lastName: widget.isMine ? null : (_lastName.text.trim().isEmpty ? null : _lastName.text.trim()),
      acquiredOdometer: int.tryParse(_odo.text),
      purchasePrice: _num(_price.text),
      acquiredDate: _date?.toIso8601String().substring(0, 10),
      isCurrent: widget.isMine,
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(ownershipRepositoryProvider).save(ownership);
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
          Text(widget.isMine ? 'Mon achat' : 'Ancien propriétaire',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (!widget.isMine) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _firstName,
                    decoration: const InputDecoration(labelText: 'Prénom'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lastName,
                    decoration: const InputDecoration(labelText: 'Nom'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _odo,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Km à l\'achat', suffixText: 'km'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Prix d\'achat', suffixText: '€'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date ?? DateTime.now(),
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date d\'achat'),
              child: Text(_date == null
                  ? 'Choisir une date'
                  : '${_date!.day}/${_date!.month}/${_date!.year}'),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Enregistrer')),
        ],
      ),
    );
  }
}
