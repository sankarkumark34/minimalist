import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../glass.dart';
import '../theme.dart';

class SummaryScreen extends StatelessWidget {
  final int durationMinutes;
  final int blockedCount;

  const SummaryScreen({
    super.key,
    required this.durationMinutes,
    required this.blockedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withAlpha(56),
                      blurRadius: 48,
                    ),
                  ],
                ),
                child: const Icon(Icons.check_circle_outline,
                        size: 72, color: AppColors.accentBright)
                    .animate()
                    .scale(
                        begin: const Offset(0.6, 0.6),
                        duration: 500.ms,
                        curve: Curves.easeOutBack)
                    .fadeIn(duration: 300.ms),
              ),
              const SizedBox(height: 28),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, AppColors.inkDim],
                ).createShader(bounds),
                child: const Text('Session complete',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w300,
                        color: Colors.white)),
              ),
              const SizedBox(height: 40),
              GlassPanel(
                radius: 24,
                high: true,
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Stat(value: '$durationMinutes', label: 'minutes focused'),
                    Container(
                      width: 1,
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 36),
                      color: AppColors.glassBorder,
                    ),
                    _Stat(value: '$blockedCount', label: 'apps blocked'),
                  ],
                ),
              ),
              const Spacer(),
              GlossyButton(
                label: 'Done',
                height: 56,
                onPressed: () => context.go('/'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, AppColors.accentBright],
          ).createShader(bounds),
          child: Text(value,
              style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w200,
                  color: Colors.white)),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.inkDim)),
      ],
    );
  }
}
