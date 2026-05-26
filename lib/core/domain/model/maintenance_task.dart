import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';

/// Élément du backlog : tâche ponctuelle, entretien périodique ou CT.
/// L'état (`upcoming`/`dueSoon`/`overdue`) est calculé localement.
class MaintenanceTask {
  final UuidValue id;
  final UuidValue vehicleId;
  final String title;
  final String? description;
  final TaskKind kind;
  final String? category;
  final TaskPriority? priority;
  final double? estimatedCost;
  final String? dueDate; // YYYY-MM-DD (ponctuel / CT)
  final int? dueOdometer;
  final int? intervalKm; // périodique
  final int? intervalMonths; // périodique
  final String? lastDoneDate; // YYYY-MM-DD
  final int? lastDoneOdometer;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  MaintenanceTask({
    required this.id,
    required this.vehicleId,
    required this.title,
    required this.kind,
    required this.updatedAt,
    this.description,
    this.category,
    this.priority,
    this.estimatedCost,
    this.dueDate,
    this.dueOdometer,
    this.intervalKm,
    this.intervalMonths,
    this.lastDoneDate,
    this.lastDoneOdometer,
    this.deletedAt,
  }) : assert(title.trim().isNotEmpty, 'title cannot be empty');

  MaintenanceTask copyWith({
    String? title,
    String? description,
    TaskKind? kind,
    String? category,
    TaskPriority? priority,
    double? estimatedCost,
    String? dueDate,
    int? dueOdometer,
    int? intervalKm,
    int? intervalMonths,
    String? lastDoneDate,
    int? lastDoneOdometer,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return MaintenanceTask(
      id: id,
      vehicleId: vehicleId,
      title: title ?? this.title,
      description: description ?? this.description,
      kind: kind ?? this.kind,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      dueDate: dueDate ?? this.dueDate,
      dueOdometer: dueOdometer ?? this.dueOdometer,
      intervalKm: intervalKm ?? this.intervalKm,
      intervalMonths: intervalMonths ?? this.intervalMonths,
      lastDoneDate: lastDoneDate ?? this.lastDoneDate,
      lastDoneOdometer: lastDoneOdometer ?? this.lastDoneOdometer,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceTask && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
