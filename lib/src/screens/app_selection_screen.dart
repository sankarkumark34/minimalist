import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../providers.dart';
import '../theme.dart';

class AppSelectionScreen extends ConsumerStatefulWidget {
  const AppSelectionScreen({super.key});

  @override
  ConsumerState<AppSelectionScreen> createState() =>
      _AppSelectionScreenState();
}

class _AppSelectionScreenState extends ConsumerState<AppSelectionScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(installedAppsProvider);
    final blocked = ref.watch(blockedAppsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Block apps',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
        actions: [
          if (appsAsync.hasValue)
            TextButton(
              onPressed: () {
                final all = appsAsync.value!.map((a) => a.package_);
                final anyBlocked = blocked.isNotEmpty;
                ref
                    .read(blockedAppsProvider.notifier)
                    .setAll(all, blocked: !anyBlocked);
              },
              child: Text(blocked.isEmpty ? 'Block all' : 'Clear',
                  style: const TextStyle(color: AppColors.accent)),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'Search apps',
                hintStyle: const TextStyle(color: AppColors.inkFaint),
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.inkFaint),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: appsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent)),
              error: (e, _) => Center(
                  child: Text('Could not load apps\n$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.inkDim))),
              data: (apps) {
                final filtered = _query.isEmpty
                    ? apps
                    : apps
                        .where((a) => a.name
                            .toLowerCase()
                            .contains(_query.toLowerCase()))
                        .toList();
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) =>
                      _AppRow(app: filtered[i], blocked: blocked),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AppRow extends ConsumerWidget {
  final AppInfo app;
  final Set<String> blocked;

  const _AppRow({required this.app, required this.blocked});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBlocked = blocked.contains(app.package_);
    return ListTile(
      leading: app.icon != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(app.icon!,
                  width: 40, height: 40, gaplessPlayback: true),
            )
          : Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.android,
                  size: 22, color: AppColors.inkFaint),
            ),
      title: Text(app.name,
          style: const TextStyle(fontSize: 15, color: AppColors.ink)),
      trailing: Switch(
        value: isBlocked,
        onChanged: (_) =>
            ref.read(blockedAppsProvider.notifier).toggle(app.package_),
      ),
      onTap: () =>
          ref.read(blockedAppsProvider.notifier).toggle(app.package_),
    );
  }
}
