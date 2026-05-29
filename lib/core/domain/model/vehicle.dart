import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';

/// Véhicule possédé par un utilisateur. Le **km courant** n'est pas stocké :
/// il est dérivé du MAX(odometer) des saisies (cf. VehicleStatsService).
class Vehicle {
  final UuidValue id;
  final UuidValue ownerUserId;
  final String? shareCode; // assigné par le serveur après synchro
  final VehicleType type;
  final String nickname;
  final String? make;
  final String? model;
  final int? year;
  final String? trim;
  final String? vin;
  final String? licensePlate;
  final FuelType? fuelType;
  final int? engineCc;
  final int? powerHp;
  final String? firstRegistrationDate; // YYYY-MM-DD
  final String? color;
  final UuidValue? photoMediaId;

  /// Perte de pression « normale » attendue, en bar par mois. Sert de référence
  /// pour signaler une roue qui se dégonfle anormalement vite. Null → défaut.
  final double? tireMonthlyLossBar;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// Perte mensuelle par défaut (bar) quand le véhicule n'en définit pas.
  static const defaultTireMonthlyLossBar = 0.1;

  Vehicle({
    required this.id,
    required this.ownerUserId,
    required this.type,
    required this.nickname,
    required this.updatedAt,
    this.shareCode,
    this.make,
    this.model,
    this.year,
    this.trim,
    this.vin,
    this.licensePlate,
    this.fuelType,
    this.engineCc,
    this.powerHp,
    this.firstRegistrationDate,
    this.color,
    this.photoMediaId,
    this.tireMonthlyLossBar,
    this.deletedAt,
  }) : assert(nickname.trim().isNotEmpty, 'nickname cannot be empty');

  int get wheelCount => type.wheelCount;

  /// Taux de perte effectif (valeur du véhicule ou défaut).
  double get tireMonthlyLoss => tireMonthlyLossBar ?? defaultTireMonthlyLossBar;

  /// Libellé compact « marque modèle (année) ».
  String get descriptor {
    final parts = [make, model].where((p) => p != null && p.isNotEmpty).join(' ');
    if (parts.isEmpty) return type.label;
    return year != null ? '$parts ($year)' : parts;
  }

  Vehicle copyWith({
    String? shareCode,
    VehicleType? type,
    String? nickname,
    String? make,
    String? model,
    int? year,
    String? trim,
    String? vin,
    String? licensePlate,
    FuelType? fuelType,
    int? engineCc,
    int? powerHp,
    String? firstRegistrationDate,
    String? color,
    UuidValue? photoMediaId,
    double? tireMonthlyLossBar,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Vehicle(
      id: id,
      ownerUserId: ownerUserId,
      shareCode: shareCode ?? this.shareCode,
      type: type ?? this.type,
      nickname: nickname ?? this.nickname,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      trim: trim ?? this.trim,
      vin: vin ?? this.vin,
      licensePlate: licensePlate ?? this.licensePlate,
      fuelType: fuelType ?? this.fuelType,
      engineCc: engineCc ?? this.engineCc,
      powerHp: powerHp ?? this.powerHp,
      firstRegistrationDate: firstRegistrationDate ?? this.firstRegistrationDate,
      color: color ?? this.color,
      photoMediaId: photoMediaId ?? this.photoMediaId,
      tireMonthlyLossBar: tireMonthlyLossBar ?? this.tireMonthlyLossBar,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vehicle && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
