import 'package:motorz/core/domain/model/device.dart';
import 'package:motorz/core/domain/model/session.dart';

/// Persistance de la session (JWT + user + device) — `flutter_secure_storage`.
abstract interface class SessionRepository {
  Future<Session?> read();
  Future<void> write(Session session);
  Future<void> clear();

  /// Lit l'identifiant d'appareil persistant, ou en crée un (UUID v4) au
  /// premier lancement. Préservé même après déconnexion.
  Future<Device> readOrCreateDevice();
}
