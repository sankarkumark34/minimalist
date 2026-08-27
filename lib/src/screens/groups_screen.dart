import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../glass.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';

/// App groups: create collections like Social Media / Entertainment, pick
/// which ones join the next focus session, and see their daily quotas.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    final selected = ref.watch(selectedGroupsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('App groups',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/groups/edit'),
            icon: const Icon(Icons.add, size: 18, color: AppColors.accent),
            label: const Text('New',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
      body: groups.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🗂️', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 16),
                    const Text('No groups yet',
                        style:
                            TextStyle(fontSize: 18, color: AppColors.ink)),
                    const SizedBox(height: 8),
                    const Text(
                      'Group apps like Social Media or Entertainment, '
                      'then focus-block or time-limit the whole group '
                      'in one tap.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 13, color: AppColors.inkDim),
                    ),
                    const SizedBox(height: 24),
                    GlossyButton(
                      label: 'Create a group',
                      height: 52,
                      onPressed: () => context.push('/groups/edit'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    'Toggle a group on to block all its apps during focus.',
                    style: TextStyle(fontSize: 13, color: AppColors.inkDim),
                  ),
                ),
                for (final g in groups)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _GroupCard(
                      group: g,
                      inFocus: selected.contains(g.id),
                      onToggle: () => ref
                          .read(selectedGroupsProvider.notifier)
                          .toggle(g.id),
                      onTap: () => context.push('/groups/edit', extra: g),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final AppGroup group;
  final bool inFocus;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _GroupCard({
    required this.group,
    required this.inFocus,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 18,
      high: inFocus,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      onTap: onTap,
      child: Row(
        children: [
          Text(group.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name,
                    style:
                        const TextStyle(fontSize: 16, color: AppColors.ink)),
                const SizedBox(height: 3),
                Text(
                  '${group.packages.length} app'
                  '${group.packages.length == 1 ? '' : 's'}'
                  '${group.limitMinutes != null ? ' · ${group.limitMinutes}m/day each' : ''}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.inkDim),
                ),
              ],
            ),
          ),
          Switch(value: inFocus, onChanged: (_) => onToggle()),
        ],
      ),
    );
  }
}
