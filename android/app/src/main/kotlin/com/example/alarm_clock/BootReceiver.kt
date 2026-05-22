package com.example.alarm_clock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager

/**
 * Receives BOOT_COMPLETED and schedules alarm reschedule work via WorkManager.
 *
 * Android 10+ prohibits background startActivity, so we use WorkManager instead
 * of launching the main activity directly. WorkManager runs even when the app
 * is not in the foreground and survives Doze/battery optimization.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d("BootReceiver", "Boot completed — enqueuing alarm reschedule work")
            val workRequest = OneTimeWorkRequestBuilder<AlarmRescheduleWorker>().build()
            WorkManager.getInstance(context).enqueue(workRequest)
        }
    }
}
