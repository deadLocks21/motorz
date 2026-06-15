import 'package:motorz/core/domain/model/uuid_value.dart';

/// Intervalle de montage d'un [Tire] (`tire.dart`) à une position. Un intervalle
/// **ouvert** (`dismountedOdometer == null`, non supprimé) ⇒ pneu actuellement
/// monté à cette position. Les km roulés d'un pneu se dérivent de la somme de ses
/// intervalles (cf. TireService) — on enregistre l'odomètre à chaque montage et
/// démontage.
class TireMount {
  final UuidValue id;
  final UuidValue vehicleId;
  final UuidValue tireId;

  /// AVG|AVD|ARG|ARD, AV|AR, ou SEC (secours) — cf. wheelPositions / positionLabel.
  final String position;
  final int mountedOdometer;
  final String? mountedDate; // YYYY-MM-DD
  final int? dismountedOdometer;
  final String? dismountedDate; // YYYY-MM-DD
  final DateTime updatedAt;
  final DateTime? deletedAt;

  TireMount({
    required this.id,
    required this.vehicleId,
    required this.tireId,
    required this.position,
    required this.mountedOdometer,
    required this.updatedAt,
    this.mountedDate,
    this.dismountedOdometer,
    this.dismountedDate,
    this.deletedAt,
  });

  /// Pneu encore monté : intervalle ouvert et non supprimé.
  bool get isOpen => dismountedOdometer == null && deletedAt == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TireMount && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
