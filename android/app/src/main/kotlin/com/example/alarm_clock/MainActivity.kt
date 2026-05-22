package com.example.alarm_clock

import android.content.Intent
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
    }

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
}
