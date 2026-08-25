import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../channel.dart';
import '../glass.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {
  final DateTime endTime;
  final int durationMinutes;
  final int blockedCount;

  const ActiveSessionScreen({
    super.key,
    required this.endTime,
    required this.durationMinutes,
    required this.blockedCount,
  });

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _tick() async {
    final remaining = widget.endTime.difference(DateTime.now());
    if (remaining.isNegative || remaining == Duration.zero) {
      _timer?.cancel();
      if (_finished) return;
      _finished = true;
      try {
        await FocusChannel.getSessionState();
      } catch (_) {}
      saveSessionRecord(SessionRecord(
        start: widget.endTime
            .subtract(Duration(minutes: widget.durationMinutes)),
        durationMinutes: widget.durationMinutes,
        blockedCount: widget.blockedCount,
        completed: true,
      ));
      if (!mounted) return;
      context.go('/summary', extra: {
        'durationMinutes': widget.durationMinutes,
        'blockedCount': widget.blockedCount,
      });
      return;
    }
    setState(() => _remaining = remaining);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _endEarly() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xF02760C2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        title: const Text('End session early?'),
        content: const Text(
            'Your apps will be unblocked now. This session will be '
            'recorded as unfinished.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep focusing',
                  style: TextStyle(color: AppColors.accent))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('End now',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirm != true || _finished) return;
    _finished = true;
    _timer?.cancel();
    await FocusChannel.stopFocusSession();
    final elapsed = Duration(minutes: widget.durationMinutes) - _remaining;
    saveSessionRecord(SessionRecord(
      start:
          widget.endTime.subtract(Duration(minutes: widget.durationMinutes)),
      durationMinutes: elapsed.inMinutes.clamp(0, widget.durationMinutes),
      blockedCount: widget.blockedCount,
      completed: false,
    ));
    if (!mounted) return;
    context.go('/');
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final total = Duration(minutes: widget.durationMinutes);
    final progress = total.inSeconds == 0
        ? 0.0
        : 1 - (_remaining.inSeconds / total.inSeconds).clamp(0.0, 1.0);

    return PopScope(
      canPop: false, // no way out but the timer — by design (MVP)
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('FOCUSING',
                        style: TextStyle(
                            fontSize: 13,
                            letterSpacing: 6,
                            color: AppColors.inkDim))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fadeIn(duration: 1500.ms)
                    .then()
                    .fade(begin: 1, end: 0.4, duration: 1500.ms),
                const SizedBox(height: 44),
                // Glass timer medallion: frosted disc + glowing gold ring.
                Container(
                  width: 292,
                  height: 292,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withAlpha(46),
                        blurRadius: 60,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.glassFillHigh,
                              AppColors.glassFill
                            ],
                          ),
                          border:
                              Border.all(color: AppColors.glassBorder),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Specular arc on the upper-left of the disc
                            Positioned(
                              top: 14,
                              left: 40,
                              right: 40,
                              child: Container(
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(80),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white.withAlpha(31),
                                      Colors.white.withAlpha(0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 260,
                              height: 260,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 4,
                                backgroundColor: AppColors.glassBorder,
                                color: AppColors.accent,
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white,
                                  AppColors.accentBright
                                ],
                              ).createShader(bounds),
                              child: Text(_fmt(_remaining),
                                  style: const TextStyle(
                                      fontSize: 52,
                                      fontWeight: FontWeight.w200,
                                      color: Colors.white,
                                      fontFeatures: [
                                        FontFeature.tabularFigures()
                                      ])),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 44),
                GlassPanel(
                  radius: 16,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: Text(
                    '${widget.blockedCount} app${widget.blockedCount == 1 ? '' : 's'} blocked',
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.inkDim),
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.durationMinutes > 90)
                  TextButton(
                    onPressed: _endEarly,
                    child: const Text('End session early',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.inkFaint)),
                  )
                else
                  const Text('The only way out is through.',
                      style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: AppColors.inkFaint)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
