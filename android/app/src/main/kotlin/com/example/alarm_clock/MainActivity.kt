package com.example.alarm_clock

import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.net.Uri
import android.util.Log
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val RINGTONE_PICK_REQUEST = 1001      // custom audio
        private const val RINGTONE_SYSTEM_REQUEST = 1002    // system ringtone picker
        private const val RINGTONE_DEFAULT_URI = "default"
    }

    private var ringtoneResult: MethodChannel.Result? = null
    private var previewPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Settings channel: open app settings page + check battery optimization
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.alarm_clock/settings"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAppSettings" -> {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = android.net.Uri.fromParts("package", packageName, null)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(null)
                }
                "openFullScreenIntentSettings" -> {
                    // Android 14+: open the USE_FULL_SCREEN_INTENT permission page
                    val intent = Intent(
                        Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT
                    ).apply {
                        data = android.net.Uri.fromParts("package", packageName, null)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(null)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(POWER_SERVICE) as PowerManager
                    val isIgnoring = pm.isIgnoringBatteryOptimizations(packageName)
                    result.success(isIgnoring)
                }
                "openMiuiPermissionEditor" -> {
                    // Open standard Android app info page.
                    // On HyperOS/MIUI: tap "其他权限" → find "后台弹出界面" / "锁屏显示"
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = android.net.Uri.fromParts("package", packageName, null)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    Log.d(TAG, "Opened app details settings for MIUI permission access")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Ringtone channel: get system ringtones + pick custom audio
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.alarm_clock/ringtone"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSystemRingtones" -> {
                    try {
                        val ringtones = getSystemRingtones()
                        result.success(ringtones)
                    } catch (e: Exception) {
                        result.error("RINGTONE_ERROR", e.message, null)
                    }
                }
                "pickCustomAudio" -> {
                    ringtoneResult = result
                    try {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            setType("audio/*")
                            putExtra(Intent.EXTRA_TITLE, "选择闹铃音乐")
                        }
                        startActivityForResult(intent, RINGTONE_PICK_REQUEST)
                    } catch (e: Exception) {
                        ringtoneResult = null
                        result.error("PICK_ERROR", e.message, null)
                    }
                }
                "pickSystemRingtone" -> {
                    ringtoneResult = result
                    try {
                        val existingUri = when (val uri = call.argument<String>("existingUri")) {
                            null, RINGTONE_DEFAULT_URI -> null
                            else -> Uri.parse(uri)
                        }
                        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "选择闹铃铃声")
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                            if (existingUri != null) {
                                putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, existingUri)
                            }
                        }
                        startActivityForResult(intent, RINGTONE_SYSTEM_REQUEST)
                    } catch (e: Exception) {
                        ringtoneResult = null
                        result.error("PICK_ERROR", e.message, null)
                    }
                }
                "previewRingtone" -> {
                    val uri = call.argument<String>("uri") ?: "default"
                    try {
                        previewRingtone(uri)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("PREVIEW_ERROR", e.message, null)
                    }
                }
                "stopPreview" -> {
                    stopPreview()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Alarm ringing channel: start/stop the AlarmRingingService
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.alarm_clock/alarm_ring"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAlarmRing" -> {
                    val ringtoneUri = call.argument<String>("ringtoneUri") ?: "default"
                    val serviceIntent = Intent(this, AlarmRingingService::class.java).apply {
                        action = AlarmRingingService.ACTION_START
                        putExtra("ringtoneUri", ringtoneUri)
                    }
                    AlarmRingingService.start(this, serviceIntent)
                    result.success(null)
                }
                "stopAlarmRing" -> {
                    AlarmRingingService.stop(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Alarm scheduler channel: schedule/cancel exact alarms via AlarmManager
        AlarmScheduler.register(flutterEngine, this)

        // Timer background channel: schedule/cancel native timer alarms + stop ringing
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.alarm_clock/timer_background"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleTimerAlarm" -> {
                    val endTimeMillis = call.argument<Long>("endTimeMillis") ?: run {
                        result.error("INVALID", "endTimeMillis is required", null)
                        return@setMethodCallHandler
                    }
                    scheduleTimerAlarm(endTimeMillis)
                    result.success(null)
                }
                "cancelTimerAlarm" -> {
                    cancelTimerAlarm()
                    result.success(null)
                }
                "stopTimerRing" -> {
                    TimerRingingService.stop(this)
                    result.success(null)
                }
                "startTimerRing" -> {
                    TimerRingingService.start(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Initialize WorkManager manually since the default initializer
        // was removed from AndroidManifest.xml
        initWorkManager()
        // Check if launched from alarm notification or full-screen intent
        checkAlarmLaunch(intent)
        // Check if launched from timer notification or full-screen intent
        checkTimerLaunch(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        checkAlarmLaunch(intent)
        checkTimerLaunch(intent)
    }

    /**
     * Checks if the activity was launched by tapping the alarm notification
     * or full-screen intent. If so, sends the alarm info to Flutter via
     * MethodChannel so it can show the full-screen alarm UI.
     *
     * Includes a retry mechanism: if the Flutter engine isn't ready yet
     * (common when fullScreenIntent launches the app from cold start),
     * we delay 500ms and try again.
     */
    private fun checkAlarmLaunch(intent: Intent?, retryCount: Int = 0) {
        if (intent?.getBooleanExtra("alarm_ring", false) == true) {
            val alarmId = intent.getIntExtra("alarmId", -1)
            Log.d(TAG, "Launched from alarm notification: alarmId=$alarmId, retry=$retryCount")

            val engine = flutterEngine
            if (engine != null) {
                MethodChannel(
                    engine.dartExecutor.binaryMessenger,
                    "com.example.alarm_clock/alarm_fire"
                ).invokeMethod("onAlarmFired", mapOf(
                    "alarmId" to alarmId,
                    "title" to "战马闹钟"
                ))
            } else if (retryCount < 3) {
                // Flutter engine not ready yet — retry after delay
                Log.d(TAG, "Flutter engine not ready, retrying in 500ms (attempt ${retryCount + 1})")
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    checkAlarmLaunch(intent, retryCount + 1)
                }, 500)
            } else {
                Log.w(TAG, "Flutter engine still not ready after $retryCount retries, giving up on alarm launch")
            }
        }
    }

    /**
     * Checks if the activity was launched by the timer ringing notification
     * or full-screen intent. If so, sends a MethodChannel call to Flutter
     * to show the timer full-screen UI.
     */
    private fun checkTimerLaunch(intent: Intent?, retryCount: Int = 0) {
        if (intent?.getBooleanExtra("timer_ring", false) == true) {
            Log.d(TAG, "Launched from timer notification, retry=$retryCount")

            val engine = flutterEngine
            if (engine != null) {
                MethodChannel(
                    engine.dartExecutor.binaryMessenger,
                    "com.example.alarm_clock/timer_fire"
                ).invokeMethod("onTimerFired", null)
            } else if (retryCount < 3) {
                Log.d(TAG, "Flutter engine not ready for timer, retrying in 500ms (attempt ${retryCount + 1})")
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    checkTimerLaunch(intent, retryCount + 1)
                }, 500)
            } else {
                Log.w(TAG, "Flutter engine still not ready after $retryCount retries, giving up on timer launch")
            }
        }
    }

    /**
     * Manually initializes WorkManager and sets up a periodic reschedule
     * check every 6 hours. This ensures alarms are re-scheduled even if
     * the app process was killed and the system missed a broadcast.
     */
    private fun initWorkManager() {
        try {
            val workManager = WorkManager.getInstance(applicationContext)
            Log.d(TAG, "WorkManager initialized successfully")

            // Enqueue a periodic reschedule check every 6 hours
            val periodicWork = PeriodicWorkRequestBuilder<AlarmRescheduleWorker>(
                6, java.util.concurrent.TimeUnit.HOURS
            ).build()
            workManager.enqueueUniquePeriodicWork(
                "alarm_periodic_reschedule",
                ExistingPeriodicWorkPolicy.KEEP,
                periodicWork
            )
            Log.d(TAG, "Periodic alarm reschedule work enqueued")
        } catch (e: Exception) {
            Log.e(TAG, "WorkManager initialization failed", e)
        }
    }

    /**
     * Schedules a native exact alarm via AlarmManager for the countdown timer.
     * When the alarm fires, [TimerReceiver] will play a sound and show a
     * notification, even if the app is in the background or Doze mode.
     */
    private fun scheduleTimerAlarm(endTimeMillis: Long) {
        val alarmManager = getSystemService(ALARM_SERVICE) as android.app.AlarmManager
        val intent = Intent(this, TimerReceiver::class.java).apply {
            action = TimerReceiver.ACTION_TIMER_FIRE
        }
        val pendingIntent = android.app.PendingIntent.getBroadcast(
            this,
            30001,
            intent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                android.app.AlarmManager.RTC_WAKEUP,
                endTimeMillis,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                android.app.AlarmManager.RTC_WAKEUP,
                endTimeMillis,
                pendingIntent
            )
        }
        Log.d(TAG, "Scheduled timer alarm at $endTimeMillis")
    }

    /**
     * Cancels a previously scheduled native timer alarm.
     */
    private fun cancelTimerAlarm() {
        val alarmManager = getSystemService(ALARM_SERVICE) as android.app.AlarmManager
        val intent = Intent(this, TimerReceiver::class.java).apply {
            action = TimerReceiver.ACTION_TIMER_FIRE
        }
        val pendingIntent = android.app.PendingIntent.getBroadcast(
            this,
            30001,
            intent,
            android.app.PendingIntent.FLAG_NO_CREATE or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        pendingIntent?.let {
            alarmManager.cancel(it)
            it.cancel()
        }
        Log.d(TAG, "Canceled timer alarm")
    }

    /**
     * Queries the system's RingtoneManager for all alarm/notification/ringtone
     * sounds and returns them categorized with title, uri, and type fields.
     */
    private fun getSystemRingtones(): List<Map<String, String>> {
        val ringtones = mutableListOf<Map<String, String>>()

        // Add "默认" option that uses the app's built-in alarm sound
        ringtones.add(mapOf(
            "title" to "默认",
            "uri" to "default",
            "type" to "default"
        ))

        // Alarm sounds
        val rmAlarm = RingtoneManager(this)
        rmAlarm.setType(RingtoneManager.TYPE_ALARM)
        val cursorAlarm = rmAlarm.cursor
        while (cursorAlarm.moveToNext()) {
            val title = cursorAlarm.getString(RingtoneManager.TITLE_COLUMN_INDEX)
            val uri = rmAlarm.getRingtoneUri(cursorAlarm.position).toString()
            ringtones.add(mapOf("title" to title, "uri" to uri, "type" to "alarm"))
        }

        // Notification sounds
        val rmNotif = RingtoneManager(this)
        rmNotif.setType(RingtoneManager.TYPE_NOTIFICATION)
        val cursorNotif = rmNotif.cursor
        while (cursorNotif.moveToNext()) {
            val title = cursorNotif.getString(RingtoneManager.TITLE_COLUMN_INDEX)
            val uri = rmNotif.getRingtoneUri(cursorNotif.position).toString()
            ringtones.add(mapOf("title" to title, "uri" to uri, "type" to "notification"))
        }

        // Ringtone (phone call) sounds
        val rmRing = RingtoneManager(this)
        rmRing.setType(RingtoneManager.TYPE_RINGTONE)
        val cursorRing = rmRing.cursor
        while (cursorRing.moveToNext()) {
            val title = cursorRing.getString(RingtoneManager.TITLE_COLUMN_INDEX)
            val uri = rmRing.getRingtoneUri(cursorRing.position).toString()
            ringtones.add(mapOf("title" to title, "uri" to uri, "type" to "ringtone"))
        }

        return ringtones
    }

    /**
     * Play a short preview of the selected ringtone.
     */
    private fun previewRingtone(uri: String) {
        stopPreview()
        try {
            val player = MediaPlayer()
            previewPlayer = player
            if (uri == "default") {
                val afd = resources.openRawResourceFd(R.raw.alarm_sound)
                player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
            } else {
                player.setDataSource(this, Uri.parse(uri))
            }
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            player.isLooping = false
            player.setOnCompletionListener { it.release(); previewPlayer = null }
            player.prepare()
            player.start()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to preview ringtone: $uri", e)
            previewPlayer = null
        }
    }

    /**
     * Stop any currently playing preview.
     */
    private fun stopPreview() {
        try {
            previewPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (_: Exception) {}
        previewPlayer = null
    }

    override fun onDestroy() {
        stopPreview()
        super.onDestroy()
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == RINGTONE_SYSTEM_REQUEST) {
            if (resultCode == RESULT_OK && data != null) {
                val uri = data.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
                if (uri != null) {
                    val title = RingtoneManager.getRingtone(this, uri).getTitle(this)
                    ringtoneResult?.success(mapOf(
                        "title" to title,
                        "uri" to uri.toString()
                    ))
                } else {
                    // User selected "Silent" or default — treat as default
                    ringtoneResult?.success(mapOf(
                        "title" to "默认",
                        "uri" to RINGTONE_DEFAULT_URI
                    ))
                }
            } else {
                ringtoneResult?.success(null)
            }
            ringtoneResult = null
        } else if (requestCode == RINGTONE_PICK_REQUEST) {
            if (resultCode == RESULT_OK && data != null) {
                val uri = data.data
                if (uri != null) {
                    // Take persistent permission so we can access it later
                    try {
                        contentResolver.takePersistableUriPermission(
                            uri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION
                        )
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to take persistable uri permission", e)
                    }

                    // Get display name from the content URI
                    var displayName = "自定义音乐"
                    try {
                        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                            if (cursor.moveToFirst()) {
                                val nameIndex = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                                if (nameIndex >= 0) {
                                    displayName = cursor.getString(nameIndex)
                                    // Remove file extension
                                    displayName = displayName.substringBeforeLast('.')
                                }
                            }
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to get display name", e)
                    }

                    ringtoneResult?.success(mapOf(
                        "title" to displayName,
                        "uri" to uri.toString()
                    ))
                } else {
                    ringtoneResult?.success(null)
                }
            } else {
                ringtoneResult?.success(null)
            }
            ringtoneResult = null
        }
    }
}
