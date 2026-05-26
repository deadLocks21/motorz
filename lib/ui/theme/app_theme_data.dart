import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:motorz/core/domain/model/app_theme_mode.dart';
import 'package:motorz/ui/theme/app_colors.dart';

/// Assemble les thèmes Material 3 clair/sombre de Motorz (pattern kidflix :
/// `abstract final class` + ColorScheme + ThemeExtension `AppColors` + styles
/// de boutons centralisés). Typo : **Archivo** (via google_fonts).
abstract final class AppThemeData {
  static ThemeData buildLightTheme() => _build(motorzLightScheme, AppColors.light, Brightness.light);
  static ThemeData buildDarkTheme() => _build(motorzDarkScheme, AppColors.dark, Brightness.dark);

  static ThemeMode toFlutterThemeMode(AppThemeMode mode) => switch (mode) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };

  static ThemeData _build(ColorScheme scheme, AppColors colors, Brightness brightness) {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
    final textTheme = GoogleFonts.archivoTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: colors.background,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.archivo(
          textStyle: TextStyle(
            color: colors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outline),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          minimumSize: const Size(0, 52),
          textStyle: GoogleFonts.archivo(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          minimumSize: const Size(0, 52),
          side: BorderSide(color: colors.outline),
          textStyle: GoogleFonts.archivo(fontWeight: FontWeight.w600, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.accent, width: 2),
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.outline, space: 1, thickness: 1),
    );
  }
}
