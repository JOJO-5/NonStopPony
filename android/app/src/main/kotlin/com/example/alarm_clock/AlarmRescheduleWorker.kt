package com.example.alarm_clock

import android.content.Context
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.MethodChannel

/**
 * WorkManager Worker that reschedules all enabled alarms after device reboot.
 *
 * Spins up a background FlutterEngine (no UI) to invoke the Dart-side
 * reschedule logic via MethodChannel, then tears the engine down.
 *
 * This approach avoids the Android 10+ ban on background startActivity.
 */
class AlarmRescheduleWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : Worker(context, workerParams) {

    override fun doWork(): Result {
        Log.d("AlarmRescheduleWorker", "Starting alarm reschedule after boot")
        return try {
            @Suppress("DEPRECATION")
            val loader = FlutterLoader()
            loader.startInitialization(context)
            loader.ensureInitializationComplete(context, null)

            val engine = FlutterEngine(context)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )

            // Give the Dart isolate a moment to initialise before invoking the channel.
            Thread.sleep(3000)

            MethodChannel(
                engine.dartExecutor.binaryMessenger,
                "com.example.alarm_clock/boot_receiver"
            ).invokeMethod("rescheduleAlarms", null)

            // Allow async Dart work to complete.
            Thread.sleep(5000)
            engine.destroy()

            Log.d("AlarmRescheduleWorker", "Alarm reschedule work completed")
            Result.success()
        } catch (e: Exception) {
            Log.e("AlarmRescheduleWorker", "Reschedule failed", e)
            Result.retry()
        }
    }
}
