import 'package:flutter/material.dart';

/// Nature documentaire d'un média (cf. `media.category` côté API), distincte du
/// *format* (`kind` = photo/pdf). `uncategorized` est le défaut / repli.
enum MediaCategory {
  invoice('invoice', 'Facture', Icons.receipt_long_outlined),
  quote('quote', 'Devis', Icons.request_quote_outlined),
  registration('registration', 'Carte grise', Icons.badge_outlined),
  insurance('insurance', 'Assurance', Icons.verified_user_outlined),
  inspection('inspection', 'Contrôle technique', Icons.fact_check_outlined),
  photo('photo', 'Photo', Icons.photo_outlined),
  uncategorized('uncategorized', 'Non classé', Icons.folder_outlined);

  const MediaCategory(this.value, this.label, this.icon);

  /// Valeur transmise à l'API et stockée en base.
  final String value;

  /// Libellé affiché à l'utilisateur.
  final String label;
  final IconData icon;

  /// Repli sur `uncategorized` pour toute valeur inconnue (anciens médias).
  static MediaCategory fromValue(String? v) =>
      values.firstWhere((c) => c.value == v, orElse: () => uncategorized);

  /// Pré-sélection raisonnable du picker selon la cible et le format du fichier.
  static MediaCategory suggestion({required String ownerType, required String kind}) {
    switch (ownerType) {
      case 'maintenance_quote':
        return quote;
      case 'maintenance_operation':
      case 'fuel_entry':
        return invoice;
      default:
        return kind == 'photo' ? photo : uncategorized;
    }
  }
}
