package com.example.alarm_clock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BroadcastReceiver that fires when the countdown timer reaches zero
 * while the app is in the background.
 *
 * Starts [TimerRingingService] which handles:
 * - Continuous alarm sound (looping MediaPlayer)
 * - Vibration
 * - Full-screen lock screen notification
 */
class TimerReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "TimerReceiver"
        const val ACTION_TIMER_FIRE = "com.example.alarm_clock.TIMER_FIRE"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_TIMER_FIRE) return

        Log.d(TAG, "Timer fired! Starting TimerRingingService")

        // Start the foreground ringing service — it handles sound, vibration,
        // and full-screen lock screen notification.
        TimerRingingService.start(context)
    }
}
