import 'package:motorz/core/domain/model/uuid_value.dart';

/// Pression cible nommée (avant/arrière par essieu, en bar) — ex. « à vide ».
class TargetPressure {
  final UuidValue id;
  final UuidValue vehicleId;
  final String label;
  final double? front;
  final double? rear;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  TargetPressure({
    required this.id,
    required this.vehicleId,
    required this.label,
    required this.updatedAt,
    this.front,
    this.rear,
    this.deletedAt,
  }) : assert(label.trim().isNotEmpty, 'label cannot be empty');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TargetPressure && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
