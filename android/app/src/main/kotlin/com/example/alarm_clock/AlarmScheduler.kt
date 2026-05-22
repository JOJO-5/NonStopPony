package com.example.alarm_clock

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Schedules exact alarms via Android AlarmManager.
 *
 * This replaces `flutter_local_notifications` zonedSchedule for alarm
 * triggering, because zonedSchedule only shows a notification but
 * does NOT give Flutter a callback when the notification fires.
 * As a result, the AlarmRingingService (continuous sound + vibration)
 * was never started for scheduled alarms.
 *
 * Flow:
 * 1. Flutter calls `scheduleExactAlarm(alarmId, epochMillis)`
 * 2. This sets an AlarmManager exact alarm via [AlarmReceiver]
 * 3. When alarm fires, [AlarmReceiver] starts [AlarmRingingService]
 * 4. [AlarmRingingService] also shows a high-priority ongoing notification
 *    with STOP button and full-screen intent
 */
object AlarmScheduler {

    private const val CHANNEL = "com.example.alarm_clock/alarm_scheduler"

    fun register(flutterEngine: FlutterEngine, context: Context) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleExactAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId") ?: run {
                        result.error("INVALID", "alarmId is required", null)
                        return@setMethodCallHandler
                    }
                    val epochMillis = call.argument<Long>("epochMillis") ?: run {
                        result.error("INVALID", "epochMillis is required", null)
                        return@setMethodCallHandler
                    }
                    val title = call.argument<String>("title") ?: "战马闹钟"
                    val body = call.argument<String>("body") ?: "闹钟响了"

                    scheduleExactAlarm(context, alarmId, epochMillis, title, body)
                    result.success(null)
                }
                "cancelExactAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId") ?: run {
                        result.error("INVALID", "alarmId is required", null)
                        return@setMethodCallHandler
                    }
                    cancelExactAlarm(context, alarmId)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun scheduleExactAlarm(
        context: Context,
        alarmId: Int,
        epochMillis: Long,
        title: String,
        body: String
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = "com.example.alarm_clock.ALARM_FIRE"
            putExtra("alarmId", alarmId)
            putExtra("title", title)
            putExtra("body", body)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            alarmId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Use AlarmManagercompat for exact alarms
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+: canScheduleExactAlarms may be false
            // but USE_EXACT_ALARM permission (for alarm apps) bypasses this
            if (alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    epochMillis,
                    pendingIntent
                )
            } else {
                // Fallback: inexact but still wakes device
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    epochMillis,
                    pendingIntent
                )
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                epochMillis,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                epochMillis,
                pendingIntent
            )
        }
    }

    private fun cancelExactAlarm(context: Context, alarmId: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = "com.example.alarm_clock.ALARM_FIRE"
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            alarmId,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )

        pendingIntent?.let {
            alarmManager.cancel(it)
            it.cancel()
        }
    }
}
