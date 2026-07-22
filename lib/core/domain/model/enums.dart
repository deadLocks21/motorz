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

/// Périodicité d'un poste de coût. `ponctuel` = un paiement daté (une révision,
/// une franchise). Les autres décrivent une charge **perpétuelle** saisie une
/// seule fois — « l'assurance, c'est 800 € par an » — que le TCO étale au
/// prorata du temps de possession plutôt que d'attendre une ligne par échéance.
enum CostRecurrence {
  ponctuel,
  mensuel,
  trimestriel,
  semestriel,
  annuel;

  String get wire => name;

  /// Repli sur `ponctuel` : c'est la valeur des frais saisis avant ce champ.
  static CostRecurrence fromWire(String? w) =>
      CostRecurrence.values.where((e) => e.name == w).firstOrNull ?? CostRecurrence.ponctuel;

  bool get isRecurring => this != CostRecurrence.ponctuel;

  /// Nombre de mois couverts par un versement. Zéro pour `ponctuel` : un
  /// paiement unique ne couvre aucune période, il ne s'étale pas.
  int get months => switch (this) {
    CostRecurrence.ponctuel => 0,
    CostRecurrence.mensuel => 1,
    CostRecurrence.trimestriel => 3,
    CostRecurrence.semestriel => 6,
    CostRecurrence.annuel => 12,
  };

  String get label => switch (this) {
    CostRecurrence.ponctuel => 'Ponctuel',
    CostRecurrence.mensuel => 'Par mois',
    CostRecurrence.trimestriel => 'Par trimestre',
    CostRecurrence.semestriel => 'Par semestre',
    CostRecurrence.annuel => 'Par an',
  };

  /// Suffixe court accolé au montant (« 800 € /an »).
  String get suffix => switch (this) {
    CostRecurrence.ponctuel => '',
    CostRecurrence.mensuel => '/mois',
    CostRecurrence.trimestriel => '/trimestre',
    CostRecurrence.semestriel => '/semestre',
    CostRecurrence.annuel => '/an',
  };
}

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
