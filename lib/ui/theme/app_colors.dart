// Motorz — Tokens de couleur « Motorsport » (graphite · orange signal).
// Pattern kidflix : palette brute + ThemeExtension `AppColors` + `context.appColors`.

import 'package:flutter/material.dart';

/// Palette brute (tokens bas niveau). Ne pas utiliser directement dans l'UI :
/// toujours passer par [AppColors] / `context.appColors`.
abstract final class MotorzPalette {
  // Neutres graphite
  static const graphite900 = Color(0xFF0C0D11); // fond (sombre)
  static const graphite800 = Color(0xFF15171D); // surface (sombre)
  static const graphite700 = Color(0xFF1B1E26); // surface élevée (sombre)
  static const graphite600 = Color(0xFF23262E); // outline (sombre)
  static const ink = Color(0xFF14161B); // texte principal (clair)
  static const inkInverse = Color(0xFFECEEF2); // texte principal (sombre)
  static const slate = Color(0xFF5E6470); // texte atténué (clair)
  static const slateInverse = Color(0xFF888F9D); // texte atténué (sombre)
  static const cloud = Color(0xFFF2F3F5); // fond (clair)
  static const mist = Color(0xFFF7F8FA); // surface élevée (clair)
  static const white = Color(0xFFFFFFFF); // surface (clair)
  static const line = Color(0xFFE4E6EA); // outline (clair)

  // Orange signal — accent de marque
  static const orange = Color(0xFFFF5A1F); // accent (clair)
  static const orangeBright = Color(0xFFFF6A2C); // accent (sombre)
  static const orangeSoft = Color(0xFFFFE3D6); // container (clair)
  static const orangeDeep = Color(0xFFB23E10); // texte sur container (clair)
  static const orangeSoftDark = Color(0xFF3A2412); // container (sombre)
  static const orangeOnDark = Color(0xFFFF9B66); // texte sur container (sombre)
  static const onOrangeDark = Color(0xFF160A04); // texte sur orange (sombre)

  // Statuts d'échéance (à jour / bientôt dû / en retard)
  static const ok = Color(0xFF27C281);
  static const soon = Color(0xFFFFB020);
  static const overdue = Color(0xFFFF4D4F);
}

/// Tokens sémantiques exposés à l'UI via `context.appColors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.outline,
    required this.textPrimary,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.statusOk,
    required this.statusSoon,
    required this.statusOverdue,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color outline;
  final Color textPrimary;
  final Color textMuted;
  final Color accent; // orange signal — couleur d'action principale
  final Color onAccent;
  final Color accentSoft; // fond doux orange (pastilles, containers)
  final Color onAccentSoft;
  final Color statusOk;
  final Color statusSoon;
  final Color statusOverdue;

  static const AppColors light = AppColors(
    background: MotorzPalette.cloud,
    surface: MotorzPalette.white,
    surfaceAlt: MotorzPalette.mist,
    outline: MotorzPalette.line,
    textPrimary: MotorzPalette.ink,
    textMuted: MotorzPalette.slate,
    accent: MotorzPalette.orange,
    onAccent: MotorzPalette.white,
    accentSoft: MotorzPalette.orangeSoft,
    onAccentSoft: MotorzPalette.orangeDeep,
    statusOk: MotorzPalette.ok,
    statusSoon: MotorzPalette.soon,
    statusOverdue: MotorzPalette.overdue,
  );

  static const AppColors dark = AppColors(
    background: MotorzPalette.graphite900,
    surface: MotorzPalette.graphite800,
    surfaceAlt: MotorzPalette.graphite700,
    outline: MotorzPalette.graphite600,
    textPrimary: MotorzPalette.inkInverse,
    textMuted: MotorzPalette.slateInverse,
    accent: MotorzPalette.orangeBright,
    onAccent: MotorzPalette.onOrangeDark,
    accentSoft: MotorzPalette.orangeSoftDark,
    onAccentSoft: MotorzPalette.orangeOnDark,
    statusOk: MotorzPalette.ok,
    statusSoon: MotorzPalette.soon,
    statusOverdue: MotorzPalette.overdue,
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? outline,
    Color? textPrimary,
    Color? textMuted,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? onAccentSoft,
    Color? statusOk,
    Color? statusSoon,
    Color? statusOverdue,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      outline: outline ?? this.outline,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccentSoft: onAccentSoft ?? this.onAccentSoft,
      statusOk: statusOk ?? this.statusOk,
      statusSoon: statusSoon ?? this.statusSoon,
      statusOverdue: statusOverdue ?? this.statusOverdue,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccentSoft: Color.lerp(onAccentSoft, other.onAccentSoft, t)!,
      statusOk: Color.lerp(statusOk, other.statusOk, t)!,
      statusSoon: Color.lerp(statusSoon, other.statusSoon, t)!,
      statusOverdue: Color.lerp(statusOverdue, other.statusOverdue, t)!,
    );
  }
}

/// Raccourci d'accès : `context.appColors.accent`.
extension AppColorsX on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

/// Schémas Material 3 — orange = `primary`, graphite = neutre fort.
final ColorScheme motorzLightScheme = ColorScheme.fromSeed(
  seedColor: MotorzPalette.orange,
  brightness: Brightness.light,
).copyWith(
  primary: MotorzPalette.orange,
  onPrimary: MotorzPalette.white,
  primaryContainer: MotorzPalette.orangeSoft,
  onPrimaryContainer: MotorzPalette.orangeDeep,
  secondary: MotorzPalette.ink,
  onSecondary: MotorzPalette.white,
  surface: MotorzPalette.white,
  onSurface: MotorzPalette.ink,
  outline: MotorzPalette.line,
  error: MotorzPalette.overdue,
);

final ColorScheme motorzDarkScheme = ColorScheme.fromSeed(
  seedColor: MotorzPalette.orange,
  brightness: Brightness.dark,
).copyWith(
  primary: MotorzPalette.orangeBright,
  onPrimary: MotorzPalette.onOrangeDark,
  primaryContainer: MotorzPalette.orangeSoftDark,
  onPrimaryContainer: MotorzPalette.orangeOnDark,
  secondary: MotorzPalette.inkInverse,
  onSecondary: MotorzPalette.graphite900,
  surface: MotorzPalette.graphite800,
  onSurface: MotorzPalette.inkInverse,
  outline: MotorzPalette.graphite600,
  error: MotorzPalette.overdue,
);
