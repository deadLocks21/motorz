import 'package:motorz/core/domain/model/uuid_value.dart';

/// Poste de coût libre / assurance — alimente le TCO (§5.2). Chaque entrée est
/// un paiement daté ; le TCO somme les entrées depuis ma date d'acquisition.
class CostEntry {
  final UuidValue id;
  final UuidValue vehicleId;
  final UuidValue? createdByUserId;
  final String label;
  final String? category; // ex. 'assurance' | 'autre'
  final double? amount;
  final DateTime date;
  final String? notes;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  CostEntry({
    required this.id,
    required this.vehicleId,
    required this.label,
    required this.date,
    required this.updatedAt,
    this.createdByUserId,
    this.category,
    this.amount,
    this.notes,
    this.deletedAt,
  }) : assert(label.trim().isNotEmpty, 'label cannot be empty');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CostEntry && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
