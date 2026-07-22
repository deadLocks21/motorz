import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';

/// Plein de carburant. La consommation est dérivée (volume / km parcourus)
/// par FuelStatsService — pas stockée.
class FuelEntry {
  final UuidValue id;
  final UuidValue vehicleId;
  final UuidValue? createdByUserId;
  /// Date du plein. Optionnelle : un plein peut être saisi avec seulement le
  /// kilométrage (au moins l'un des deux — date ou odometer — est renseigné).
  final DateTime? date;
  /// Kilométrage au plein. Optionnel (cf. [date]).
  final int? odometer;
  final double? volumeLiters;
  final double? pricePerLiter;
  final double? totalCost;
  final FuelType? fuelType;
  final String? station;
  final String? notes;
  /// Un plein a été fait entre le précédent et celui-ci sans être saisi
  /// (véhicule prêté, ticket perdu). Les litres manquants rendent le segment
  /// non mesurable : il sort de la conso, km compris (cf. StatsService).
  final bool missedFillBefore;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  FuelEntry({
    required this.id,
    required this.vehicleId,
    required this.updatedAt,
    this.date,
    this.odometer,
    this.createdByUserId,
    this.volumeLiters,
    this.pricePerLiter,
    this.totalCost,
    this.fuelType,
    this.station,
    this.notes,
    this.missedFillBefore = false,
    this.deletedAt,
  })  : assert(odometer == null || odometer >= 0, 'odometer must be >= 0'),
        assert(date != null || odometer != null,
            'au moins la date ou le kilométrage doit être renseigné');

  FuelEntry copyWith({
    DateTime? date,
    int? odometer,
    double? volumeLiters,
    double? pricePerLiter,
    double? totalCost,
    FuelType? fuelType,
    String? station,
    String? notes,
    bool? missedFillBefore,
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
      missedFillBefore: missedFillBefore ?? this.missedFillBefore,
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
