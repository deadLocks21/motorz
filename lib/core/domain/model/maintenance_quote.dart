import 'package:motorz/core/domain/model/uuid_value.dart';

/// Devis comparatif rattaché à une opération d'entretien (§5.5). Jamais compté
/// comme dépense réelle ; le devis retenu (`isSelected`) alimente l'estimatif
/// « tout en garage ».
class MaintenanceQuote {
  final UuidValue id;
  final UuidValue operationId;
  final String? source;
  final double? amount;
  final bool isSelected;
  final String? notes;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  MaintenanceQuote({
    required this.id,
    required this.operationId,
    required this.updatedAt,
    this.source,
    this.amount,
    this.isSelected = false,
    this.notes,
    this.deletedAt,
  });

  MaintenanceQuote copyWith({
    String? source,
    double? amount,
    bool? isSelected,
    String? notes,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return MaintenanceQuote(
      id: id,
      operationId: operationId,
      source: source ?? this.source,
      amount: amount ?? this.amount,
      isSelected: isSelected ?? this.isSelected,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceQuote && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
