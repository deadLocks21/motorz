import 'package:motorz/core/domain/model/uuid_value.dart';

/// Relevé de pression par roue (en bar). Clés selon le nombre de roues :
/// `{AV, AR}` (2 roues) ou `{AVG, AVD, ARG, ARD}` (4 roues).
class TirePressureEntry {
  final UuidValue id;
  final UuidValue vehicleId;
  final UuidValue? createdByUserId;
  final DateTime date;
  final int odometer;
  final Map<String, double> pressures;
  final String? notes;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  TirePressureEntry({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.odometer,
    required this.pressures,
    required this.updatedAt,
    this.createdByUserId,
    this.notes,
    this.deletedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TirePressureEntry && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
