package com.example.alarm_clock

import android.content.Intent
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.media.RingtoneManager
import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val RINGTONE_PICK_REQUEST = 1001
    }

    private var ringtoneResult: MethodChannel.Result? = null

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
                    AlarmRingingService.start(this)
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
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Check if launched from alarm notification or full-screen intent
        checkAlarmLaunch(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        checkAlarmLaunch(intent)
    }

    /**
     * Checks if the activity was launched by tapping the alarm notification
     * or full-screen intent. If so, sends the alarm info to Flutter via
     * MethodChannel so it can show the full-screen alarm UI.
     */
    private fun checkAlarmLaunch(intent: Intent?) {
        if (intent?.getBooleanExtra("alarm_ring", false) == true) {
            val alarmId = intent.getIntExtra("alarmId", -1)
            Log.d(TAG, "Launched from alarm notification: alarmId=$alarmId")

            // Notify Flutter to show the full-screen alarm UI
            flutterEngine?.let { engine ->
                MethodChannel(
                    engine.dartExecutor.binaryMessenger,
                    "com.example.alarm_clock/alarm_fire"
                ).invokeMethod("onAlarmFired", mapOf(
                    "alarmId" to alarmId,
                    "title" to "战马闹钟"
                ))
            }
        }
    }

    /**
     * Queries the system's RingtoneManager for all alarm-type ringtones
     * and returns them as a list of maps with title and uri fields.
     */
    private fun getSystemRingtones(): List<Map<String, String>> {
        val ringtones = mutableListOf<Map<String, String>>()

        // Add "默认" option that uses the app's built-in alarm sound
        ringtones.add(mapOf(
            "title" to "默认",
            "uri" to "default"
        ))

        val rm = RingtoneManager(this)
        rm.setType(RingtoneManager.TYPE_ALARM)
        val cursor = rm.cursor

        while (cursor.moveToNext()) {
            val title = cursor.getString(RingtoneManager.TITLE_COLUMN_INDEX)
            val uri = rm.getRingtoneUri(cursor.position).toString()
            ringtones.add(mapOf(
                "title" to title,
                "uri" to uri
            ))
        }

        // Also add notification sounds as they can also be used as alarms
        val rmNotif = RingtoneManager(this)
        rmNotif.setType(RingtoneManager.TYPE_NOTIFICATION)
        val cursorNotif = rmNotif.cursor

        while (cursorNotif.moveToNext()) {
            val title = cursorNotif.getString(RingtoneManager.TITLE_COLUMN_INDEX)
            val uri = rmNotif.getRingtoneUri(cursorNotif.position).toString()
            ringtones.add(mapOf(
                "title" to title,
                "uri" to uri
            ))
        }

        // Also add ringtone sounds
        val rmRing = RingtoneManager(this)
        rmRing.setType(RingtoneManager.TYPE_RINGTONE)
        val cursorRing = rmRing.cursor

        while (cursorRing.moveToNext()) {
            val title = cursorRing.getString(RingtoneManager.TITLE_COLUMN_INDEX)
            val uri = rmRing.getRingtoneUri(cursorRing.position).toString()
            ringtones.add(mapOf(
                "title" to title,
                "uri" to uri
            ))
        }

        return ringtones
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == RINGTONE_PICK_REQUEST) {
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
