import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../glass.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';
import 'limits_screen.dart' show appLimitsProvider;

const _emojis = ['📱', '💬', '🎬', '🎮', '🎵', '🛍️', '✈️', '📰', '🏦', '🍔'];

/// Create or edit an app group: name, emoji, member apps, and an optional
/// daily quota applied to each member app individually.
class GroupEditScreen extends ConsumerStatefulWidget {
  final AppGroup? group;

  const GroupEditScreen({super.key, this.group});

  @override
  ConsumerState<GroupEditScreen> createState() => _GroupEditScreenState();
}

class _GroupEditScreenState extends ConsumerState<GroupEditScreen> {
  late final TextEditingController _nameCtl;
  late String _emoji;
  late Set<String> _packages;
  int? _limitMinutes;
  String _query = '';

  bool get _isNew => widget.group == null;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.group?.name ?? '');
    _emoji = widget.group?.emoji ?? '📱';
    _packages = {...?widget.group?.packages};
    _limitMinutes = widget.group?.limitMinutes;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Give the group a name')));
      return;
    }
    if (_packages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one app')));
      return;
    }
    final group = AppGroup(
      id: widget.group?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      emoji: _emoji,
      packages: _packages.toList(),
      limitMinutes: _limitMinutes,
    );
    await ref.read(groupsProvider.notifier).save(group);
    ref.invalidate(appLimitsProvider);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xF02760C2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        title: Text('Delete "${widget.group!.name}"?'),
        content: const Text(
            'Its per-app daily limits will be removed as well.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.inkDim))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(groupsProvider.notifier).delete(widget.group!.id);
    ref.invalidate(appLimitsProvider);
    if (mounted) context.pop();
  }

  Future<void> _pickLimit() async {
    var minutes = _limitMinutes ?? 30;
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xF02760C2),
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
              const Text('Daily limit per app',
                  style: TextStyle(fontSize: 18, color: AppColors.ink)),
              const SizedBox(height: 8),
              const Text(
                'Each app in this group gets its own daily allowance — '
                'when an app uses it up, that app locks until midnight.',
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
                label: 'Set $minutes min / day per app',
                height: 52,
                onPressed: () => Navigator.pop(ctx, minutes),
              ),
              if (_limitMinutes != null)
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
    setState(() => _limitMinutes = result == -1 ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(installedAppsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_isNew ? 'New group' : 'Edit group',
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
        actions: [
          if (!_isNew)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline,
                  size: 22, color: AppColors.danger),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              children: [
                TextField(
                  controller: _nameCtl,
                  style: const TextStyle(color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: 'Group name (e.g. Social Media)',
                    hintStyle: const TextStyle(color: AppColors.inkFaint),
                    filled: true,
                    fillColor: AppColors.glassFill,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: AppColors.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                          color: AppColors.accent.withAlpha(140)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in _emojis)
                      GestureDetector(
                        onTap: () => setState(() => _emoji = e),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _emoji == e
                                ? AppColors.glassFillHigh
                                : AppColors.glassFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _emoji == e
                                  ? AppColors.accentBright.withAlpha(153)
                                  : AppColors.glassBorder,
                            ),
                          ),
                          child:
                              Text(e, style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                GlassPanel(
                  radius: 18,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 16),
                  onTap: _pickLimit,
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_bottom,
                          size: 20, color: AppColors.accent),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _limitMinutes == null
                              ? 'Daily limit per app: off'
                              : 'Daily limit: $_limitMinutes min per app',
                          style: const TextStyle(
                              fontSize: 15, color: AppColors.ink),
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 20, color: AppColors.inkFaint),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'APPS · ${_packages.length} selected',
                    style: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 2,
                        color: AppColors.inkFaint),
                  ),
                ),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: 'Search apps',
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
                      borderSide: BorderSide(
                          color: AppColors.accent.withAlpha(140)),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                appsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.accent)),
                  ),
                  error: (e, _) => Text('Could not load apps\n$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.inkDim)),
                  data: (apps) {
                    // Members first so the group's contents stay visible.
                    final members = apps
                        .where((a) => _packages.contains(a.package_))
                        .toList();
                    final rest = apps
                        .where((a) =>
                            !_packages.contains(a.package_) &&
                            (_query.isEmpty ||
                                a.name
                                    .toLowerCase()
                                    .contains(_query.toLowerCase())))
                        .toList();
                    return Column(
                      children: [
                        for (final app in [...members, ...rest])
                          CheckboxListTile(
                            value: _packages.contains(app.package_),
                            onChanged: (v) => setState(() => v == true
                                ? _packages.add(app.package_)
                                : _packages.remove(app.package_)),
                            controlAffinity:
                                ListTileControlAffinity.trailing,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4),
                            activeColor: AppColors.accent,
                            checkColor: AppColors.bgBottom,
                            secondary: app.icon != null
                                ? ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    child: Image.memory(app.icon!,
                                        width: 40,
                                        height: 40,
                                        gaplessPlayback: true),
                                  )
                                : Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.glassFillHigh,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                          color: AppColors.glassBorder),
                                    ),
                                    child: const Icon(Icons.android,
                                        size: 22,
                                        color: AppColors.inkFaint),
                                  ),
                            title: Text(app.name,
                                style: const TextStyle(
                                    fontSize: 15, color: AppColors.ink)),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: GlossyButton(
              label: _isNew ? 'Create group' : 'Save group',
              height: 54,
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }
}
