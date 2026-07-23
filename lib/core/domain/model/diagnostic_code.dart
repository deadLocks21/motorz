import 'package:motorz/core/domain/model/uuid_value.dart';

/// Ce que l'outil dit du défaut **au moment de la lecture**.
enum DiagnosticCodeStatus {
  pending,
  confirmed,
  permanent,
  unknown;

  String get wire => name;
  static DiagnosticCodeStatus fromWire(String? w) =>
      DiagnosticCodeStatus.values.where((e) => e.name == w).firstOrNull ??
      DiagnosticCodeStatus.unknown;

  String get label => switch (this) {
    DiagnosticCodeStatus.pending => 'En attente',
    DiagnosticCodeStatus.confirmed => 'Confirmé',
    DiagnosticCodeStatus.permanent => 'Permanent',
    DiagnosticCodeStatus.unknown => 'Statut inconnu',
  };
}

/// Un code défaut tel que remonté par **un** calculateur.
///
/// Un même code vu par plusieurs modules donne plusieurs instances : on reste
/// fidèle au rapport, c'est l'affichage qui regroupe par [code] (§5.11).
class DiagnosticCode {
  final UuidValue id;
  final UuidValue sessionId;

  /// Normalisé en majuscules sans espace (`P2291`) — cf. [normalizeCode].
  final String code;

  /// Calculateur qui remonte le code (« Unité de contrôle moteur#1 », « ABS »).
  final String? module;

  /// Description telle que fournie par l'outil : pas de catalogue embarqué, les
  /// codes constructeur n'étant de toute façon pas normalisés.
  final String? description;
  final DiagnosticCodeStatus status;

  /// Libellé d'origine du statut (« En attente de défaut présent ») : garde la
  /// nuance d'un outil qu'on ne sait pas encore normaliser.
  final String? rawStatus;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  DiagnosticCode({
    required this.id,
    required this.sessionId,
    required this.code,
    required this.updatedAt,
    this.module,
    this.description,
    this.status = DiagnosticCodeStatus.unknown,
    this.rawStatus,
    this.deletedAt,
  });

  /// Forme canonique d'un code : majuscules, sans espace ni séparateur. Sert de
  /// clé de regroupement — `p2291` et `P 2291` sont le même défaut.
  static String normalizeCode(String raw) =>
      raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// Forme hexadécimale affichée par certains outils (`P2291` → `0x2291`).
  /// **Dérivée**, jamais stockée : c'est une réécriture du code, pas une donnée.
  String? get hex {
    final m = RegExp(r'^[PBCU]([0-9A-F]{4})$').firstMatch(code);
    return m == null ? null : '0x${m.group(1)}';
  }

  /// Domaine du code, d'après sa première lettre.
  String get domainLabel => switch (code.isEmpty ? '' : code[0]) {
    'P' => 'Moteur / transmission',
    'B' => 'Carrosserie',
    'C' => 'Châssis',
    'U' => 'Réseau',
    _ => 'Inconnu',
  };

  DiagnosticCode copyWith({
    String? code,
    String? module,
    String? description,
    DiagnosticCodeStatus? status,
    String? rawStatus,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return DiagnosticCode(
      id: id,
      sessionId: sessionId,
      code: code ?? this.code,
      module: module ?? this.module,
      description: description ?? this.description,
      status: status ?? this.status,
      rawStatus: rawStatus ?? this.rawStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiagnosticCode && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
