import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../glass.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final completed = history.where((r) => r.completed).toList();

    final streak = _streakDays(completed);
    final weekMinutes = _minutesSince(
        completed, DateTime.now().subtract(const Duration(days: 7)));
    final allMinutes =
        completed.fold<int>(0, (sum, r) => sum + r.durationMinutes);
    final best = completed.isEmpty
        ? 0
        : completed
            .map((r) => r.durationMinutes)
            .reduce((a, b) => a > b ? a : b);
    final daily = _dailyMinutes(completed, 7);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Your focus',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          // Streak hero
          GlassPanel(
            radius: 24,
            high: true,
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, AppColors.accentBright],
                  ).createShader(bounds),
                  child: Text('$streak',
                      style: const TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w200,
                          height: 1,
                          color: Colors.white)),
                ),
                const SizedBox(height: 6),
                Text(
                  streak == 1 ? 'day streak 🔥' : 'day streak 🔥',
                  style:
                      const TextStyle(fontSize: 14, color: AppColors.inkDim),
                ),
                if (streak == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Complete a session today to start one',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.inkFaint)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _StatCard(
                      value: _fmtHours(weekMinutes), label: 'this week')),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      value: _fmtHours(allMinutes), label: 'all-time')),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      value: _fmtHours(best), label: 'best session')),
            ],
          ),
          const SizedBox(height: 12),
          // Last-7-days chart
          GlassPanel(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Last 7 days',
                    style:
                        TextStyle(fontSize: 14, color: AppColors.inkDim)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 160,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => const Color(0xE61F2233),
                          getTooltipItem: (group, _, rod, indexInGroup) =>
                              BarTooltipItem(
                            _fmtHours(rod.toY.round()),
                            const TextStyle(
                                color: AppColors.accentBright,
                                fontSize: 12),
                          ),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(),
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) => Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _dayLabel(v.toInt()),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.inkFaint),
                              ),
                            ),
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < 7; i++)
                          BarChartGroupData(x: i, barRods: [
                            BarChartRodData(
                              toY: daily[i].toDouble(),
                              width: 18,
                              borderRadius: BorderRadius.circular(6),
                              gradient: const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppColors.accentDeep,
                                  AppColors.accentBright
                                ],
                              ),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: (daily
                                            .reduce((a, b) =>
                                                a > b ? a : b)
                                            .clamp(60, 1440))
                                    .toDouble(),
                                color: AppColors.glassFill,
                              ),
                            ),
                          ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            radius: 18,
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.verified,
                    size: 20, color: AppColors.accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '${completed.length} session${completed.length == 1 ? '' : 's'} completed'
                    '${history.length > completed.length ? ' · ${history.length - completed.length} ended early' : ''}',
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtHours(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  static String _dayLabel(int index) {
    final day = DateTime.now().subtract(Duration(days: 6 - index));
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[day.weekday - 1];
  }

  /// Minutes per day for the last [days] days (oldest first).
  static List<int> _dailyMinutes(List<SessionRecord> completed, int days) {
    final today = DateTime.now();
    final out = List<int>.filled(days, 0);
    for (final r in completed) {
      final d = DateTime(r.start.year, r.start.month, r.start.day);
      final diff = DateTime(today.year, today.month, today.day)
          .difference(d)
          .inDays;
      if (diff >= 0 && diff < days) {
        out[days - 1 - diff] += r.durationMinutes;
      }
    }
    return out;
  }

  static int _minutesSince(List<SessionRecord> completed, DateTime since) =>
      completed
          .where((r) => r.start.isAfter(since))
          .fold(0, (sum, r) => sum + r.durationMinutes);

  /// Consecutive days (ending today or yesterday) with >=1 completed session.
  static int _streakDays(List<SessionRecord> completed) {
    if (completed.isEmpty) return 0;
    final days = completed
        .map((r) => DateTime(r.start.year, r.start.month, r.start.day))
        .toSet();
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    // Streak survives if today has no session yet but yesterday does.
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 18,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Column(
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  color: AppColors.accentBright)),
          const SizedBox(height: 4),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.inkDim)),
        ],
      ),
    );
  }
}
