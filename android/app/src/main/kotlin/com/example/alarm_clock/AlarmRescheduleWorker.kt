package com.example.alarm_clock

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.MethodChannel

/**
 * WorkManager Worker that reschedules all enabled alarms after device reboot
 * or app update.
 *
 * Spins up a background FlutterEngine (no UI) to invoke the Dart-side
 * reschedule logic via MethodChannel, then tears the engine down.
 *
 * Uses a callback-based approach instead of fixed Thread.sleep to wait for
 * the Dart isolate to be ready. Falls back to a maximum timeout if the
 * callback is never received.
 */
class AlarmRescheduleWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : Worker(context, workerParams) {

    companion object {
        private const val TAG = "AlarmRescheduleWorker"
        private const val CHANNEL = "com.example.alarm_clock/boot_receiver"
        private const val MAX_WAIT_MILLIS = 15000L  // Maximum total wait time
    }

    override fun doWork(): Result {
        Log.d(TAG, "Starting alarm reschedule after boot/update")
        return try {
            @Suppress("DEPRECATION")
            val loader = FlutterLoader()
            loader.startInitialization(context)
            loader.ensureInitializationComplete(context, null)

            val engine = FlutterEngine(context)
            val handler = Handler(Looper.getMainLooper())
            val callbackReceived = BooleanArray(1)
            val lock = Object()

            // Set up a MethodChannel handler so the Dart side can signal when
            // it has finished rescheduling alarms.
            MethodChannel(
                engine.dartExecutor.binaryMessenger,
                CHANNEL
            ).setMethodCallHandler { call, result ->
                if (call.method == "rescheduleComplete") {
                    synchronized(lock) {
                        callbackReceived[0] = true
                        lock.notifyAll()
                    }
                    result.success(null)
                } else if (call.method == "rescheduleAlarms") {
                    // Dart side acknowledges reschedule request
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }

            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )

            // Give the Dart isolate a moment to initialize before invoking the channel.
            Thread.sleep(3000)

            MethodChannel(
                engine.dartExecutor.binaryMessenger,
                CHANNEL
            ).invokeMethod("rescheduleAlarms", null)

            // Wait for the Dart side to call back "rescheduleComplete",
            // with a maximum timeout so we don't block forever.
            synchronized(lock) {
                val deadline = System.currentTimeMillis() + MAX_WAIT_MILLIS
                while (!callbackReceived[0]) {
                    val remaining = deadline - System.currentTimeMillis()
                    if (remaining <= 0) {
                        Log.w(TAG, "Timed out waiting for rescheduleComplete callback")
                        break
                    }
                    lock.wait(remaining)
                }
            }

            engine.destroy()
            Log.d(TAG, "Alarm reschedule work completed (callbackReceived=${callbackReceived[0]})")
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Reschedule failed", e)
            Result.retry()
        }
    }
}
