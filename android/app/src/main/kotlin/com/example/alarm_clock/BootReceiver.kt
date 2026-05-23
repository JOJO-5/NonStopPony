package com.example.alarm_clock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager

/**
 * Receives BOOT_COMPLETED and other system broadcasts, then schedules alarm
 * reschedule work via WorkManager.
 *
 * Handles:
 * - BOOT_COMPLETED: device reboot
 * - LOCKED_BOOT_COMPLETED: device reboot while locked
 * - QUICKBOOT_POWER / QUICKBOOT_POWERON: HTC/Android quick boot
 * - MY_PACKAGE_REPLACED: app updated or re-enabled
 */
class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
        private val TRIGGER_ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWER",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            Intent.ACTION_MY_PACKAGE_REPLACED,
        )
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != null && TRIGGER_ACTIONS.contains(action)) {
            Log.d(TAG, "Received $action — enqueuing alarm reschedule work")
            val workRequest = OneTimeWorkRequestBuilder<AlarmRescheduleWorker>().build()
            WorkManager.getInstance(context).enqueue(workRequest)
        }
    }
}
