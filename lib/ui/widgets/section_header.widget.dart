import 'package:flutter/material.dart';

/// En-tête de section réutilisable : un titre et, optionnellement, un bouton
/// d'action à droite (« Ajouter » par défaut). Style commun à toutes les listes
/// éditables (finances, pressions cibles…).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key, this.onAdd, this.addLabel = 'Ajouter'});

  final String label;
  final VoidCallback? onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
          if (onAdd != null)
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(addLabel),
            ),
        ],
      ),
    );
  }
}
