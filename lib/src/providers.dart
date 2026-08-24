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
