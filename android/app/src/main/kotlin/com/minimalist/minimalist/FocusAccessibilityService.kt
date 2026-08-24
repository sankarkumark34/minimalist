package com.minimalist.minimalist

import android.accessibilityservice.AccessibilityService
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import java.util.concurrent.TimeUnit

/**
 * Core blocker. Listens for window changes; when a blocked app comes to the
 * foreground during an active session, draws a full-screen liquid-glass
 * overlay — blurred backdrop (Android 12+), frosted card, glossy gold
 * button — with a live countdown.
 */
class FocusAccessibilityService : AccessibilityService() {

    companion object {
        /** Locked while a session runs: uninstalling the app, disabling the
         *  blocker, or force-stopping it mid-session is not possible. */
        private val PROTECTED_PACKAGES = setOf(
            "com.android.settings",                // AOSP / most OEM settings
            "com.android.packageinstaller",        // uninstall dialogs (AOSP)
            "com.google.android.packageinstaller", // uninstall dialogs (Pixel+)
            "com.android.vending",                 // Play Store
            "com.miui.securitycenter",             // Xiaomi security center
            "com.samsung.android.lool",            // Samsung device care
            "com.coloros.safecenter",              // Oppo security center
            "com.iqoo.secure"                      // Vivo security center
        )
    }

    private fun isRestricted(pkg: String): Boolean =
        PROTECTED_PACKAGES.contains(pkg) ||
            SessionStore.blockedPackages(this).contains(pkg)

    private var overlay: View? = null
    private var protectedTrigger = false
    private var countdownText: TextView? = null
    private val handler = Handler(Looper.getMainLooper())

    private val ticker = object : Runnable {
        override fun run() {
            if (!SessionStore.isActive(this@FocusAccessibilityService)) {
                hideOverlay()
                return
            }
            countdownText?.text = formatRemaining(SessionStore.remainingMillis(this@FocusAccessibilityService))
            handler.postDelayed(this, 1000L)
        }
    }

    private val autoHide = Runnable {
        autoHidePending = false
        hideOverlay()
    }

    /** Strict multi-window sweep: split-screen, floating windows and PiP
     *  all appear in [windows]; any blocked package visible => block. */
    private val monitor = object : Runnable {
        override fun run() {
            if (SessionStore.isActive(this@FocusAccessibilityService)) {
                if (scanWindowsForBlocked()) {
                    showOverlay()
                    performGlobalAction(GLOBAL_ACTION_HOME)
                } else if (overlay != null && handlerHasNoAutoHide()) {
                    hideOverlay()
                }
                // Active session: tight 500ms sweep for sub-second worst case.
                handler.postDelayed(this, 500L)
            } else {
                hideOverlay()
                // No session: relax to 2s — near-zero battery cost while idle.
                handler.postDelayed(this, 2000L)
            }
        }
    }

    private var autoHidePending = false

    private fun handlerHasNoAutoHide(): Boolean = !autoHidePending

