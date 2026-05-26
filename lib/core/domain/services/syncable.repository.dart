/// Port générique d'accès à une ressource synchronisable offline-first.
/// Lectures depuis le store local ; écritures locales optimistes + mise en file.
abstract interface class SyncableRepository<T> {
  /// Toutes les entités (non supprimées) de la ressource, depuis le local.
  Future<List<T>> listAll();

  /// Entités (non supprimées) d'un véhicule, depuis le store local.
  Future<List<T>> listForVehicle(String vehicleId);
  Future<T?> getById(String id);

  /// Upsert local immédiat + mise en file de synchro.
  Future<void> save(T entity);

  /// Suppression logique (tombstone) locale + mise en file.
  Future<void> delete(T entity);
}
