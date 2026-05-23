package com.example.alarm_clock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * BroadcastReceiver that fires when an alarm triggers via AlarmManager.
 *
 * This receiver starts the [AlarmRingingService] which plays the alarm
 * sound in a loop and vibrates until the user dismisses.
 *
 * It also shows a high-priority notification with full-screen intent
 * so the alarm is visible even on the lock screen.
 */
class AlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AlarmReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "com.example.alarm_clock.ALARM_FIRE") return

        val alarmId = intent.getIntExtra("alarmId", -1)
        val title = intent.getStringExtra("title") ?: "战马闹钟"
        val body = intent.getStringExtra("body") ?: "闹钟响了"
        val ringtoneUri = intent.getStringExtra("ringtoneUri") ?: "default"

        Log.d(TAG, "Alarm fired! alarmId=$alarmId, title=$title, ringtoneUri=$ringtoneUri")

        // Start the AlarmRingingService for continuous sound + vibration
        val serviceIntent = Intent(context, AlarmRingingService::class.java).apply {
            action = AlarmRingingService.ACTION_START
            putExtra("alarmId", alarmId)
            putExtra("title", title)
            putExtra("body", body)
            putExtra("ringtoneUri", ringtoneUri)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
