package com.minimalist.minimalist

import android.accessibilityservice.AccessibilityService
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
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
 * foreground during an active session, draws a full-screen accessibility
 * overlay with a live countdown and a "return to focus" action.
 */
class FocusAccessibilityService : AccessibilityService() {

    private var overlay: View? = null
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

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return

        if (!SessionStore.isActive(this)) {
            hideOverlay()
            return
        }

        // Ignore our own windows (including the overlay itself) and system UI.
        if (pkg == packageName || pkg == "com.android.systemui") return

        if (SessionStore.blockedPackages(this).contains(pkg)) {
            showOverlay()
        } else {
            hideOverlay()
        }
    }

    override fun onInterrupt() {
        hideOverlay()
    }

    override fun onDestroy() {
        hideOverlay()
        super.onDestroy()
    }

    private fun showOverlay() {
        if (overlay != null) return
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager

        val root = FrameLayout(this).apply { setBackgroundColor(Color.parseColor("#0C0C0E")) }

        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }

        val title = TextView(this).apply {
            text = "Focus Mode Active"
            textSize = 24f
            setTextColor(Color.parseColor("#EDEDEF"))
            typeface = Typeface.create("sans-serif-light", Typeface.NORMAL)
            gravity = Gravity.CENTER
        }

        val subtitle = TextView(this).apply {
            text = "This app is blocked until your session ends."
            textSize = 14f
            setTextColor(Color.parseColor("#8A8A93"))
            gravity = Gravity.CENTER
            setPadding(0, dp(12), 0, dp(36))
        }

        countdownText = TextView(this).apply {
            text = formatRemaining(SessionStore.remainingMillis(this@FocusAccessibilityService))
            textSize = 56f
            setTextColor(Color.parseColor("#E8C36A"))
            typeface = Typeface.create("sans-serif-thin", Typeface.NORMAL)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(48))
        }

        val button = TextView(this).apply {
            text = "Return to focus"
            textSize = 16f
            setTextColor(Color.parseColor("#0C0C0E"))
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            gravity = Gravity.CENTER
            setPadding(dp(36), dp(16), dp(36), dp(16))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#E8C36A"))
                cornerRadius = dp(30).toFloat()
            }
            setOnClickListener {
                performGlobalAction(GLOBAL_ACTION_HOME)
                hideOverlay()
            }
        }

        column.addView(title)
        column.addView(subtitle)
        column.addView(countdownText)
        column.addView(button)
        root.addView(
            column,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER
            )
        )

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.OPAQUE
        )

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
