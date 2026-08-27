import 'dart:convert';
import 'dart:typed_data';

class AppInfo {
  final String name;
  final String package_;
  final Uint8List? icon;

  const AppInfo({required this.name, required this.package_, this.icon});

  factory AppInfo.fromMap(Map<String, dynamic> m) => AppInfo(
        name: m['name'] as String? ?? '',
        package_: m['package'] as String? ?? '',
        icon: m['icon'] != null ? base64Decode(m['icon'] as String) : null,
      );
}

/// A named collection of apps ("Social Media", "Entertainment"...) that can
/// be focused as one unit, or given a per-app daily quota in one step.
class AppGroup {
  final String id;
  final String name;
  final String emoji;
  final List<String> packages;

  /// Daily allowance in minutes applied to EACH app in the group
  /// individually (not a shared pool), or null for no limit.
  final int? limitMinutes;

  const AppGroup({
    required this.id,
    required this.name,
    this.emoji = '📱',
    this.packages = const [],
    this.limitMinutes,
  });

  AppGroup copyWith({
    String? name,
    String? emoji,
    List<String>? packages,
    int? limitMinutes,
    bool clearLimit = false,
  }) =>
      AppGroup(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        packages: packages ?? this.packages,
        limitMinutes: clearLimit ? null : (limitMinutes ?? this.limitMinutes),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'packages': packages,
        'limitMinutes': limitMinutes,
      };

  factory AppGroup.fromMap(Map<dynamic, dynamic> m) => AppGroup(
        id: m['id'] as String,
        name: m['name'] as String? ?? '',
        emoji: m['emoji'] as String? ?? '📱',
        packages: (m['packages'] as List?)?.cast<String>() ?? const [],
        limitMinutes: m['limitMinutes'] as int?,
      );
}

class SessionRecord {
  final DateTime start;
  final int durationMinutes;
  final int blockedCount;
  final bool completed;

  const SessionRecord({
    required this.start,
    required this.durationMinutes,
    required this.blockedCount,
    required this.completed,
  });

  Map<String, dynamic> toMap() => {
        'start': start.millisecondsSinceEpoch,
        'durationMinutes': durationMinutes,
        'blockedCount': blockedCount,
        'completed': completed,
      };

  factory SessionRecord.fromMap(Map<dynamic, dynamic> m) => SessionRecord(
        start: DateTime.fromMillisecondsSinceEpoch(m['start'] as int),
        durationMinutes: m['durationMinutes'] as int,
        blockedCount: m['blockedCount'] as int,
        completed: m['completed'] as bool? ?? true,
      );
}
