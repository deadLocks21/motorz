import 'package:motorz/infrastructure/sync/pending_queue.dart';

/// Champs de métadonnée : gérés par le serveur ou structurels. Les exclure du
/// diff évite d'annoncer « 4 champs différents » quand seul `updated_at` bouge.
const _metaFields = {
  'id',
  'updated_at',
  'created_at',
  'deleted_at',
  'vehicle_id',
  'owner_user_id',
  'share_code',
  'created_by_user_id',
};

/// Une même entité modifiée des deux côtés pendant la déconnexion : la version
/// locale (encore en file, jamais poussée) et celle du serveur, plus récente.
///
/// Détecté **avant** le push : le serveur applique un last-write-wins muet
/// (cf. `applyRow` côté API), donc pousser sans demander ferait disparaître
/// l'une des deux versions sans que personne ne le sache.
class SyncConflict {
  final PendingOp local;
  final Map<String, dynamic> server;

  /// Champs dont la valeur diffère (hors métadonnées), triés pour un affichage
  /// stable d'un lancement à l'autre.
  final List<String> changedFields;

  SyncConflict({required this.local, required this.server})
      : changedFields = _diff(local.data, server);

  String get resource => local.resource;
  String get entityId => local.entityId;

  DateTime get localUpdatedAt => DateTime.parse(local.data['updated_at'] as String);
  DateTime get serverUpdatedAt => DateTime.parse(server['updated_at'] as String);

  /// Vrai quand la version locale supprime l'entité — le choix n'est plus
  /// « quels champs garder » mais « supprimer ou conserver ».
  bool get localDeletes => local.data['deleted_at'] != null;

  static List<String> _diff(Map<String, dynamic> local, Map<String, dynamic> server) {
    final keys = {...local.keys, ...server.keys}..removeAll(_metaFields);
    final changed = keys.where((k) => local[k] != server[k]).toList()..sort();
    return List.unmodifiable(changed);
  }
}

/// Ce que l'utilisateur décide pour un conflit.
enum ConflictChoice {
  /// Pousser la version locale : elle écrasera celle du serveur.
  keepLocal,

  /// Abandonner la saisie locale et adopter celle du serveur.
  keepServer,
}

// ── Libellés ────────────────────────────────────────────────────────────────

/// Nom lisible d'une ressource `/sync`, au singulier.
String resourceLabel(String resource) => switch (resource) {
      'vehicles' => 'Véhicule',
      'fuel_entries' => 'Plein',
      'maintenance_operations' => 'Opération',
      'maintenance_operation_lines' => 'Poste d\'opération',
      'maintenance_plans' => 'Échéance',
      'maintenance_quotes' => 'Devis',
      'tire_pressure_entries' => 'Relevé de pression',
      'target_pressures' => 'Pression cible',
      'tires' => 'Pneu',
      'tire_mounts' => 'Montage de pneu',
      'cost_entries' => 'Frais',
      'media' => 'Média',
      'ownerships' => 'Propriété',
      _ => resource,
    };

/// Intitulé de l'entité en conflit, tiré de la ligne « wire ». On préfère la
/// version serveur pour nommer (elle fait foi tant que rien n'est décidé) et on
/// retombe sur la locale si le champ n'y est pas.
String entityLabel(String resource, Map<String, dynamic> row, Map<String, dynamic> fallback) {
  String? pick(String key) {
    final v = row[key] ?? fallback[key];
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  final label = switch (resource) {
    'vehicles' => pick('nickname') ?? [pick('make'), pick('model')].nonNulls.join(' '),
    'fuel_entries' => _dated('Plein', pick('date')),
    'maintenance_operations' => pick('title') ?? _dated('Opération', pick('date')),
    'maintenance_operation_lines' => pick('label') ?? 'Poste d\'opération',
    'maintenance_plans' => pick('title') ?? 'Échéance',
    'maintenance_quotes' => pick('provider') ?? _dated('Devis', pick('date')),
    'tires' => [pick('brand'), pick('model')].nonNulls.join(' '),
    'cost_entries' => pick('label') ?? _dated('Frais', pick('date')),
    'media' => pick('file_name') ?? 'Média',
    _ => null,
  };
  final trimmed = label?.trim();
  return (trimmed == null || trimmed.isEmpty) ? resourceLabel(resource) : trimmed;
}

String _dated(String prefix, String? iso) {
  final date = iso == null ? null : DateTime.tryParse(iso);
  if (date == null) return prefix;
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$prefix du $d/$m/${date.year}';
}

/// Nom lisible d'un champ « wire ». Repli : la clé dé-`snake_case`-ée, ce qui
/// reste lisible pour les champs rares plutôt que d'imposer une table
/// exhaustive de 13 ressources.
String fieldLabel(String key) =>
    _fieldLabels[key] ??
    key.replaceAll('_', ' ').replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase());

const _fieldLabels = {
  'nickname': 'Surnom',
  'make': 'Marque',
  'model': 'Modèle',
  'year': 'Année',
  'trim': 'Finition',
  'vin': 'VIN',
  'license_plate': 'Plaque',
  'fuel_type': 'Carburant',
  'engine_cc': 'Cylindrée',
  'power_hp': 'Puissance',
  'odometer': 'Kilométrage',
  'date': 'Date',
  'volume_liters': 'Volume',
  'price_per_liter': 'Prix au litre',
  'total_cost': 'Coût total',
  'recurrence': 'Périodicité',
  'end_date': 'Fin',
  'station': 'Station',
  'notes': 'Notes',
  'note': 'Note',
  'title': 'Intitulé',
  'label': 'Intitulé',
  'provider': 'Prestataire',
  'brand': 'Marque',
  'file_name': 'Fichier',
};
