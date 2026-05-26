import 'package:motorz/core/domain/model/uuid_value.dart';

/// Période de possession (historique). Ma période porte `userId` + `isCurrent`
/// et son prix/km/date servent au TCO ; les précédentes sont descriptives.
class Ownership {
  final UuidValue id;
  final UuidValue vehicleId;
  final UuidValue? userId;
  final String? firstName;
  final String? lastName;
  final String? acquiredDate; // YYYY-MM-DD
  final int? acquiredOdometer;
  final double? purchasePrice;
  final bool isCurrent;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Ownership({
    required this.id,
    required this.vehicleId,
    required this.updatedAt,
    this.userId,
    this.firstName,
    this.lastName,
    this.acquiredDate,
    this.acquiredOdometer,
    this.purchasePrice,
    this.isCurrent = false,
    this.deletedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ownership && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
