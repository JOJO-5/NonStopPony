package com.example.alarm_clock

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.util.Log
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import java.util.Calendar

/**
 * Receives BOOT_COMPLETED and other system broadcasts, then reschedules alarms
 * via two parallel paths:
 *
 * 1. **Native AlarmManager (synchronous)** — opens the sqflite
 *    `alarm_clock.db` directly, computes the next trigger time for each
 *    enabled alarm, and registers an exact alarm via AlarmManager. This
 *    path does NOT require the Flutter engine, Dart isolate, or WorkManager
 *    to be alive. It guarantees the next-firing alarm will sound even if
 *    the Dart-side reschedule (path 2) is killed by the OS or never starts.
 *
 * 2. **Dart-side reschedule via WorkManager (async)** — enqueues
 *    [AlarmRescheduleWorker] which boots a background FlutterEngine and
 *    calls `BootReceiverService.rescheduleAlarmsAfterBoot` to re-register
 *    all enabled alarms with the full single/double-rest scheduling engine.
 *
 * Handles:
 * - BOOT_COMPLETED: device reboot
 * - LOCKED_BOOT_COMPLETED: device reboot while locked (requires
 *   `android:directBootAware="true"` in AndroidManifest)
 * - QUICKBOOT_POWER / QUICKBOOT_POWERON: HTC/Android quick boot
 * - MY_PACKAGE_REPLACED: app updated or re-enabled
 */
