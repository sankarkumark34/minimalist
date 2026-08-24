import 'package:flutter/services.dart';

/// Bridge to the native Android focus engine.
class FocusChannel {
  static const _channel = MethodChannel('minimalist/focus');

  /// Installed launchable apps: [{name, package, icon(base64 png)}]
  static Future<List<Map<String, dynamic>>> getInstalledApps() async {
    final raw = await _channel.invokeListMethod<dynamic>('getInstalledApps');
    return (raw ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// {accessibility: bool, notifications: bool}
  static Future<Map<String, bool>> checkPermissions() async {
    final raw =
        await _channel.invokeMapMethod<String, dynamic>('checkPermissions');
    return raw?.map((k, v) => MapEntry(k, v == true)) ?? {};
  }

  static Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod('openAccessibilitySettings');

  static Future<void> requestNotificationPermission() =>
      _channel.invokeMethod('requestNotificationPermission');

  static Future<void> openBatterySettings() =>
      _channel.invokeMethod('openBatterySettings');

  static Future<void> startFocusSession({
    required int durationMinutes,
    required List<String> blockedPackages,
  }) =>
      _channel.invokeMethod('startFocusSession', {
        'durationMinutes': durationMinutes,
        'blockedPackages': blockedPackages,
      });

  /// {active: bool, endTimeMillis: int, blockedCount: int}
  static Future<Map<String, dynamic>> getSessionState() async {
    final raw =
        await _channel.invokeMapMethod<String, dynamic>('getSessionState');
    return Map<String, dynamic>.from(raw ?? {});
  }
}
