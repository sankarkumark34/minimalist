# minimalist

A study-focused Focus Mode app for Android. Offline-first — no login, no backend, no data ever leaves the device.

Pick a duration, choose which apps to block, and begin. Opening a blocked app during a session shows a full-screen focus overlay with a live countdown. The only way out is the timer expiring.

## Architecture

- **Flutter (Dart)** — UI: home / duration picker, app selection, active session, summary. State via Riverpod, persistence via Hive.
- **Kotlin (native Android)** — the focus engine, bridged over a `MethodChannel` (`minimalist/focus`):
  - [FocusAccessibilityService.kt](android/app/src/main/kotlin/com/minimalist/minimalist/FocusAccessibilityService.kt) — detects foreground app changes; draws a `TYPE_ACCESSIBILITY_OVERLAY` block screen over blocked apps (no `SYSTEM_ALERT_WINDOW` permission needed).
  - [FocusForegroundService.kt](android/app/src/main/kotlin/com/minimalist/minimalist/FocusForegroundService.kt) — keeps the session timer alive in the background with an ongoing notification; ends the session and notifies on completion.
  - [SessionStore.kt](android/app/src/main/kotlin/com/minimalist/minimalist/SessionStore.kt) — SharedPreferences-backed session state shared by all components.
  - [MainActivity.kt](android/app/src/main/kotlin/com/minimalist/minimalist/MainActivity.kt) — MethodChannel handler: installed-app listing (with icons), permission checks, session start.

## Permissions

| Permission | Why | How granted |
|---|---|---|
| Accessibility service | Detect when a blocked app opens; draw the block overlay | User enables in Settings (app guides them) |
| `POST_NOTIFICATIONS` | Session timer + completion notification | Runtime prompt (Android 13+) |
| `FOREGROUND_SERVICE_SPECIAL_USE` | Keep the timer running with screen off | Manifest |

No usage-access permission, no internet permission, no analytics.

## Build

Requires Flutter 3.44+ and a JDK 17–21 for Gradle (JDK 26 breaks AGP's `jlink` transform — `android/gradle.properties` pins `org.gradle.java.home`; adjust the path for your machine).

```
flutter pub get
flutter build apk --release
```

minSdk 26 (Android 8.0+), Android only. iOS is out of scope — true app blocking is not feasible there without Apple entitlements.

## Status

Phase 1 MVP per the project plan: duration picker, app block list with search, native blocking engine, live countdown, session summary, local history. Emergency break is deliberately absent — deferred to Phase 2.
