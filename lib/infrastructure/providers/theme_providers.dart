import 'package:motorz/core/domain/model/app_theme_mode.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_providers.g.dart';

/// Mode de thème (clair/sombre/système), persisté dans `shared_preferences`.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  static const _prefKey = 'motorz.theme_mode';

  @override
  Future<AppThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AppThemeMode.fromName(prefs.getString(_prefKey));
  }

  Future<void> set(AppThemeMode mode) async {
    await (await SharedPreferences.getInstance()).setString(_prefKey, mode.name);
    state = AsyncData(mode);
  }
}
