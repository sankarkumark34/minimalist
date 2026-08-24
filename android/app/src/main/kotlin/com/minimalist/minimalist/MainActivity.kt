package com.minimalist.minimalist

import android.Manifest
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Base64
import android.view.accessibility.AccessibilityManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.toBitmap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingSoundResult: MethodChannel.Result? = null

    companion object {
        private const val REQUEST_PICK_AUDIO = 200
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "minimalist/focus"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> getInstalledApps(result)
                "checkPermissions" -> result.success(
                    mapOf(
                        "accessibility" to isAccessibilityEnabled(),
                        "notifications" to hasNotificationPermission()
                    )
                )
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    })
                    result.success(null)
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        !hasNotificationPermission()
                    ) {
                        ActivityCompat.requestPermissions(
                            this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 100
                        )
                    }
                    result.success(null)
                }
                "openBatterySettings" -> {
                    startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    })
                    result.success(null)
                }
                "startFocusSession" -> {
                    val minutes = call.argument<Int>("durationMinutes") ?: 25
                    val blocked = call.argument<List<String>>("blockedPackages") ?: emptyList()
                    SessionStore.start(this, minutes, blocked)
                    FocusForegroundService.start(this)
                    result.success(null)
                }
                "stopFocusSession" -> {
                    // Stop the service first (so its ticker can't fire a
                    // "session complete" notification), then clear state.
                    stopService(Intent(this, FocusForegroundService::class.java))
                    SessionStore.clear(this)
                    result.success(null)
                }
                "pickAlarmSound" -> {
                    if (pendingSoundResult != null) {
                        result.error("BUSY", "Picker already open", null)
                    } else {
                        pendingSoundResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "audio/*"
                        }
                        startActivityForResult(intent, REQUEST_PICK_AUDIO)
                    }
                }
                "getAlarmSound" -> result.success(AlarmPlayer.soundName(this))
                "clearAlarmSound" -> {
                    AlarmPlayer.setSound(this, null, null)
                    result.success(null)
                }
                "stopAlarmSound" -> {
                    AlarmPlayer.stop()
                    result.success(null)
                }
                "getSessionState" -> result.success(
                    mapOf(
                        "active" to SessionStore.isActive(this),
                        "endTimeMillis" to SessionStore.endTimeMillis(this),
                        "blockedCount" to SessionStore.blockedPackages(this).size,
                        "durationMinutes" to SessionStore.durationMinutes(this)
                    )
                )
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_PICK_AUDIO) return
        val result = pendingSoundResult ?: return
        pendingSoundResult = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            contentResolver.takePersistableUriPermission(
                uri, Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        } catch (_: Exception) {
        }
        var name = uri.lastPathSegment ?: "Custom sound"
        try {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val idx = cursor.getColumnIndex(
                    android.provider.OpenableColumns.DISPLAY_NAME
                )
                if (idx >= 0 && cursor.moveToFirst()) {
                    name = cursor.getString(idx) ?: name
                }
            }
        } catch (_: Exception) {
        }
        AlarmPlayer.setSound(this, uri.toString(), name)
        result.success(name)
    }

    /** Launchable apps with base64 PNG icons, resolved off the main thread. */
    private fun getInstalledApps(result: MethodChannel.Result) {
        val context = applicationContext
        executor.execute {
            try {
                val pm = context.packageManager
                val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                val activities = pm.queryIntentActivities(intent, 0)
                val apps = activities
                    .distinctBy { it.activityInfo.packageName }
                    .filter { it.activityInfo.packageName != context.packageName }
                    .map { info ->
                        val pkg = info.activityInfo.packageName
                        val icon = try {
                            val drawable = info.loadIcon(pm)
                            val bitmap = drawable.toBitmap(96, 96, Bitmap.Config.ARGB_8888)
                            val stream = ByteArrayOutputStream()
                            bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
                            Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
                        } catch (_: Exception) {
                            null
                        }
                        mapOf(
                            "name" to info.loadLabel(pm).toString(),
                            "package" to pkg,
                            "icon" to icon
                        )
                    }
                mainHandler.post { result.success(apps) }
            } catch (e: Exception) {
                mainHandler.post { result.error("APP_LIST_ERROR", e.message, null) }
            }
        }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabled =
            am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
        return enabled.any {
            it.resolveInfo.serviceInfo.packageName == packageName &&
                it.resolveInfo.serviceInfo.name == FocusAccessibilityService::class.java.name
        }
    }

    private fun hasNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return ContextCompat.checkSelfPermission(
            this, Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
    }
}
