import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.check_circle_outline,
                      size: 72, color: AppColors.accent)
                  .animate()
                  .scale(
                      begin: const Offset(0.6, 0.6),
                      duration: 500.ms,
                      curve: Curves.easeOutBack)
                  .fadeIn(duration: 300.ms),
              const SizedBox(height: 28),
              const Text('Session complete',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w300,
                      color: AppColors.ink)),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Stat(value: '$durationMinutes', label: 'minutes focused'),
                  const SizedBox(width: 48),
                  _Stat(value: '$blockedCount', label: 'apps blocked'),
                ],
              ),
              const Spacer(),
              SizedBox(
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.ink,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: () => context.go('/'),
                  child: const Text('Done'),
                ),
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
        Text(value,
            style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w200,
                color: AppColors.ink)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.inkDim)),
      ],
    );
  }
}
