import 'package:flutter/material.dart';

/// Liquid-glass palette — deep midnight canvas with cool depth lighting,
/// translucent frosted surfaces, and a polished gold accent.
abstract final class AppColors {
  // Canvas depth gradient
  static const bgTop = Color(0xFF101322);
  static const bgMid = Color(0xFF0B0D18);
  static const bgBottom = Color(0xFF07080F);

  // Ambient glow orbs behind the glass
  static const glowGold = Color(0x33E8C36A);
  static const glowBlue = Color(0x2E5B7FE8);
  static const glowViolet = Color(0x268B5BE8);

  // Glass surfaces
  static const glassFill = Color(0x14FFFFFF); // 8% white
  static const glassFillHigh = Color(0x1FFFFFFF); // 12% white
  static const glassBorder = Color(0x2EFFFFFF); // 18% white
  static const glassSheen = Color(0x40FFFFFF); // top edge highlight

  // Ink
  static const ink = Color(0xFFF2F3F7);
  static const inkDim = Color(0xFF9BA0B0);
  static const inkFaint = Color(0xFF565B6E);

  // Accent: polished gold
  static const accent = Color(0xFFE8C36A);
  static const accentBright = Color(0xFFF6DFA0);
  static const accentDeep = Color(0xFFC99B3F);
  static const danger = Color(0xFFE86A6A);
}

/// Full-bleed background: vertical depth gradient with soft glow orbs,
/// so the frosted glass panels have something to refract.
class LiquidBackground extends StatelessWidget {
  final Widget child;

  const LiquidBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bgTop, AppColors.bgMid, AppColors.bgBottom],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: -120,
            right: -80,
            child: _GlowOrb(color: AppColors.glowGold, size: 340),
          ),
          const Positioned(
            top: 260,
            left: -140,
            child: _GlowOrb(color: AppColors.glowBlue, size: 380),
          ),
          const Positioned(
            bottom: -160,
            right: -60,
            child: _GlowOrb(color: AppColors.glowViolet, size: 360),
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
              ? AppColors.accent
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
      backgroundColor: Color(0xE61F2233),
      contentTextStyle: TextStyle(color: AppColors.ink),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
