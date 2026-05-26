import 'package:shared_preferences/shared_preferences.dart';

/// Curseur de synchro delta (`server_time` du dernier pull).
abstract interface class SyncCursorStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPrefsSyncCursorStore implements SyncCursorStore {
  static const _key = 'motorz.sync_cursor';
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<String?> read() async => (await _prefs).getString(_key);

  @override
  Future<void> write(String value) async => (await _prefs).setString(_key, value);
}

class InMemorySyncCursorStore implements SyncCursorStore {
  String? _value;
  @override
  Future<String?> read() async => _value;
  @override
  Future<void> write(String value) async => _value = value;
}
