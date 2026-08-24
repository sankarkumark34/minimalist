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
