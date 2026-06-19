import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';

/// Un pneu+jante physique de l'inventaire d'un véhicule. La position courante et
/// les km roulés ne sont **pas** stockés ici : ils se dérivent du journal de
/// montages ([TireMount]) — cf. TireService.
class Tire {
  final UuidValue id;
  final UuidValue vehicleId;
  final UuidValue? createdByUserId;
  final String? brand;
  final String? model;

  /// Taille pneu en texte libre, ex. « 255/40 R19 ».
  final String? size;

  /// Repère libre pour distinguer deux pneus identiques (ex. « A », « 1 »,
  /// « marqué bleu ») — en miroir d'une marque physique sur le pneu.
  final String? marker;
  final RimMaterial? rimMaterial;

  /// Dimension de jante en texte libre, ex. « 8J×19 ET40 ».
  final String? rimSpec;
  final TireSeason? season;
  final TireCondition condition;
  final String? purchaseDate; // YYYY-MM-DD
  final double? purchasePrice;
  final String? notes;

  /// Date de mise au rebut (YYYY-MM-DD). Non-null ⇒ pneu **au rebut** : sorti de
  /// l'inventaire actif et de la monte, mais conservé (avec ses montages) pour
  /// l'historique. Null ⇒ en service / en stock.
  final String? disposedDate;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Tire({
    required this.id,
    required this.vehicleId,
    required this.updatedAt,
    this.createdByUserId,
    this.brand,
    this.model,
    this.size,
    this.marker,
    this.rimMaterial,
    this.rimSpec,
    this.season,
    this.condition = TireCondition.neuf,
    this.purchaseDate,
    this.purchasePrice,
    this.notes,
    this.disposedDate,
    this.deletedAt,
  });

  /// Pneu au rebut (parti à la benne) : hors inventaire actif, gardé pour l'historique.
  bool get isDisposed => disposedDate != null;

  /// Libellé compact « marque modèle » (ou « Pneu » si inconnu).
  String get descriptor {
    final parts = [brand, model].where((p) => p != null && p.isNotEmpty).join(' ');
    return parts.isEmpty ? 'Pneu' : parts;
  }

  /// Libellé d'affichage : descriptor + repère s'il existe, pour distinguer deux
  /// pneus identiques. Ex. « Michelin Pilot Sport 4S · A ».
  String get displayName {
    final m = marker?.trim();
    return (m == null || m.isEmpty) ? descriptor : '$descriptor · $m';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tire && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
