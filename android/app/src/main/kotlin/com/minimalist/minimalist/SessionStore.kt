package com.minimalist.minimalist

import android.content.Context
import android.content.SharedPreferences

/**
 * Single source of truth for the active focus session, shared between the
 * Flutter-facing MethodChannel, the foreground service and the
 * accessibility service. Backed by SharedPreferences so every process
 * component reads the same state.
 */
object SessionStore {
    private const val PREFS = "focus_session"
    private const val KEY_END_TIME = "endTimeMillis"
    private const val KEY_BLOCKED = "blockedPackages"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun start(context: Context, durationMinutes: Int, blockedPackages: List<String>) {
        val end = System.currentTimeMillis() + durationMinutes * 60_000L
        prefs(context).edit()
            .putLong(KEY_END_TIME, end)
            .putStringSet(KEY_BLOCKED, blockedPackages.toSet())
            .apply()
    }

    fun clear(context: Context) {
        prefs(context).edit().clear().apply()
    }

    fun endTimeMillis(context: Context): Long = prefs(context).getLong(KEY_END_TIME, 0L)

    fun isActive(context: Context): Boolean = endTimeMillis(context) > System.currentTimeMillis()

    fun blockedPackages(context: Context): Set<String> =
        prefs(context).getStringSet(KEY_BLOCKED, emptySet()) ?: emptySet()

    fun remainingMillis(context: Context): Long =
        (endTimeMillis(context) - System.currentTimeMillis()).coerceAtLeast(0L)
}