    private fun scanWindowsForBlocked(): Boolean {
        return try {
            windows.any { w ->
                val pkg = w.root?.packageName?.toString()
                pkg != null && pkg != packageName && isRestricted(pkg)
            }
        } catch (_: Exception) {
            false
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        handler.removeCallbacks(monitor)
        handler.post(monitor)
    }

    private var launcherPkg: String? = null

    private fun isLauncher(pkg: String): Boolean {
        if (launcherPkg == null) {
            val intent = android.content.Intent(android.content.Intent.ACTION_MAIN)
                .addCategory(android.content.Intent.CATEGORY_HOME)
            launcherPkg = packageManager.resolveActivity(intent, 0)
                ?.activityInfo?.packageName ?: ""
        }
        return pkg == launcherPkg
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (!SessionStore.isActive(this)) {
            hideOverlay()
            return
        }

        if (event.eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED) {
            // A window appeared/moved/resized (split-screen, floating, PiP):
            // sweep everything visible right now.
            if (scanWindowsForBlocked()) {
                showOverlay()
                performGlobalAction(GLOBAL_ACTION_HOME)
                scheduleAutoHide()
            }
            return
        }

        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return

        // Ignore our own windows (including the overlay itself) and system UI.
        if (pkg == packageName || pkg == "com.android.systemui") return

        if (isRestricted(pkg) || scanWindowsForBlocked()) {
            protectedTrigger = PROTECTED_PACKAGES.contains(pkg)
            // Strict mode: show the block screen AND immediately kick the
            // user back to the launcher — the blocked app (or a session-
            // killing surface like Settings) is never usable, at any size.
            showOverlay()
            performGlobalAction(GLOBAL_ACTION_HOME)
            scheduleAutoHide()
        } else if (!isLauncher(pkg)) {
            hideOverlay()
        }
    }

    private fun scheduleAutoHide() {
        autoHidePending = true
        handler.removeCallbacks(autoHide)
        handler.postDelayed(autoHide, 2500L)
    }

    override fun onInterrupt() {
        hideOverlay()
    }

    override fun onDestroy() {
        handler.removeCallbacks(monitor)
        hideOverlay()
        super.onDestroy()
    }

    private fun showOverlay() {
        if (overlay != null) return
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager

        // Scrim: deep translucent midnight; the window blur (S+) frosts
        // whatever the blocked app was showing underneath.
        val root = FrameLayout(this).apply { setBackgroundColor(Color.parseColor("#E60B0D18")) }

        // Frosted glass card
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(32), dp(40), dp(32), dp(40))
            background = GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                intArrayOf(Color.parseColor("#1FFFFFFF"), Color.parseColor("#0AFFFFFF"))
            ).apply {
                cornerRadius = dp(28).toFloat()
                setStroke(dp(1), Color.parseColor("#2EFFFFFF"))
            }
            clipToOutline = true
        }

        val title = TextView(this).apply {
            text = "Focus Mode Active"
            textSize = 24f
            setTextColor(Color.parseColor("#F2F3F7"))
            typeface = Typeface.create("sans-serif-light", Typeface.NORMAL)
            gravity = Gravity.CENTER
        }

        val subtitle = TextView(this).apply {
            text = if (protectedTrigger)
                "Settings, uninstalling and app stores are locked while focus is active."
            else
                "This app is blocked until your session ends."
            textSize = 14f
            setTextColor(Color.parseColor("#9BA0B0"))
            gravity = Gravity.CENTER
            setPadding(0, dp(12), 0, dp(32))
        }

        countdownText = TextView(this).apply {
            text = formatRemaining(SessionStore.remainingMillis(this@FocusAccessibilityService))
            textSize = 56f
            setTextColor(Color.parseColor("#F6DFA0"))
            typeface = Typeface.create("sans-serif-thin", Typeface.NORMAL)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(40))
            setShadowLayer(24f, 0f, 0f, Color.parseColor("#66E8C36A"))
        }

        // Glossy gold pill button
        val button = TextView(this).apply {
            text = "Return to focus"
            textSize = 16f
            setTextColor(Color.parseColor("#07080F"))
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            gravity = Gravity.CENTER
            setPadding(dp(36), dp(16), dp(36), dp(16))
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(
                    Color.parseColor("#F6DFA0"),
                    Color.parseColor("#E8C36A"),
                    Color.parseColor("#C99B3F")
                )
            ).apply {
                cornerRadius = dp(30).toFloat()
                setStroke(dp(1), Color.parseColor("#8CF6DFA0"))
            }
            elevation = dp(8).toFloat()
            setOnClickListener {
                performGlobalAction(GLOBAL_ACTION_HOME)
                hideOverlay()
            }
        }

        card.addView(title)
        card.addView(subtitle)
        card.addView(countdownText)
        card.addView(button)
        root.addView(
            card,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER
            ).apply {
                marginStart = dp(24)
                marginEnd = dp(24)
            }
        )

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            params.flags = params.flags or WindowManager.LayoutParams.FLAG_BLUR_BEHIND
            params.blurBehindRadius = dp(24)
        }

        try {
            wm.addView(root, params)
            overlay = root
            handler.post(ticker)
        } catch (_: Exception) {
            overlay = null
        }
    }

    private fun hideOverlay() {
        handler.removeCallbacks(ticker)
        handler.removeCallbacks(autoHide)
        autoHidePending = false
        overlay?.let {
            try {
                (getSystemService(WINDOW_SERVICE) as WindowManager).removeView(it)
            } catch (_: Exception) {
            }
        }
        overlay = null
        countdownText = null
    }

    private fun formatRemaining(millis: Long): String {
        val h = TimeUnit.MILLISECONDS.toHours(millis)
        val m = TimeUnit.MILLISECONDS.toMinutes(millis) % 60
        val s = TimeUnit.MILLISECONDS.toSeconds(millis) % 60
        return if (h > 0) String.format("%d:%02d:%02d", h, m, s)
        else String.format("%02d:%02d", m, s)
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
