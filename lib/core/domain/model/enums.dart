/// Type de véhicule — détermine le nombre de roues (pressions, affichage).
enum VehicleType {
  voiture,
  moto,
  scooter,
  autre;

  /// 2 roues pour moto/scooter, 4 sinon.
  int get wheelCount => (this == VehicleType.moto || this == VehicleType.scooter) ? 2 : 4;

  String get wire => name;
  static VehicleType fromWire(String w) =>
      VehicleType.values.where((e) => e.name == w).firstOrNull ?? VehicleType.autre;

  String get label => switch (this) {
    VehicleType.voiture => 'Voiture',
    VehicleType.moto => 'Moto',
    VehicleType.scooter => 'Scooter',
    VehicleType.autre => 'Autre',
  };
}

/// Carburant. Électrique/hybride hors périmètre.
enum FuelType {
  essence,
  diesel,
  gpl;

  String get wire => name;
  static FuelType? fromWire(String? w) =>
      w == null ? null : FuelType.values.where((e) => e.name == w).firstOrNull;

  String get label => switch (this) {
    FuelType.essence => 'Essence',
    FuelType.diesel => 'Diesel',
    FuelType.gpl => 'GPL',
  };
}

enum TaskPriority {
  basse,
  normale,
  haute;

  String get wire => name;
  static TaskPriority? fromWire(String? w) =>
      w == null ? null : TaskPriority.values.where((e) => e.name == w).firstOrNull;
}

/// État d'échéance calculé localement (cf. indicateurs in-app).
enum DueStatus { upcoming, dueSoon, overdue }

/// État d'un pneu à l'achat. Requis (défaut : neuf).
enum TireCondition {
  neuf,
  occasion;

  String get wire => name;
  static TireCondition fromWire(String? w) =>
      TireCondition.values.where((e) => e.name == w).firstOrNull ?? TireCondition.neuf;

  String get label => switch (this) {
    TireCondition.neuf => 'Neuf',
    TireCondition.occasion => 'Occasion',
  };
}

/// Saison / usage d'un pneu (oriente « lequel est monté »).
enum TireSeason {
  ete,
  hiver,
  quatreSaisons,
  circuit;

  String get wire => switch (this) {
    TireSeason.ete => 'ete',
    TireSeason.hiver => 'hiver',
    TireSeason.quatreSaisons => 'quatre_saisons',
    TireSeason.circuit => 'circuit',
  };
  static TireSeason? fromWire(String? w) =>
      w == null ? null : TireSeason.values.where((e) => e.wire == w).firstOrNull;

  String get label => switch (this) {
    TireSeason.ete => 'Été',
    TireSeason.hiver => 'Hiver',
    TireSeason.quatreSaisons => '4 saisons',
    TireSeason.circuit => 'Circuit',
  };
}

/// Matériau de jante.
enum RimMaterial {
  alu,
  tole,
  autre;

  String get wire => name;
  static RimMaterial? fromWire(String? w) =>
      w == null ? null : RimMaterial.values.where((e) => e.name == w).firstOrNull;

  String get label => switch (this) {
    RimMaterial.alu => 'Alu',
    RimMaterial.tole => 'Tôle',
    RimMaterial.autre => 'Autre',
  };
}

/// Positions des roues motrices d'un véhicule selon son nombre de roues (2 ou 4),
/// dans le même schéma que les relevés de pression. Hors roue de secours.
List<String> wheelPositions(int wheelCount) =>
    wheelCount == 2 ? const ['AV', 'AR'] : const ['AVG', 'AVD', 'ARG', 'ARD'];

/// Position « roue de secours » (galette), proposée en plus des roues motrices.
const spareWheelPosition = 'SEC';

/// Libellé lisible d'une position de roue (cf. [wheelPositions]).
String positionLabel(String position) => switch (position) {
  'AV' => 'Avant',
  'AR' => 'Arrière',
  'AVG' => 'Avant gauche',
  'AVD' => 'Avant droit',
  'ARG' => 'Arrière gauche',
  'ARD' => 'Arrière droit',
  'SEC' => 'Secours',
  _ => position,
};
