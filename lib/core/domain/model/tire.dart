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
  final RimMaterial? rimMaterial;

  /// Dimension de jante en texte libre, ex. « 8J×19 ET40 ».
  final String? rimSpec;
  final TireSeason? season;
  final TireCondition condition;
  final String? purchaseDate; // YYYY-MM-DD
  final double? purchasePrice;
  final String? notes;
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
    this.rimMaterial,
    this.rimSpec,
    this.season,
    this.condition = TireCondition.neuf,
    this.purchaseDate,
    this.purchasePrice,
    this.notes,
    this.deletedAt,
  });

  /// Libellé compact « marque modèle » (ou « Pneu » si inconnu).
  String get descriptor {
    final parts = [brand, model].where((p) => p != null && p.isNotEmpty).join(' ');
    return parts.isEmpty ? 'Pneu' : parts;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tire && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