class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
        private const val DB_NAME = "alarm_clock.db"
        private const val ALARMS_TABLE = "alarms"
        private const val WEEK_SCHEDULE_TABLE = "week_schedule"
        // Epoch for weekNumber() — must match lib/utils/date_utils.dart
        private val WEEK_EPOCH_MS = java.util.GregorianCalendar(2024, 0, 1).timeInMillis

        private val TRIGGER_ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWER",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            Intent.ACTION_MY_PACKAGE_REPLACED,
        )

        // RepeatType enum index — must match lib/models/alarm_info.dart
        private const val REPEAT_ONCE = 0
        private const val REPEAT_DAILY = 1
        private const val REPEAT_WEEKDAYS = 2
        private const val REPEAT_WEEKENDS = 3
        private const val REPEAT_SINGLE_REST = 4
        private const val REPEAT_DOUBLE_REST = 5
        private const val REPEAT_CUSTOM = 6

        // WeekType — must match lib/models/week_schedule.dart
        private const val WEEK_SINGLE = 0
        private const val WEEK_DOUBLE = 1

        // Action matching AlarmReceiver.kt's intent.action check
        private const val ACTION_ALARM_FIRE = "com.example.alarm_clock.ALARM_FIRE"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == null || action !in TRIGGER_ACTIONS) {
            Log.d(TAG, "Ignoring action=$action")
            return
        }
        Log.d(TAG, "Received $action — rescheduling alarms")

        // Path 1: native AlarmManager. Synchronous — runs first so AlarmManager
        // has at least one alarm registered before the process may be killed.
        try {
            rescheduleNative(context)
        } catch (e: Exception) {
            Log.e(TAG, "Native AlarmManager reschedule failed", e)
        }

        // Path 2: full Dart-side reschedule via WorkManager. Handles every
        // enabled alarm (not just the next one) with the complete scheduling
        // engine from lib/utils/date_utils.dart.
        try {
            val workRequest = OneTimeWorkRequestBuilder<AlarmRescheduleWorker>().build()
            WorkManager.getInstance(context).enqueue(workRequest)
            Log.d(TAG, "Enqueued AlarmRescheduleWorker")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to enqueue AlarmRescheduleWorker", e)
        }
    }

    /**
     * Synchronous AlarmManager registration. Idempotent — multiple calls
     * just replace the existing PendingIntent for the same alarmId.
     */
    private fun rescheduleNative(context: Context) {
        val alarms = readEnabledAlarms(context)
        if (alarms.isEmpty()) {
            Log.d(TAG, "No enabled alarms — nothing to schedule")
            return
        }
        val overrides = readWeekScheduleOverrides(context)
        val (holidaySet, makeupSet) = readHolidaySetsFromDb(context)

        val alarmManager =
            context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        for (alarm in alarms) {
            try {
                val triggerAt = computeNextTrigger(
                    alarm = alarm,
                    overrides = overrides,
                    holidaySet = holidaySet,
                    makeupSet = makeupSet,
                    from = System.currentTimeMillis(),
                ) ?: continue

                val title = alarm.label?.takeIf { it.isNotBlank() } ?: "战马闹钟"
                val body = "到达设定时间"

                val pendingIntent = buildAlarmPendingIntent(
                    context = context,
                    alarmId = alarm.id,
                    title = title,
                    body = body,
                    ringtoneUri = alarm.ringtone ?: "default",
                )

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    if (alarmManager.canScheduleExactAlarms()) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent
                        )
                    } else {
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent
                        )
                    }
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent
                    )
                } else {
                    @Suppress("DEPRECATION")
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent
                    )
                }
                Log.d(TAG, "Scheduled alarm ${alarm.id} at $triggerAt via AlarmManager")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to schedule alarm ${alarm.id}", e)
            }
        }
    }

    // ── Data model (mirror of lib/services/alarm_storage_service.dart) ───

    private data class AlarmRow(
        val id: Int,
        val hour: Int,
        val minute: Int,
        val repeatType: Int,
        val weekdays: List<Int>, // Dart convention: 1=Mon..7=Sun
        val label: String?,
        val isEnabled: Boolean,
        val ringtone: String?,
        val saturdayHour: Int?,
        val saturdayMinute: Int?,
    )

    private data class WeekOverride(
        val weekIndex: Int,
        val weekType: Int,
    )

    // ── sqflite direct read (no FlutterEngine needed) ────────────────────

    private fun openDb(context: Context): SQLiteDatabase? {
        val dbPath = context.getDatabasePath(DB_NAME)
        if (!dbPath.exists()) {
            Log.w(TAG, "Database $DB_NAME does not exist at ${dbPath.absolutePath}")
            return null
        }
        return try {
            SQLiteDatabase.openDatabase(
                dbPath.absolutePath, null, SQLiteDatabase.OPEN_READONLY
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open $DB_NAME", e)
            null
        }
    }

    private fun readEnabledAlarms(context: Context): List<AlarmRow> {
        val db = openDb(context) ?: return emptyList()
        val out = mutableListOf<AlarmRow>()
        val cursor: Cursor? = try {
            db.rawQuery(
                "SELECT id, hour, minute, repeatType, weekdays, label, " +
                    "isEnabled, ringtone, saturdayHour, saturdayMinute " +
                    "FROM $ALARMS_TABLE WHERE isEnabled = 1",
                null
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query alarms", e)
            null
        }
        cursor?.use { c ->
            val idIdx = c.getColumnIndexOrThrow("id")
            val hourIdx = c.getColumnIndexOrThrow("hour")
            val minIdx = c.getColumnIndexOrThrow("minute")
            val rptIdx = c.getColumnIndexOrThrow("repeatType")
            val wdIdx = c.getColumnIndexOrThrow("weekdays")
            val labelIdx = c.getColumnIndexOrThrow("label")
            val ringIdx = c.getColumnIndexOrThrow("ringtone")
            val satHIdx = c.getColumnIndexOrThrow("saturdayHour")
            val satMIdx = c.getColumnIndexOrThrow("saturdayMinute")
            while (c.moveToNext()) {
                val weekdaysStr = c.getString(wdIdx) ?: ""
                val weekdays = if (weekdaysStr.isBlank()) emptyList() else
                    weekdaysStr.split(",").mapNotNull { it.trim().toIntOrNull() }
                out.add(
                    AlarmRow(
                        id = c.getInt(idIdx),
                        hour = c.getInt(hourIdx),
                        minute = c.getInt(minIdx),
                        repeatType = c.getInt(rptIdx),
                        weekdays = weekdays,
                        label = c.getString(labelIdx),
                        isEnabled = c.getInt(c.getColumnIndexOrThrow("isEnabled")) == 1,
                        ringtone = c.getString(ringIdx),
                        saturdayHour = if (c.isNull(satHIdx)) null else c.getInt(satHIdx),
                        saturdayMinute = if (c.isNull(satMIdx)) null else c.getInt(satMIdx),
                    )
                )
            }
        }
        db.close()
        return out
    }

    private fun readWeekScheduleOverrides(context: Context): List<WeekOverride> {
        val db = openDb(context) ?: return emptyList()
        val out = mutableListOf<WeekOverride>()
        val cursor: Cursor? = try {
            db.rawQuery(
                "SELECT weekIndex, weekType FROM $WEEK_SCHEDULE_TABLE",
                null
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query week_schedule", e)
            null
        }
        cursor?.use { c ->
            val wiIdx = c.getColumnIndexOrThrow("weekIndex")
            val wtIdx = c.getColumnIndexOrThrow("weekType")
            while (c.moveToNext()) {
                out.add(WeekOverride(c.getInt(wiIdx), c.getInt(wtIdx)))
            }
        }
        db.close()
        return out
    }

    /**
     * Read holiday / make-up workday sets directly from the holiday_cache
     * table that HolidayService writes. (Dart side never writes the legacy
     * flutter.holiday_dates prefs keys, so reading prefs always yielded
     * empty sets and the native path ignored holidays entirely.)
     * Returns Pair(holidaySet, makeupSet) of yyyy-MM-dd strings.
     */
    private fun readHolidaySetsFromDb(context: Context): Pair<Set<String>, Set<String>> {
        val db = openDb(context) ?: return Pair(emptySet(), emptySet())
        val holidays = mutableSetOf<String>()
        val makeups = mutableSetOf<String>()
        val cursor: Cursor? = try {
            db.rawQuery(
                "SELECT date, isHoliday, isWorkday FROM holiday_cache",
                null
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query holiday_cache", e)
            null
        }
        cursor?.use { c ->
            val dIdx = c.getColumnIndexOrThrow("date")
            val hIdx = c.getColumnIndexOrThrow("isHoliday")
            val wIdx = c.getColumnIndexOrThrow("isWorkday")
            while (c.moveToNext()) {
                val d = c.getString(dIdx)
                if (c.getInt(hIdx) == 1) holidays.add(d)
                if (c.getInt(wIdx) == 1) makeups.add(d)
            }
        }
        db.close()
        return Pair(holidays, makeups)
    }

    // ── Algorithm (mirror of lib/utils/date_utils.dart) ───────────────────

    private fun weekNumber(dateMs: Long): Int {
        val diff = dateMs - WEEK_EPOCH_MS
        // Math.floorDiv keeps negative weeks alternating correctly
        // (Kotlin `/` truncates toward zero, same bug Dart had before fix).
        val days = Math.floorDiv(diff, 86_400_000L)
        return Math.floorDiv(days, 7L).toInt() + 1
    }

    private fun autoWeekType(dateMs: Long): Int {
        return if (weekNumber(dateMs) % 2 != 0) WEEK_SINGLE else WEEK_DOUBLE
    }

    private fun resolveWeekType(
        dateMs: Long,
        overrides: List<WeekOverride>,
    ): Int {
        val wn = weekNumber(dateMs)
        val exact = overrides.firstOrNull { it.weekIndex == wn }
        if (exact != null) return exact.weekType
        val prior = overrides.filter { it.weekIndex < wn }
            .maxByOrNull { it.weekIndex }
        if (prior != null) {
            val distance = wn - prior.weekIndex
            return if (distance % 2 == 0) {
                prior.weekType
            } else {
                if (prior.weekType == WEEK_SINGLE) WEEK_DOUBLE else WEEK_SINGLE
            }
        }
        return autoWeekType(dateMs)
    }

    private fun shouldRingOnDate(
        alarm: AlarmRow,
        date: Calendar,
        overrides: List<WeekOverride>,
        holidaySet: Set<String>,
        makeupSet: Set<String>,
    ): Boolean {
        if (!alarm.isEnabled) return false
        val dateKey = ymd(date)
        if (dateKey in holidaySet) return false
        // Make-up workday (补班): force ring for workday-semantic types only;
        // once/custom fall through to their own rules (mirror of Dart).
        if (dateKey in makeupSet) {
            val isWorkdayType = alarm.repeatType == REPEAT_DAILY ||
                alarm.repeatType == REPEAT_WEEKDAYS ||
                alarm.repeatType == REPEAT_SINGLE_REST ||
                alarm.repeatType == REPEAT_DOUBLE_REST
            if (isWorkdayType) return true
        }

        // Calendar.DAY_OF_WEEK: 1=Sun..7=Sat. Convert to Dart convention.
        val calWd = date.get(Calendar.DAY_OF_WEEK)
        val dartWd = if (calWd == Calendar.SUNDAY) 7 else calWd - 1

        when (alarm.repeatType) {
            REPEAT_ONCE -> {
                if (alarm.weekdays.isNotEmpty()) {
                    return alarm.weekdays.contains(dartWd)
                }
                return true
            }
            REPEAT_DAILY -> {
                if (alarm.weekdays.isNotEmpty()) {
                    return alarm.weekdays.contains(dartWd)
                }
                return true
            }
            REPEAT_WEEKDAYS -> return dartWd in 1..5
            REPEAT_WEEKENDS -> return dartWd == 6 || dartWd == 7
            REPEAT_SINGLE_REST -> {
                if (dartWd == 7) return false
                if (dartWd != 6) return true
                val wt = resolveWeekType(date.timeInMillis, overrides)
                return wt == WEEK_SINGLE
            }
            REPEAT_DOUBLE_REST -> {
                if (dartWd == 6 || dartWd == 7) return false
                return true
            }
            REPEAT_CUSTOM -> return alarm.weekdays.contains(dartWd)
        }
        return false
    }

    private fun alarmTimeForDate(
        alarm: AlarmRow,
        date: Calendar,
        overrides: List<WeekOverride>,
        makeupSet: Set<String>,
    ): Calendar {
        val cal = Calendar.getInstance().apply {
            timeInMillis = date.timeInMillis
            set(Calendar.HOUR_OF_DAY, alarm.hour)
            set(Calendar.MINUTE, alarm.minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (alarm.repeatType == REPEAT_SINGLE_REST &&
            date.get(Calendar.DAY_OF_WEEK) == Calendar.SATURDAY
        ) {
            val wt = resolveWeekType(date.timeInMillis, overrides)
            // 补班周六视为工作日，同样使用周六专用时间（mirror of Dart）
            val isMakeup = ymd(date) in makeupSet
            if (wt == WEEK_SINGLE || isMakeup) {
                val sh = alarm.saturdayHour ?: alarm.hour
                val sm = alarm.saturdayMinute ?: alarm.minute
                cal.set(Calendar.HOUR_OF_DAY, sh)
                cal.set(Calendar.MINUTE, sm)
            }
        }
        return cal
    }

    /**
     * Mirrors AlarmSchedulerService.calculateNextTrigger.
     * Returns the next trigger time in epoch millis, or null if no
     * trigger found within 365 days.
     */
    private fun computeNextTrigger(
        alarm: AlarmRow,
        overrides: List<WeekOverride>,
        holidaySet: Set<String>,
        makeupSet: Set<String>,
        from: Long,
    ): Long? {
        val now = Calendar.getInstance().apply { timeInMillis = from }
        val today = Calendar.getInstance().apply {
            timeInMillis = from
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val todayAlarmTime = alarmTimeForDate(alarm, today, overrides, makeupSet)

        val startCal: Calendar = when (alarm.repeatType) {
            REPEAT_ONCE -> {
                // Mirror Dart: honor weekdays + holiday/makeup for today.
                val todayRings = shouldRingOnDate(alarm, today, overrides, holidaySet, makeupSet)
                if (todayRings && now.before(todayAlarmTime)) return todayAlarmTime.timeInMillis
                return null
            }
            else -> {
                if (now.before(todayAlarmTime)) {
                    today.clone() as Calendar
                } else {
                    (today.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 1) }
                }
            }
        }

        for (i in 0 until 365) {
            val candidate = (startCal.clone() as Calendar).apply {
                add(Calendar.DAY_OF_YEAR, i)
            }
            if (shouldRingOnDate(alarm, candidate, overrides, holidaySet, makeupSet)) {
                val trigger = alarmTimeForDate(alarm, candidate, overrides, makeupSet)
                if (trigger.timeInMillis > from) return trigger.timeInMillis
            }
        }
        return null
    }

    private fun ymd(date: Calendar): String {
        return String.format(
            "%04d-%02d-%02d",
            date.get(Calendar.YEAR),
            date.get(Calendar.MONTH) + 1,
            date.get(Calendar.DAY_OF_MONTH),
        )
    }

    // ── PendingIntent construction (mirror of native scheduleExactAlarm) ─

    private fun buildAlarmPendingIntent(
        context: Context,
        alarmId: Int,
        title: String,
        body: String,
        ringtoneUri: String,
    ): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION_ALARM_FIRE
            putExtra("alarmId", alarmId)
            putExtra("title", title)
            putExtra("body", body)
            putExtra("ringtoneUri", ringtoneUri)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, alarmId, intent, flags)
    }
}
