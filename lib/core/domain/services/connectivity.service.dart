/// Port de connectivité réseau. La synchro s'abonne à [watch].
abstract interface class ConnectivityService {
  bool get isOnline;

  /// Émet l'état courant immédiatement, puis à chaque changement.
  Stream<bool> watch();
}
