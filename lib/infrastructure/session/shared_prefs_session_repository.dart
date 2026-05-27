import 'dart:convert';

import 'package:motorz/core/domain/model/device.dart';
import 'package:motorz/core/domain/model/session.dart';
import 'package:motorz/core/domain/model/user.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/services/session.repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart' show Uuid;

/// Session persistée dans `shared_preferences` (stockage local **non chiffré**).
/// L'identifiant d'appareil est conservé même après déconnexion.
class SharedPreferencesSessionRepository implements SessionRepository {
  static const _kJwt = 'motorz.jwt';
  static const _kUser = 'motorz.user';
  static const _kDeviceId = 'motorz.device_id';
  static const _kDeviceName = 'motorz.device_name';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<Session?> read() async {
    final prefs = await _prefs;
    final jwt = prefs.getString(_kJwt);
    final userJson = prefs.getString(_kUser);
    final deviceId = prefs.getString(_kDeviceId);
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
      device: Device(id: deviceId, name: prefs.getString(_kDeviceName)),
    );
  }

  @override
  Future<void> write(Session session) async {
    final prefs = await _prefs;
    await prefs.setString(_kJwt, session.jwt);
    await prefs.setString(
      _kUser,
      jsonEncode({
        'id': session.user.id.value,
        'first_name': session.user.firstName,
        'last_name': session.user.lastName,
        'phone_number': session.user.phoneNumber,
        'is_admin': session.user.isAdmin,
      }),
    );
    await prefs.setString(_kDeviceId, session.device.id);
    final name = session.device.name;
    if (name != null) {
      await prefs.setString(_kDeviceName, name);
    } else {
      await prefs.remove(_kDeviceName);
    }
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs;
    // Préserve l'identifiant d'appareil.
    await prefs.remove(_kJwt);
    await prefs.remove(_kUser);
  }

  @override
  Future<Device> readOrCreateDevice() async {
    final prefs = await _prefs;
    final existing = prefs.getString(_kDeviceId);
    if (existing != null) {
      return Device(id: existing, name: prefs.getString(_kDeviceName));
    }
    final created = Device(id: const Uuid().v4());
    await prefs.setString(_kDeviceId, created.id);
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
