import 'package:motorz/core/domain/model/uuid_value.dart';

/// Ligne d'une opération : **un poste fait**. Soit rattachée à un poste de
/// catalogue (`catalogItemId` → pilote le compteur du plan correspondant), soit
/// un **libellé libre** (`label`) pour un one-shot hors catalogue. Exactement
/// l'un des deux (XOR).
class OperationLine {
  final UuidValue id;
  final UuidValue operationId;
  final UuidValue? catalogItemId;
  final String? label;
  final double? partsCost;
  final double? laborCost;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  OperationLine({
    required this.id,
    required this.operationId,
    required this.updatedAt,
    this.catalogItemId,
    this.label,
    this.partsCost,
    this.laborCost,
    this.deletedAt,
  }) : assert(
          (catalogItemId == null) != (label == null),
          'a line is either a catalog item or a free label, not both',
        );

  /// Coût de la ligne (pièces + main d'œuvre) ; nul si rien n'est saisi.
  double? get cost {
    if (partsCost == null && laborCost == null) return null;
    return (partsCost ?? 0) + (laborCost ?? 0);
  }

  OperationLine copyWith({
    double? partsCost,
    double? laborCost,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return OperationLine(
      id: id,
      operationId: operationId,
      catalogItemId: catalogItemId,
      label: label,
      partsCost: partsCost ?? this.partsCost,
      laborCost: laborCost ?? this.laborCost,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OperationLine && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
