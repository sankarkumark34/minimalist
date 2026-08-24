import 'package:flutter/material.dart';

/// Minimal dark palette — near-black canvas, soft off-white ink,
/// a single warm accent used sparingly.
abstract final class AppColors {
  static const bg = Color(0xFF0C0C0E);
  static const surface = Color(0xFF16161A);
  static const surfaceHigh = Color(0xFF1F1F24);
  static const ink = Color(0xFFEDEDEF);
  static const inkDim = Color(0xFF8A8A93);
  static const inkFaint = Color(0xFF4A4A52);
  static const accent = Color(0xFFE8C36A);
  static const danger = Color(0xFFE86A6A);
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.bg,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      secondary: AppColors.inkDim,
      error: AppColors.danger,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
      fontFamily: 'Roboto',
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: AppColors.ink,
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.surfaceHigh),
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.bg
              : AppColors.inkDim),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.surfaceHigh),
  );
}
