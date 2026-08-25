import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Frosted glass panel: backdrop blur, translucent fill, hairline border
/// and a specular sheen along the top edge.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool high;

  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.high = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: high
                    ? [AppColors.glassFillHigh, AppColors.glassFill]
                    : [AppColors.glassFill, const Color(0x14FFFFFF)],
              ),
              border: Border.all(color: AppColors.glassBorder, width: 1),
            ),
            child: InkWell(
              borderRadius: borderRadius,
              onTap: onTap,
              splashColor: AppColors.glassSheen,
              highlightColor: AppColors.glassFill,
              child: Stack(
                children: [
                  // Specular top-edge highlight
                  Positioned(
                    top: 0,
                    left: radius,
                    right: radius,
                    child: Container(
                      height: 1.2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppColors.glassSheen.withAlpha(0),
                          AppColors.glassSheen,
                          AppColors.glassSheen.withAlpha(0),
                        ]),
                      ),
                    ),
                  ),
                  Padding(padding: padding, child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Polished, reflective pill button — vertical gold gradient with a
/// glossy top highlight, soft glow shadow, pressed-state depth.
class GlossyButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final double height;
  final bool primary;

  const GlossyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 60,
    this.primary = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: primary
            ? [
                BoxShadow(
                  color: AppColors.accent.withAlpha(64),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: primary
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.accentBright,
                          AppColors.accent,
                          AppColors.accentDeep,
                        ],
                        stops: [0.0, 0.45, 1.0],
                      )
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.glassFillHigh, AppColors.glassFill],
                      ),
                border: Border.all(
                  color: primary
                      ? AppColors.accentBright.withAlpha(140)
                      : AppColors.glassBorder,
                  width: 1,
                ),
              ),
              child: InkWell(
                borderRadius: radius,
                onTap: onPressed,
                child: Stack(
                  children: [
                    // Glossy upper-half reflection
                    Positioned(
                      top: 2,
                      left: 8,
                      right: 8,
                      height: height * 0.42,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(height / 2),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withAlpha(primary ? 97 : 31),
                              Colors.white.withAlpha(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                          color: primary ? AppColors.bgBottom : AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
