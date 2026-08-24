package com.minimalist.minimalist

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Handler
import android.os.Looper

/**
 * Plays the session-complete sound: the user's chosen local audio file if
 * one is set (persisted in its own prefs file, so it survives session
 * clears), otherwise the device's default alarm tone. Capped at 60s.
 */
object AlarmPlayer {
    private const val PREFS = "focus_settings"
    private const val KEY_URI = "alarmUri"
    private const val KEY_NAME = "alarmName"
    private const val MAX_PLAY_MILLIS = 60_000L

    private var player: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private val stopper = Runnable { stop() }

    fun setSound(context: Context, uri: String?, name: String?) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_URI, uri)
            .putString(KEY_NAME, name)
            .apply()
    }

    fun soundName(context: Context): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_NAME, null)

    private fun soundUri(context: Context): Uri? {
        val saved = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_URI, null)
        return if (saved != null) Uri.parse(saved)
        else RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
    }

    fun play(context: Context) {
        stop()
        val uri = soundUri(context) ?: return
        try {
            val mp = MediaPlayer()
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            mp.setDataSource(context.applicationContext, uri)
            mp.setOnCompletionListener { stop() }
            mp.setOnErrorListener { _, _, _ -> stop(); true }
            mp.prepare()
            mp.start()
            player = mp
            handler.postDelayed(stopper, MAX_PLAY_MILLIS)
        } catch (_: Exception) {
            stop()
        }
    }

    fun stop() {
        handler.removeCallbacks(stopper)
        player?.let {
            try {
                if (it.isPlaying) it.stop()
                it.release()
            } catch (_: Exception) {
            }
        }
        player = null
    }
}
