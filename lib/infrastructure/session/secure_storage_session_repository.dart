import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:motorz/core/domain/model/device.dart';
import 'package:motorz/core/domain/model/session.dart';
import 'package:motorz/core/domain/model/user.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/services/session.repository.dart';
import 'package:uuid/uuid.dart' show Uuid;

/// Session persistée dans `flutter_secure_storage` (JWT chiffré au repos).
/// L'identifiant d'appareil est conservé même après déconnexion.
class SecureStorageSessionRepository implements SessionRepository {
  static const _kJwt = 'motorz.jwt';
  static const _kUser = 'motorz.user';
  static const _kDeviceId = 'motorz.device_id';
  static const _kDeviceName = 'motorz.device_name';

  final FlutterSecureStorage _storage;
  SecureStorageSessionRepository({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              // macOS : la signature de dev est ad-hoc (sans équipe), donc le
              // *data protection keychain* n'a pas d'access-group résoluble et
              // l'écriture échoue (errSecMissingEntitlement). On bascule sur le
              // keychain legacy, qui fonctionne sous sandbox sans préfixe
              // d'équipe. macOS n'est pas une cible de distribution (Android only).
              mOptions: MacOsOptions(usesDataProtectionKeychain: false),
            );

  @override
  Future<Session?> read() async {
    final jwt = await _storage.read(key: _kJwt);
    final userJson = await _storage.read(key: _kUser);
    final deviceId = await _storage.read(key: _kDeviceId);
    if (jwt == null || userJson == null || deviceId == null) return null;
    final u = jsonDecode(userJson) as Map<String, dynamic>;
    return Session(
      jwt: jwt,
      user: User(
        id: UuidValue.parse(u['id'] as String),
        firstName: u['first_name'] as String,
        lastName: u['last_name'] as String,
        phoneNumber: u['phone_number'] as String,
        isAdmin: (u['is_admin'] as bool?) ?? false,
      ),
      device: Device(id: deviceId, name: await _storage.read(key: _kDeviceName)),
    );
  }

  @override
  Future<void> write(Session session) async {
    await _storage.write(key: _kJwt, value: session.jwt);
    await _storage.write(
      key: _kUser,
      value: jsonEncode({
        'id': session.user.id.value,
        'first_name': session.user.firstName,
        'last_name': session.user.lastName,
        'phone_number': session.user.phoneNumber,
        'is_admin': session.user.isAdmin,
      }),
    );
    await _storage.write(key: _kDeviceId, value: session.device.id);
    final name = session.device.name;
    if (name != null) {
      await _storage.write(key: _kDeviceName, value: name);
    } else {
      await _storage.delete(key: _kDeviceName);
    }
  }

  @override
  Future<void> clear() async {
    // Préserve l'identifiant d'appareil.
    await _storage.delete(key: _kJwt);
    await _storage.delete(key: _kUser);
  }

  @override
  Future<Device> readOrCreateDevice() async {
    final existing = await _storage.read(key: _kDeviceId);
    if (existing != null) {
      return Device(id: existing, name: await _storage.read(key: _kDeviceName));
    }
    final created = Device(id: const Uuid().v4());
    await _storage.write(key: _kDeviceId, value: created.id);
    return created;
  }
}

/// Session en mémoire (tests/web).
class InMemorySessionRepository implements SessionRepository {
  Session? _session;
  Device? _device;

  @override
  Future<Session?> read() async => _session;

  @override
  Future<void> write(Session session) async {
    _session = session;
    _device = session.device;
  }

  @override
  Future<void> clear() async => _session = null;

  @override
  Future<Device> readOrCreateDevice() async => _device ??= Device(id: const Uuid().v4());
}
