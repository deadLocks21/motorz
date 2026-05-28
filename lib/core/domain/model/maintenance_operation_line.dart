import 'package:motorz/core/domain/model/uuid_value.dart';

/// Ligne d'une opération : **un poste fait**, décrit par un libellé libre + ses
/// coûts. Une ligne dont l'intitulé correspond au titre d'une échéance (§5.6)
/// remet cette échéance à zéro (rapprochement par intitulé, dérivé de l'historique).
class OperationLine {
  final UuidValue id;
  final UuidValue operationId;
  final String label;
  final double? partsCost;
  final double? laborCost;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  OperationLine({
    required this.id,
    required this.operationId,
    required this.label,
    required this.updatedAt,
    this.partsCost,
    this.laborCost,
    this.deletedAt,
  }) : assert(label.trim().isNotEmpty, 'label cannot be empty');

  /// Coût de la ligne (pièces + main d'œuvre) ; nul si rien n'est saisi.
  double? get cost {
    if (partsCost == null && laborCost == null) return null;
    return (partsCost ?? 0) + (laborCost ?? 0);
  }

  OperationLine copyWith({
    String? label,
    double? partsCost,
    double? laborCost,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return OperationLine(
      id: id,
      operationId: operationId,
      label: label ?? this.label,
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
