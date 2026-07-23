import 'package:motorz/core/domain/model/uuid_value.dart';

/// Nature d'une session : lecture de codes défaut, ou test de batterie. Une
/// seule entité pour les deux — elles partagent date, km, documents joints et
/// place dans l'historique ; seul le contenu diffère (§5.11).
enum DiagnosticType {
  obd,
  battery;

  String get wire => name;
  static DiagnosticType fromWire(String? w) =>
      DiagnosticType.values.where((e) => e.name == w).firstOrNull ?? DiagnosticType.obd;

  String get label => switch (this) {
    DiagnosticType.obd => 'Diagnostic OBD',
    DiagnosticType.battery => 'Test de batterie',
  };
}

/// Comment le rapport est entré — pas ce qu'il contient.
enum DiagnosticSource {
  manual,
  pasted,
  pdf,
  link;

  String get wire => name;
  static DiagnosticSource fromWire(String? w) =>
      DiagnosticSource.values.where((e) => e.name == w).firstOrNull ?? DiagnosticSource.manual;

  String get label => switch (this) {
    DiagnosticSource.manual => 'Saisi à la main',
    DiagnosticSource.pasted => 'Rapport collé',
    DiagnosticSource.pdf => 'PDF',
    DiagnosticSource.link => 'Lien',
  };
}

/// Un relevé daté du véhicule, au même titre qu'un plein ou une pression.
///
/// Motorz **archive** le rapport produit par une valise ou un testeur ; il ne
/// pilote aucun dongle et n'efface aucun code (§5.11).
class DiagnosticSession {
  final UuidValue id;
  final UuidValue vehicleId;
  final UuidValue? createdByUserId;
  final DateTime date;

  /// Kilométrage au relevé. **Optionnel** : un rapport OBD ne le porte jamais,
  /// et en inventer un fausserait le compteur dérivé du véhicule.
  final int? odometer;
  final DiagnosticType type;

  /// Outil ayant produit le rapport (« Car Scanner ELM OBD2 1.118.0 »).
  final String? tool;

  /// Profil de connexion du scanner (« Citroen OBD-II / EOBD »).
  final String? connectionProfile;
  final DiagnosticSource source;

  /// Rapport en ligne (testeur de batterie). Conservé comme trace de la source :
  /// les liens connus portent la donnée dans leur URL et sont décodés à la
  /// saisie, jamais rechargés.
  final String? sourceUrl;

  /// Rapport d'origine (collé, ou texte extrait d'un PDF) : permet de
  /// ré-analyser plus tard sans redemander le rapport.
  final String? rawText;

  /// `null` = **à analyser**. Distingue un rapport en attente d'extraction d'un
  /// diagnostic analysé **sans aucun défaut**, qui est une information en soi.
  final DateTime? analyzedAt;

  /// Verdict lisible (test de batterie, synthèse libre).
  final String? summary;

  /// Mesures d'un test de batterie — grandeurs variables selon le testeur.
  final Map<String, dynamic>? measurements;

  /// Calculateurs interrogés, **y compris ceux sans défaut** : c'est ce qui
  /// permet de distinguer un code disparu d'un code non revérifié.
  final List<String> modulesScanned;
  final String? notes;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  DiagnosticSession({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.updatedAt,
    this.createdByUserId,
    this.odometer,
    this.type = DiagnosticType.obd,
    this.tool,
    this.connectionProfile,
    this.source = DiagnosticSource.manual,
    this.sourceUrl,
    this.rawText,
    this.analyzedAt,
    this.summary,
    this.measurements,
    this.modulesScanned = const [],
    this.notes,
    this.deletedAt,
  }) : assert(odometer == null || odometer >= 0, 'odometer must be >= 0');

  /// Rapport reçu mais pas encore dépouillé (PDF en attente d'extraction, texte
  /// non reconnu). Un diagnostic analysé sans défaut n'est **pas** en attente.
  bool get isPendingAnalysis => analyzedAt == null && (rawText != null || sourceUrl != null);

  /// A-t-on interrogé [module] pendant cette session ? Comparaison insensible à
  /// la casse et aux espaces, les outils n'étant pas constants d'un rapport à
  /// l'autre.
  bool scanned(String module) {
    final needle = module.trim().toLowerCase();
    return modulesScanned.any((m) => m.trim().toLowerCase() == needle);
  }

  DiagnosticSession copyWith({
    DateTime? date,
    int? odometer,
    DiagnosticType? type,
    String? tool,
    String? connectionProfile,
    DiagnosticSource? source,
    String? sourceUrl,
    String? rawText,
    DateTime? analyzedAt,
    String? summary,
    Map<String, dynamic>? measurements,
    List<String>? modulesScanned,
    String? notes,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return DiagnosticSession(
      id: id,
      vehicleId: vehicleId,
      createdByUserId: createdByUserId,
      date: date ?? this.date,
      odometer: odometer ?? this.odometer,
      type: type ?? this.type,
      tool: tool ?? this.tool,
      connectionProfile: connectionProfile ?? this.connectionProfile,
      source: source ?? this.source,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      rawText: rawText ?? this.rawText,
      analyzedAt: analyzedAt ?? this.analyzedAt,
      summary: summary ?? this.summary,
      measurements: measurements ?? this.measurements,
      modulesScanned: modulesScanned ?? this.modulesScanned,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiagnosticSession && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
