/// Mode de thème choisi par l'utilisateur (persisté). Mappé vers `ThemeMode`
/// Flutter par `AppThemeData.toFlutterThemeMode`.
enum AppThemeMode {
  light,
  dark,
  system;

  static AppThemeMode fromName(String? name) =>
      AppThemeMode.values.where((m) => m.name == name).firstOrNull ?? AppThemeMode.system;
}
