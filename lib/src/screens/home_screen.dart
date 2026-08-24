import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../channel.dart';
import '../glass.dart';
import '../providers.dart';
import '../theme.dart';

const _durations = [10, 15, 25, 45, 60, 90, 120];

String _fmtDuration(int minutes) {
  if (minutes < 60) return '$minutes';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

Future<void> _pickCustom(
    BuildContext context, WidgetRef ref, int current) async {
  var hours = (current ~/ 60).clamp(0, 24);
  var mins = current % 60;
  final hoursCtl = TextEditingController(text: '$hours');
  final minsCtl = TextEditingController(text: '$mins');
  final picked = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xF0141728),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      side: BorderSide(color: AppColors.glassBorder),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final total = (hours * 60 + mins).clamp(0, 1440);

        void syncFields() {
          hoursCtl.text = '$hours';
          minsCtl.text = '$mins';
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Custom duration',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: AppColors.ink)),
              const SizedBox(height: 8),
              Text(
                total > 90
                    ? 'Sessions over 1.5h can be ended early.'
                    : 'Sessions up to 1.5h are locked until the timer ends.',
                style: const TextStyle(fontSize: 13, color: AppColors.inkDim),
              ),
              const SizedBox(height: 20),
              // Type it in directly — sliders below stay in sync.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _TimeField(
                    controller: hoursCtl,
                    label: 'hours',
                    max: 24,
                    onChanged: (v) => setSheet(() => hours = v),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(':',
                        style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w200,
                            color: AppColors.inkDim)),
                  ),
                  _TimeField(
                    controller: minsCtl,
                    label: 'minutes',
                    max: 59,
                    onChanged: (v) => setSheet(() => mins = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(
                      width: 64,
                      child: Text('Hours',
                          style: TextStyle(color: AppColors.inkDim))),
                  Expanded(
                    child: Slider(
                      value: hours.toDouble(),
                      min: 0,
                      max: 24,
                      divisions: 24,
                      activeColor: AppColors.accent,
                      inactiveColor: AppColors.glassBorder,
                      label: '${hours}h',
                      onChanged: (v) => setSheet(() {
                        hours = v.round();
                        syncFields();
                      }),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const SizedBox(
                      width: 64,
                      child: Text('Minutes',
                          style: TextStyle(color: AppColors.inkDim))),
                  Expanded(
                    child: Slider(
                      value: mins.toDouble(),
                      min: 0,
                      max: 59,
                      divisions: 59,
                      activeColor: AppColors.accent,
                      inactiveColor: AppColors.glassBorder,
                      label: '${mins}m',
                      onChanged: (v) => setSheet(() {
                        mins = v.round();
                        syncFields();
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GlossyButton(
                label: total == 0
                    ? 'Pick a duration'
                    : 'Set ${_fmtDuration(total)}',
                height: 52,
                onPressed:
                    total == 0 ? () {} : () => Navigator.pop(ctx, total),
              ),
            ],
          ),
        );
      },
    ),
  );
  hoursCtl.dispose();
  minsCtl.dispose();
  if (picked != null && picked > 0) {
    ref.read(durationProvider.notifier).set(picked);
  }
}

/// Glass number field for typing hours/minutes directly.
class _TimeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int max;
  final ValueChanged<int> onChanged;

  const _TimeField({
    required this.controller,
    required this.label,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.glassFillHigh, AppColors.glassFill],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 2,
            style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w200,
                color: AppColors.accentBright),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) {
              final parsed = (int.tryParse(v) ?? 0).clamp(0, max);
              onChanged(parsed);
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 12, letterSpacing: 1, color: AppColors.inkDim)),
      ],
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _alarmName;

  @override
  void initState() {
    super.initState();
    FocusChannel.getAlarmSound().then((name) {
      if (mounted) setState(() => _alarmName = name);
    });
    // If a session is already running (app relaunched, or user backed out),
    // jump straight to it — a live session can never be overwritten.
    WidgetsBinding.instance.addPostFrameCallback((_) => _resumeIfActive());
  }

  /// Returns true if an active session was found (and we navigated to it).
  Future<bool> _resumeIfActive() async {
    try {
      final state = await FocusChannel.getSessionState();
      if (state['active'] == true) {
        final endTime = DateTime.fromMillisecondsSinceEpoch(
            (state['endTimeMillis'] as num).toInt());
        if (endTime.isAfter(DateTime.now()) && mounted) {
          context.go('/session', extra: {
            'endTime': endTime,
            'durationMinutes':
                (state['durationMinutes'] as num?)?.toInt() ?? 25,
            'blockedCount': (state['blockedCount'] as num?)?.toInt() ?? 0,
          });
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> _pickSound() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xF0141728),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: AppColors.glassBorder),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text('Completion sound',
                  style: TextStyle(fontSize: 18, color: AppColors.ink)),
            ),
            ListTile(
              leading: const Icon(Icons.library_music,
                  color: AppColors.accent),
              title: const Text('Choose an audio file',
                  style: TextStyle(color: AppColors.ink)),
              subtitle: const Text('MP3 or any audio on this device',
                  style: TextStyle(color: AppColors.inkDim, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, 'pick'),
            ),
            ListTile(
              leading: const Icon(Icons.alarm, color: AppColors.inkDim),
              title: const Text('Use default alarm',
                  style: TextStyle(color: AppColors.ink)),
              onTap: () => Navigator.pop(ctx, 'default'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (choice == 'pick') {
      final name = await FocusChannel.pickAlarmSound();
      if (name != null && mounted) setState(() => _alarmName = name);
    } else if (choice == 'default') {
      await FocusChannel.clearAlarmSound();
      if (mounted) setState(() => _alarmName = null);
    }
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    // Guard: never start (or overwrite) while a session is already active.
    if (await _resumeIfActive()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('A focus session is already running')));
      }
      return;
    }
    if (!context.mounted) return;
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
  Widget build(BuildContext context) {
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
                        child: Text(_fmtDuration(minutes),
                                style: TextStyle(
                                    fontSize: minutes >= 60 ? 64 : 96,
                                    fontWeight: FontWeight.w200,
                                    height: 1,
                                    color: Colors.white))
                            .animate(key: ValueKey(minutes))
                            .fadeIn(duration: 200.ms),
                      ),
                      Text(minutes >= 60 ? 'duration' : 'minutes',
                          style: const TextStyle(
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
                          _CustomChip(
                            selected: !_durations.contains(minutes),
                            onTap: () => _pickCustom(context, ref, minutes),
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
              const SizedBox(height: 10),
              GlassPanel(
                radius: 18,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                onTap: () => context.push('/limits'),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_bottom,
                        size: 20, color: AppColors.inkDim),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text('Daily app limits',
                          style:
                              TextStyle(fontSize: 15, color: AppColors.ink)),
                    ),
                    Icon(Icons.chevron_right,
                        size: 20, color: AppColors.inkFaint),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              GlassPanel(
                radius: 18,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                onTap: _pickSound,
                child: Row(
                  children: [
                    const Icon(Icons.music_note,
                        size: 20, color: AppColors.inkDim),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _alarmName == null
                            ? 'Completion sound: default alarm'
                            : 'Completion sound: $_alarmName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                  onTap: () => context.push('/stats'),
                  child: Row(
                    children: [
                      const Icon(Icons.insights,
                          size: 20, color: AppColors.accent),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          '${(totalFocused / 60).floor()}h ${totalFocused % 60}m focused · view stats',
                          style: const TextStyle(
                              fontSize: 15, color: AppColors.ink),
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 20, color: AppColors.inkFaint),
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

class _CustomChip extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _CustomChip({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune,
                size: 15,
                color: selected ? AppColors.bgBottom : AppColors.inkDim),
            const SizedBox(width: 6),
            Text('Custom',
                style: TextStyle(
                    color: selected ? AppColors.bgBottom : AppColors.inkDim,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}
