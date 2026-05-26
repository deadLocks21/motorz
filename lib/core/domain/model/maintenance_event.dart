import 'package:motorz/core/domain/model/uuid_value.dart';

/// Opération d'entretien/réparation réalisée (cœur du carnet d'entretien).
class MaintenanceEvent {
  final UuidValue id;
  final UuidValue vehicleId;
  final UuidValue? createdByUserId;
  final UuidValue? taskId; // échéance clôturée par cette opération
  final DateTime date;
  final int odometer;
  final String? category;
  final String title;
  final String? description;
  final double? partsCost;
  final double? laborCost;
  final double? totalCost;
  final String? provider;
  final bool countQuoteInEstimate;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  MaintenanceEvent({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.odometer,
    required this.title,
    required this.updatedAt,
    this.createdByUserId,
    this.taskId,
    this.category,
    this.description,
    this.partsCost,
    this.laborCost,
    this.totalCost,
    this.provider,
    this.countQuoteInEstimate = true,
    this.deletedAt,
  }) : assert(title.trim().isNotEmpty, 'title cannot be empty');

  MaintenanceEvent copyWith({
    UuidValue? taskId,
    String? category,
    String? title,
    String? description,
    double? partsCost,
    double? laborCost,
    double? totalCost,
    String? provider,
    bool? countQuoteInEstimate,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return MaintenanceEvent(
      id: id,
      vehicleId: vehicleId,
      createdByUserId: createdByUserId,
      taskId: taskId ?? this.taskId,
      date: date,
      odometer: odometer,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      partsCost: partsCost ?? this.partsCost,
      laborCost: laborCost ?? this.laborCost,
      totalCost: totalCost ?? this.totalCost,
      provider: provider ?? this.provider,
      countQuoteInEstimate: countQuoteInEstimate ?? this.countQuoteInEstimate,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  /// Coût réel : total si saisi, sinon pièces + main d'œuvre.
  double? get effectiveCost {
    if (totalCost != null) return totalCost;
    if (partsCost == null && laborCost == null) return null;
    return (partsCost ?? 0) + (laborCost ?? 0);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceEvent && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
