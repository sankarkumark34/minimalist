package com.minimalist.minimalist

import android.content.Context
import android.content.SharedPreferences
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Per-app daily time limits. Usage is tracked in THIS app's storage keyed
 * by package name, so uninstalling/reinstalling the limited app does not
 * reset its count — only the day rolling over does.
 */
object AppLimitStore {
    private const val PREFS = "focus_limits"
    private const val KEY_DATE = "date"
    private const val LIMIT_PREFIX = "limit_"   // minutes (Int)
    private const val USED_PREFIX = "used_"     // millis (Long)

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun today(): String =
        SimpleDateFormat("yyyyMMdd", Locale.US).format(Date())

    /** Reset all usage counters when the day changes. */
    private fun rollover(context: Context) {
        val p = prefs(context)
        if (p.getString(KEY_DATE, "") == today()) return
        val edit = p.edit()
        p.all.keys.filter { it.startsWith(USED_PREFIX) }
            .forEach { edit.remove(it) }
        edit.putString(KEY_DATE, today()).apply()
    }

    fun setLimit(context: Context, pkg: String, minutes: Int) {
        prefs(context).edit().putInt(LIMIT_PREFIX + pkg, minutes).apply()
    }

    fun removeLimit(context: Context, pkg: String) {
        prefs(context).edit()
            .remove(LIMIT_PREFIX + pkg)
            .remove(USED_PREFIX + pkg)
            .apply()
    }

    fun hasAnyLimit(context: Context): Boolean =
        prefs(context).all.keys.any { it.startsWith(LIMIT_PREFIX) }

    fun isLimited(context: Context, pkg: String): Boolean =
        prefs(context).contains(LIMIT_PREFIX + pkg)

    fun addUsage(context: Context, pkg: String, millis: Long) {
        if (!isLimited(context, pkg)) return
        rollover(context)
        val p = prefs(context)
        val used = p.getLong(USED_PREFIX + pkg, 0L) + millis
        p.edit().putLong(USED_PREFIX + pkg, used).apply()
    }

    fun isExceeded(context: Context, pkg: String): Boolean {
        val limit = prefs(context).getInt(LIMIT_PREFIX + pkg, -1)
        if (limit < 0) return false
        rollover(context)
        return prefs(context).getLong(USED_PREFIX + pkg, 0L) >= limit * 60_000L
    }

    /** [{package, limitMinutes, usedMinutes}] for the Flutter UI. */
    fun all(context: Context): List<Map<String, Any>> {
        rollover(context)
        val p = prefs(context)
        return p.all.keys
            .filter { it.startsWith(LIMIT_PREFIX) }
            .map { key ->
                val pkg = key.removePrefix(LIMIT_PREFIX)
                mapOf(
                    "package" to pkg,
                    "limitMinutes" to p.getInt(key, 0),
                    "usedMinutes" to
                        (p.getLong(USED_PREFIX + pkg, 0L) / 60_000L).toInt()
                )
            }
    }
}
