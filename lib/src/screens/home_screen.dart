import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../channel.dart';
import '../glass.dart';
import '../providers.dart';
import '../theme.dart';

const _durations = [10, 15, 25, 45, 60, 90, 120];

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final perms = await FocusChannel.checkPermissions();
    if (perms['accessibility'] != true) {
      if (!context.mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xF01A1D2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.glassBorder),
          ),
          title: const Text('One-time setup'),
          content: const Text(
            'minimalist needs the Accessibility permission to detect and '
            'block distracting apps. Nothing leaves your device.\n\n'
            'On the next screen, enable "minimalist".',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not now',
                    style: TextStyle(color: AppColors.inkDim))),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.bgBottom),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Open settings')),
          ],
        ),
      );
      if (go == true) await FocusChannel.openAccessibilitySettings();
      return;
    }
    if (perms['notifications'] != true) {
      await FocusChannel.requestNotificationPermission();
    }

    final minutes = ref.read(durationProvider);
    final blocked = ref.read(blockedAppsProvider);
    if (blocked.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Choose at least one app to block first')));
      return;
    }
    await FocusChannel.startFocusSession(
      durationMinutes: minutes,
      blockedPackages: blocked.toList(),
    );
    if (!context.mounted) return;
    context.go('/session', extra: {
      'endTime': DateTime.now().add(Duration(minutes: minutes)),
      'durationMinutes': minutes,
      'blockedCount': blocked.length,
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minutes = ref.watch(durationProvider);
    final blocked = ref.watch(blockedAppsProvider);
    final history = ref.watch(historyProvider);
    final totalFocused = history
        .where((r) => r.completed)
        .fold<int>(0, (sum, r) => sum + r.durationMinutes);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.ink, AppColors.inkDim],
                ).createShader(bounds),
                child: const Text('minimalist',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 4,
                        color: Colors.white)),
              ),
              const Spacer(),
              Center(
                child: GlassPanel(
                  radius: 32,
                  high: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, AppColors.accentBright],
                        ).createShader(bounds),
                        child: Text('$minutes',
                                style: const TextStyle(
                                    fontSize: 96,
                                    fontWeight: FontWeight.w200,
                                    height: 1,
                                    color: Colors.white))
                            .animate(key: ValueKey(minutes))
                            .fadeIn(duration: 200.ms),
                      ),
                      const Text('minutes',
                          style: TextStyle(
                              fontSize: 14,
                              letterSpacing: 3,
                              color: AppColors.inkDim)),
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final d in _durations)
                            _DurationChip(
                              minutes: d,
                              selected: d == minutes,
                              onTap: () =>
                                  ref.read(durationProvider.notifier).set(d),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              GlassPanel(
                radius: 18,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                onTap: () => context.push('/apps'),
                child: Row(
                  children: [
                    const Icon(Icons.block, size: 20, color: AppColors.accent),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        blocked.isEmpty
                            ? 'Choose apps to block'
                            : '${blocked.length} app${blocked.length == 1 ? '' : 's'} blocked',
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.ink),
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 20, color: AppColors.inkFaint),
                  ],
                ),
              ),
              if (totalFocused > 0) ...[
                const SizedBox(height: 10),
                GlassPanel(
                  radius: 18,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.self_improvement,
                          size: 20, color: AppColors.inkDim),
                      const SizedBox(width: 14),
                      Text(
                        '${(totalFocused / 60).floor()}h ${totalFocused % 60}m focused all-time',
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              GlossyButton(
                label: 'Begin Focus',
                onPressed: () => _start(context, ref),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  const _DurationChip(
      {required this.minutes, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.accentBright, AppColors.accentDeep],
                )
              : const LinearGradient(
                  colors: [AppColors.glassFill, AppColors.glassFill]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.accentBright.withAlpha(153)
                : AppColors.glassBorder,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withAlpha(64),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text('$minutes',
            style: TextStyle(
                color: selected ? AppColors.bgBottom : AppColors.inkDim,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }
}
