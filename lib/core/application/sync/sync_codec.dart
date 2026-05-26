/// Codec d'une entité synchronisable : conversion domaine ↔ JSON « wire »
/// (forme sérialisée par l'API) + extracteurs utilisés par le store local et
/// la file de synchro. Le JSON porte toujours `id`, `updated_at`, `deleted_at`
/// (et `vehicle_id` pour les sous-ressources).
class SyncCodec<T> {
  /// Nom de la ressource côté `/sync` (ex. `fuel_entries`).
  final String resource;
  final Map<String, dynamic> Function(T entity) toJson;
  final T Function(Map<String, dynamic> json) fromJson;
  final String Function(T entity) idOf;
  final String? Function(T entity) vehicleIdOf;
  final DateTime Function(T entity) updatedAtOf;
  final DateTime? Function(T entity) deletedAtOf;

  const SyncCodec({
    required this.resource,
    required this.toJson,
    required this.fromJson,
    required this.idOf,
    required this.vehicleIdOf,
    required this.updatedAtOf,
    required this.deletedAtOf,
  });
}

// ── Helpers JSON partagés ───────────────────────────────────────────────────

String? isoOrNull(DateTime? d) => d?.toUtc().toIso8601String();
DateTime parseDate(Object? v) => DateTime.parse(v as String);
DateTime? parseDateOrNull(Object? v) => v == null ? null : DateTime.parse(v as String);
int? intOrNull(Object? v) => v == null ? null : (v as num).toInt();
double? doubleOrNull(Object? v) => v == null ? null : (v as num).toDouble();
