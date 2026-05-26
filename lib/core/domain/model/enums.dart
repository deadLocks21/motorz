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

/// Type de tâche du backlog. Le contrôle technique est une échéance datée.
enum TaskKind {
  oneShot,
  periodic,
  controleTechnique;

  String get wire => switch (this) {
    TaskKind.oneShot => 'one_shot',
    TaskKind.periodic => 'periodic',
    TaskKind.controleTechnique => 'controle_technique',
  };

  static TaskKind fromWire(String w) => switch (w) {
    'one_shot' => TaskKind.oneShot,
    'controle_technique' => TaskKind.controleTechnique,
    _ => TaskKind.periodic,
  };

  String get label => switch (this) {
    TaskKind.oneShot => 'Tâche ponctuelle',
    TaskKind.periodic => 'Entretien périodique',
    TaskKind.controleTechnique => 'Contrôle technique',
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
