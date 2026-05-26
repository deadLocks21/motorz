import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';

/// Plein de carburant. La consommation est dérivée (volume / km parcourus)
/// par FuelStatsService — pas stockée.
class FuelEntry {
  final UuidValue id;
  final UuidValue vehicleId;
  final UuidValue? createdByUserId;
  final DateTime date;
  final int odometer;
  final double? volumeLiters;
  final double? pricePerLiter;
  final double? totalCost;
  final FuelType? fuelType;
  final String? station;
  final String? notes;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  FuelEntry({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.odometer,
    required this.updatedAt,
    this.createdByUserId,
    this.volumeLiters,
    this.pricePerLiter,
    this.totalCost,
    this.fuelType,
    this.station,
    this.notes,
    this.deletedAt,
  }) : assert(odometer >= 0, 'odometer must be >= 0');

  FuelEntry copyWith({
    DateTime? date,
    int? odometer,
    double? volumeLiters,
    double? pricePerLiter,
    double? totalCost,
    FuelType? fuelType,
    String? station,
    String? notes,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return FuelEntry(
      id: id,
      vehicleId: vehicleId,
      createdByUserId: createdByUserId,
      date: date ?? this.date,
      odometer: odometer ?? this.odometer,
      volumeLiters: volumeLiters ?? this.volumeLiters,
      pricePerLiter: pricePerLiter ?? this.pricePerLiter,
      totalCost: totalCost ?? this.totalCost,
      fuelType: fuelType ?? this.fuelType,
      station: station ?? this.station,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FuelEntry && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
