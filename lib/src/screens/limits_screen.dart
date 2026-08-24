import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../channel.dart';
import '../glass.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';

final appLimitsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return FocusChannel.getAppLimits();
});

class LimitsScreen extends ConsumerStatefulWidget {
  const LimitsScreen({super.key});

  @override
  ConsumerState<LimitsScreen> createState() => _LimitsScreenState();
}

class _LimitsScreenState extends ConsumerState<LimitsScreen> {
  String _query = '';

  Future<void> _editLimit(AppInfo app, int? currentLimit) async {
    var minutes = currentLimit ?? 30;
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xF0141728),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: AppColors.glassBorder),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Daily limit — ${app.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 18, color: AppColors.ink)),
              const SizedBox(height: 8),
              const Text(
                'Once used up, the app locks until midnight — even if it '
                'is uninstalled and reinstalled.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.inkDim),
              ),
              const SizedBox(height: 20),
              Text('$minutes min',
                  style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w200,
                      color: AppColors.accentBright)),
              Slider(
                value: minutes.toDouble(),
                min: 5,
                max: 240,
                divisions: 47,
                activeColor: AppColors.accent,
                inactiveColor: AppColors.glassBorder,
                label: '${minutes}m',
                onChanged: (v) => setSheet(() => minutes = v.round()),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in [15, 30, 45, 60, 90, 120])
                    ActionChip(
                      label: Text('${m}m'),
                      labelStyle: TextStyle(
                          fontSize: 12,
                          color: minutes == m
                              ? AppColors.bgBottom
                              : AppColors.inkDim),
                      backgroundColor: minutes == m
                          ? AppColors.accent
                          : AppColors.glassFill,
                      side: const BorderSide(color: AppColors.glassBorder),
                      onPressed: () => setSheet(() => minutes = m),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              GlossyButton(
                label: 'Set $minutes min / day',
                height: 52,
                onPressed: () => Navigator.pop(ctx, minutes),
              ),
              if (currentLimit != null)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, -1),
                  child: const Text('Remove limit',
                      style: TextStyle(color: AppColors.danger)),
                ),
            ],
          ),
        ),
      ),
    );
    if (result == null) return;
    if (result == -1) {
      await FocusChannel.removeAppLimit(app.package_);
    } else {
      await FocusChannel.setAppLimit(app.package_, result);
    }
    ref.invalidate(appLimitsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(installedAppsProvider);
    final limitsAsync = ref.watch(appLimitsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Daily app limits',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
      ),
      body: appsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(
            child: Text('Could not load apps\n$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkDim))),
        data: (apps) {
          final limits = {
            for (final l in limitsAsync.valueOrNull ?? [])
              l['package'] as String: l,
          };
          final limited = apps
              .where((a) => limits.containsKey(a.package_))
              .toList();
          final rest = apps
              .where((a) =>
                  !limits.containsKey(a.package_) &&
                  (_query.isEmpty ||
                      a.name
                          .toLowerCase()
                          .contains(_query.toLowerCase())))
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              if (limited.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('LIMITED',
                      style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 2,
                          color: AppColors.inkFaint)),
                ),
                for (final app in limited)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _LimitedRow(
                      app: app,
                      limitMinutes:
                          limits[app.package_]!['limitMinutes'] as int,
                      usedMinutes:
                          limits[app.package_]!['usedMinutes'] as int,
                      onTap: () => _editLimit(app,
                          limits[app.package_]!['limitMinutes'] as int),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              TextField(
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'Search apps to limit',
                  hintStyle: const TextStyle(color: AppColors.inkFaint),
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.inkFaint),
                  filled: true,
                  fillColor: AppColors.glassFill,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: AppColors.glassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: AppColors.accent.withAlpha(140)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              for (final app in rest)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4),
                  leading: _AppIcon(app: app),
                  title: Text(app.name,
                      style: const TextStyle(
                          fontSize: 15, color: AppColors.ink)),
                  trailing: const Icon(Icons.add_circle_outline,
                      size: 20, color: AppColors.inkFaint),
                  onTap: () => _editLimit(app, null),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LimitedRow extends StatelessWidget {
  final AppInfo app;
  final int limitMinutes;
  final int usedMinutes;
  final VoidCallback onTap;

  const _LimitedRow({
    required this.app,
    required this.limitMinutes,
    required this.usedMinutes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (usedMinutes / limitMinutes).clamp(0.0, 1.0);
    final exceeded = usedMinutes >= limitMinutes;
    return GlassPanel(
      radius: 18,
      high: true,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          _AppIcon(app: app),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.name,
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.ink)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    backgroundColor: AppColors.glassFill,
                    color:
                        exceeded ? AppColors.danger : AppColors.accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  exceeded
                      ? 'Locked until midnight 🌙'
                      : '$usedMinutes of $limitMinutes min used today',
                  style: TextStyle(
                      fontSize: 12,
                      color: exceeded
                          ? AppColors.danger
                          : AppColors.inkDim),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              size: 20, color: AppColors.inkFaint),
        ],
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final AppInfo app;

  const _AppIcon({required this.app});

  @override
  Widget build(BuildContext context) {
    return app.icon != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(app.icon!,
                width: 40, height: 40, gaplessPlayback: true),
          )
        : Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.glassFillHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: const Icon(Icons.android,
                size: 22, color: AppColors.inkFaint),
          );
  }
}
