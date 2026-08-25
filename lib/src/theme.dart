import 'package:flutter/material.dart';

/// Azure liquid-glass palette — vivid blue canvas with soft ambient blobs,
/// bright white frosted surfaces, glossy white-glass accents.
abstract final class AppColors {
  // Canvas depth gradient (light azure -> deep azure)
  static const bgTop = Color(0xFF6FA8EC);
  static const bgMid = Color(0xFF3273D9);
  static const bgBottom = Color(0xFF1D55B8);

  // Ambient glow blobs behind the glass
  static const glowPeach = Color(0x59F5CDB0);
  static const glowSky = Color(0x66C9E2FA);
  static const glowDeep = Color(0x40123E8F);

  // Glass surfaces (white frost on blue)
  static const glassFill = Color(0x24FFFFFF); // 14% white
  static const glassFillHigh = Color(0x38FFFFFF); // 22% white
  static const glassBorder = Color(0x59FFFFFF); // 35% white
  static const glassSheen = Color(0x8CFFFFFF); // top edge highlight

  // Ink
  static const ink = Colors.white;
  static const inkDim = Color(0xFFD3E4F8);
  static const inkFaint = Color(0xFF9DBCE8);

  // Accent: polished white glass
  static const accent = Color(0xFFEAF3FF);
  static const accentBright = Color(0xFFFFFFFF);
  static const accentDeep = Color(0xFFB9D4F3);
  static const danger = Color(0xFFFF9E8F);
}

/// Full-bleed background: azure depth gradient with soft glow blobs,
/// so the frosted glass panels have something to refract.
class LiquidBackground extends StatelessWidget {
  final Widget child;

  const LiquidBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.bgTop, AppColors.bgMid, AppColors.bgBottom],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: -120,
            left: -100,
            child: _GlowOrb(color: AppColors.glowSky, size: 420),
          ),
          const Positioned(
            bottom: -140,
            left: -120,
            child: _GlowOrb(color: AppColors.glowPeach, size: 400),
          ),
          const Positioned(
            top: 220,
            right: -160,
            child: _GlowOrb(color: AppColors.glowDeep, size: 420),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withAlpha(0)]),
      ),
    );
  }
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.bgBottom,
      surface: AppColors.bgMid,
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
              ? AppColors.accentBright
              : AppColors.glassFill),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.accentDeep
              : AppColors.glassBorder),
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.bgBottom
              : AppColors.inkDim),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.glassBorder),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xE62B63C4),
      contentTextStyle: TextStyle(color: AppColors.ink),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
