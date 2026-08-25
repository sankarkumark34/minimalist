package com.minimalist.minimalist

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import java.util.Calendar
import java.util.concurrent.TimeUnit

/**
 * Core enforcement engine. Three jobs:
 *  1. FOCUS — during a session, blocked apps bounce straight to the
 *     launcher with a liquid-glass overlay (any window size: full-screen,
 *     split-screen, floating, PiP).
 *  2. PROTECTED — during a session, Settings / uninstall dialogs / app
 *     stores are locked so the blocker can't be disabled or removed.
 *  3. LIMIT — per-app daily time limits tracked 24/7; once today's
 *     allowance is used, the app is soft-locked until midnight. Usage is
 *     stored in this app's prefs keyed by package name, so uninstalling
 *     and reinstalling the limited app does not reset the count.
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

    private enum class Mode { FOCUS, PROTECTED, LIMIT }

    private var overlay: View? = null
    private var overlayMode: Mode? = null
    private var countdownText: TextView? = null
    private val handler = Handler(Looper.getMainLooper())
    private var currentForeground: String? = null
    private var lastTickMillis = 0L
    private var launcherPkg: String? = null
    private var autoHidePending = false

    private val autoHide = Runnable {
        autoHidePending = false
        hideOverlay()
    }

    /** Keyboards fire window-state events too; they must never be treated
     *  as the foreground app or usage attribution breaks. */
    private val imePackages: Set<String> by lazy {
        try {
            (getSystemService(INPUT_METHOD_SERVICE)
                as android.view.inputmethod.InputMethodManager)
                .inputMethodList.map { it.packageName }.toSet()
        } catch (_: Exception) {
            emptySet()
        }
    }

    /** The app that actually has window focus right now — robust against
     *  keyboards, dialogs and transient system windows, unlike the last
     *  accessibility event's package. */
    private fun focusedPackage(): String? {
        return try {
            windows.firstOrNull { it.isFocused }
                ?.root?.packageName?.toString()
                ?.takeIf { it != packageName && it != "com.android.systemui" }
                ?: currentForeground
        } catch (_: Exception) {
            currentForeground
        }
    }

    /** Updates the overlay countdown once a second while it is showing. */
    private val ticker = object : Runnable {
        override fun run() {
            val svc = this@FocusAccessibilityService
            when (overlayMode) {
                Mode.FOCUS, Mode.PROTECTED -> {
                    if (!SessionStore.isActive(svc)) {
                        hideOverlay()
                        return
                    }
                    countdownText?.text = formatRemaining(SessionStore.remainingMillis(svc))
                }
                Mode.LIMIT -> countdownText?.text = "Unlocks in ${formatUntilMidnight()}"
                null -> return
            }
            handler.postDelayed(this, 1000L)
        }
    }

    /**
     * Heartbeat: accumulates foreground time for limited apps and enforces
     * all three modes, including multi-window (split-screen/floating/PiP).
     */
    private val monitor = object : Runnable {
        override fun run() {
            val svc = this@FocusAccessibilityService
            val now = SystemClock.elapsedRealtime()
            val delta = now - lastTickMillis
            lastTickMillis = now

            // Usage tracking: count only sane, screen-on intervals so a
            // doze gap or clock jump can't inflate today's usage.
            val fg = focusedPackage()
            if (fg != null) currentForeground = fg
            if (fg != null && delta in 1..3999 && isScreenOn()) {
                AppLimitStore.addUsage(svc, fg, delta)
            }

            val mode = fg?.let { enforcementFor(it) } ?: scanWindows()
            if (mode != null) {
                showOverlay(mode)
                performGlobalAction(GLOBAL_ACTION_HOME)
                scheduleAutoHide()
            } else if (overlay != null && !autoHidePending) {
                hideOverlay()
            }

            val busy = SessionStore.isActive(svc) || AppLimitStore.hasAnyLimit(svc)
            handler.postDelayed(this, if (busy) 1000L else 2000L)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        lastTickMillis = SystemClock.elapsedRealtime()
        handler.removeCallbacks(monitor)
        handler.post(monitor)
    }

    /** Why this package must be blocked right now, or null if it's fine. */
    private fun enforcementFor(pkg: String): Mode? {
        if (pkg == packageName || pkg == "com.android.systemui" || isLauncher(pkg)) return null
        if (SessionStore.isActive(this)) {
            if (PROTECTED_PACKAGES.contains(pkg)) return Mode.PROTECTED
            if (SessionStore.blockedPackages(this).contains(pkg)) return Mode.FOCUS
        }
        if (AppLimitStore.isExceeded(this, pkg)) return Mode.LIMIT
        return null
    }

    /** Sweep every visible window (split-screen, floating, PiP). */
    private fun scanWindows(): Mode? {
        return try {
            windows.firstNotNullOfOrNull { w ->
                w.root?.packageName?.toString()?.let { enforcementFor(it) }
            }
        } catch (_: Exception) {
            null
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED) {
            scanWindows()?.let { mode ->
                showOverlay(mode)
                performGlobalAction(GLOBAL_ACTION_HOME)
                scheduleAutoHide()
            }
            return
        }

        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return

        // Our own windows (including the overlay) and system UI don't count
        // as a foreground change.
        if (pkg == packageName || pkg == "com.android.systemui") return
        if (imePackages.contains(pkg)) return
        currentForeground = pkg

        val mode = enforcementFor(pkg) ?: scanWindows()
        if (mode != null) {
            // Strict mode: show the block screen AND immediately kick the
            // user back to the launcher — never usable, at any size.
            showOverlay(mode)
            performGlobalAction(GLOBAL_ACTION_HOME)
            scheduleAutoHide()
        } else if (!isLauncher(pkg)) {
            hideOverlay()
        }
    }

    override fun onInterrupt() {
        hideOverlay()
    }

    override fun onDestroy() {
        handler.removeCallbacks(monitor)
        hideOverlay()
        super.onDestroy()
    }

    private fun scheduleAutoHide() {
        autoHidePending = true
        handler.removeCallbacks(autoHide)
        handler.postDelayed(autoHide, 2500L)
    }

    private fun isLauncher(pkg: String): Boolean {
        if (launcherPkg == null) {
            val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            launcherPkg = packageManager.resolveActivity(intent, 0)
                ?.activityInfo?.packageName ?: ""
        }
        return pkg == launcherPkg
    }

    private fun isScreenOn(): Boolean =
        (getSystemService(POWER_SERVICE) as PowerManager).isInteractive

    private fun showOverlay(mode: Mode) {
        if (overlay != null && overlayMode == mode) return
        hideOverlay()
        overlayMode = mode
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
            text = when (mode) {
                Mode.LIMIT -> "Time's up for today"
                else -> "Focus Mode Active"
            }
            textSize = 24f
            setTextColor(Color.parseColor("#F2F3F7"))
            typeface = Typeface.create("sans-serif-light", Typeface.NORMAL)
            gravity = Gravity.CENTER
        }

        val subtitle = TextView(this).apply {
            text = when (mode) {
                Mode.PROTECTED ->
                    "Settings, uninstalling and app stores are locked while focus is active."
                Mode.LIMIT ->
                    "You've used today's allowance for this app. See you tomorrow 🌙"
                Mode.FOCUS -> "This app is blocked until your session ends."
            }
            textSize = 14f
            setTextColor(Color.parseColor("#9BA0B0"))
            gravity = Gravity.CENTER
            setPadding(0, dp(12), 0, dp(32))
        }

        countdownText = TextView(this).apply {
            text = when (mode) {
                Mode.LIMIT -> "Unlocks in ${formatUntilMidnight()}"
                else -> formatRemaining(SessionStore.remainingMillis(this@FocusAccessibilityService))
            }
            textSize = if (mode == Mode.LIMIT) 28f else 56f
            setTextColor(Color.parseColor("#F6DFA0"))
            typeface = Typeface.create("sans-serif-thin", Typeface.NORMAL)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(40))
            setShadowLayer(24f, 0f, 0f, Color.parseColor("#66E8C36A"))
        }

        // Glossy gold pill button
        val button = TextView(this).apply {
            text = if (mode == Mode.LIMIT) "Okay" else "Return to focus"
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
            handler.removeCallbacks(ticker)
            handler.post(ticker)
        } catch (_: Exception) {
            overlay = null
            overlayMode = null
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
        overlayMode = null
        countdownText = null
    }

    private fun formatRemaining(millis: Long): String {
        val h = TimeUnit.MILLISECONDS.toHours(millis)
        val m = TimeUnit.MILLISECONDS.toMinutes(millis) % 60
        val s = TimeUnit.MILLISECONDS.toSeconds(millis) % 60
        return if (h > 0) String.format("%d:%02d:%02d", h, m, s)
        else String.format("%02d:%02d", m, s)
    }

    private fun formatUntilMidnight(): String {
        val midnight = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val millis = midnight.timeInMillis - System.currentTimeMillis()
        val h = TimeUnit.MILLISECONDS.toHours(millis)
        val m = TimeUnit.MILLISECONDS.toMinutes(millis) % 60
        return if (h > 0) "${h}h ${m}m" else "${m}m"
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
