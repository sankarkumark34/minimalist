import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'channel.dart';
import 'models.dart';

final installedAppsProvider = FutureProvider<List<AppInfo>>((ref) async {
  final maps = await FocusChannel.getInstalledApps();
  final apps = maps.map(AppInfo.fromMap).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return apps;
});

/// Set of package names the user has chosen to block, persisted in Hive.
class BlockedAppsNotifier extends Notifier<Set<String>> {
  Box get _box => Hive.box('settings');

  @override
  Set<String> build() {
    final saved = _box.get('blockedPackages') as List?;
    return saved?.cast<String>().toSet() ?? {};
  }

  void toggle(String pkg) {
    state = state.contains(pkg)
        ? (Set.of(state)..remove(pkg))
        : (Set.of(state)..add(pkg));
    _box.put('blockedPackages', state.toList());
  }

  void setAll(Iterable<String> pkgs, {required bool blocked}) {
    state = blocked
        ? (Set.of(state)..addAll(pkgs))
        : (Set.of(state)..removeAll(pkgs));
    _box.put('blockedPackages', state.toList());
  }
}

final blockedAppsProvider =
    NotifierProvider<BlockedAppsNotifier, Set<String>>(BlockedAppsNotifier.new);

/// Session duration in minutes, persisted.
class DurationNotifier extends Notifier<int> {
  Box get _box => Hive.box('settings');

  @override
  int build() => _box.get('durationMinutes', defaultValue: 25) as int;

  void set(int minutes) {
    state = minutes;
    _box.put('durationMinutes', minutes);
  }
}

final durationProvider =
    NotifierProvider<DurationNotifier, int>(DurationNotifier.new);

/// App groups, persisted in Hive. Saving/deleting also fans the group's
/// per-app daily limit out to the native limit store.
class GroupsNotifier extends Notifier<List<AppGroup>> {
  Box get _box => Hive.box('settings');

  @override
  List<AppGroup> build() {
    final saved = _box.get('appGroups') as List?;
    return saved
            ?.map((e) => AppGroup.fromMap(Map<dynamic, dynamic>.from(e as Map)))
            .toList() ??
        [];
  }

  void _persist() =>
      _box.put('appGroups', state.map((g) => g.toMap()).toList());

  AppGroup? byId(String id) =>
      state.where((g) => g.id == id).firstOrNull;

  /// Insert or replace, then sync native per-app limits: every member gets
  /// the group's quota individually; apps removed from the group (or a
  /// removed quota) drop their limit.
  Future<void> save(AppGroup group) async {
    final old = byId(group.id);
    final idx = state.indexWhere((g) => g.id == group.id);
    state = idx >= 0
        ? ([...state]..[idx] = group)
        : [...state, group];
    _persist();

    final oldPkgs = (old?.limitMinutes != null)
        ? old!.packages.toSet()
        : <String>{};
    final newPkgs =
        group.limitMinutes != null ? group.packages.toSet() : <String>{};
    for (final pkg in oldPkgs.difference(newPkgs)) {
      await FocusChannel.removeAppLimit(pkg);
    }
    if (group.limitMinutes != null) {
      for (final pkg in newPkgs) {
        await FocusChannel.setAppLimit(pkg, group.limitMinutes!);
      }
    }
  }

  Future<void> delete(String id) async {
    final group = byId(id);
    state = state.where((g) => g.id != id).toList();
    _persist();
    ref.read(selectedGroupsProvider.notifier).remove(id);
    if (group?.limitMinutes != null) {
      for (final pkg in group!.packages) {
        await FocusChannel.removeAppLimit(pkg);
      }
    }
  }
}

final groupsProvider =
    NotifierProvider<GroupsNotifier, List<AppGroup>>(GroupsNotifier.new);

/// Ids of groups whose apps join the next focus session, persisted.
class SelectedGroupsNotifier extends Notifier<Set<String>> {
  Box get _box => Hive.box('settings');

  @override
  Set<String> build() {
    final saved = _box.get('selectedGroupIds') as List?;
    return saved?.cast<String>().toSet() ?? {};
  }

  void toggle(String id) {
    state = state.contains(id)
        ? (Set.of(state)..remove(id))
        : (Set.of(state)..add(id));
    _box.put('selectedGroupIds', state.toList());
  }

  void remove(String id) {
    if (!state.contains(id)) return;
    state = Set.of(state)..remove(id);
    _box.put('selectedGroupIds', state.toList());
  }
}

final selectedGroupsProvider =
    NotifierProvider<SelectedGroupsNotifier, Set<String>>(
        SelectedGroupsNotifier.new);

/// Everything the next focus session blocks: individually chosen apps plus
/// every app in each selected group.
final focusPackagesProvider = Provider<Set<String>>((ref) {
  final blocked = ref.watch(blockedAppsProvider);
  final groups = ref.watch(groupsProvider);
  final selected = ref.watch(selectedGroupsProvider);
  return {
    ...blocked,
    for (final g in groups)
      if (selected.contains(g.id)) ...g.packages,
  };
});

final permissionsProvider = FutureProvider<Map<String, bool>>(
    (ref) async => FocusChannel.checkPermissions());

final historyProvider = Provider<List<SessionRecord>>((ref) {
  final box = Hive.box('history');
  return box.values
      .map((e) => SessionRecord.fromMap(e as Map))
      .toList()
      .reversed
      .toList();
});

void saveSessionRecord(SessionRecord record) {
  Hive.box('history').add(record.toMap());
}
