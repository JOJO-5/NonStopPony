package com.example.alarm_clock

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * WorkManager worker that runs the Dart-side alarm bookkeeping without the UI:
 * a full reschedule after boot/update, or the dismissal bookkeeping for a
 * single alarm (disable a one-shot alarm / schedule the next occurrence).
 *
 * Implementation notes (these were bugs before):
 * - `FlutterLoader.startInitialization` / `ensureInitializationComplete` are
 *   main-thread only. `doWork()` runs on a WorkManager background thread, so
 *   calling them by hand threw and the worker returned [Result.retry] forever
 *   (visible as a retry roughly every minute). `FlutterEngine` already performs
 *   loader initialization, so we simply build the engine on the main thread.
 * - A headless engine does not inherit the activity's plugin registration, so
 *   plugins (sqflite, notifications, ...) and the app's own AlarmManager
 *   channel are registered explicitly.
 * - Instead of sleeping a fixed 3 s and hoping the Dart isolate is ready, the
 *   invocation is retried until the Dart handler answers.
 * - Failures return [Result.failure] rather than [Result.retry]: rescheduling
 *   also happens on every app launch and via [BootReceiver]'s native path, so
 *   an endless retry loop only wastes battery and spams logcat.
 */
class AlarmRescheduleWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : Worker(context, workerParams) {

    companion object {
        private const val TAG = "AlarmRescheduleWorker"
        private const val CHANNEL = "com.example.alarm_clock/boot_receiver"
        private const val KEY_DISMISSED_ALARM_ID = "dismissedAlarmId"
        private const val MAX_WAIT_MILLIS = 20_000L
        private const val INVOKE_RETRY_MILLIS = 300L
        private const val MAX_INVOKE_ATTEMPTS = 40

        /**
         * Input data for a run that also performs dismissal bookkeeping for
         * [dismissedAlarmId]. Pass -1 for a plain "reschedule everything" run.
         */
        fun inputDataFor(dismissedAlarmId: Int) =
            workDataOf(KEY_DISMISSED_ALARM_ID to dismissedAlarmId)
    }

    override fun doWork(): Result {
        val dismissedAlarmId = inputData.getInt(KEY_DISMISSED_ALARM_ID, -1)
        Log.d(TAG, "Reschedule worker started (dismissedAlarmId=$dismissedAlarmId)")

        val finished = CountDownLatch(1)
        val succeeded = AtomicBoolean(false)
        val engineRef = AtomicReference<FlutterEngine?>(null)
        val mainHandler = Handler(Looper.getMainLooper())

        mainHandler.post {
            try {
                val engine = FlutterEngine(context)
                engineRef.set(engine)

                // Headless engines are not covered by MainActivity's
                // configureFlutterEngine, so register plugins + the custom
                // AlarmManager channel this run depends on.
                GeneratedPluginRegistrant.registerWith(engine)
                AlarmScheduler.register(engine, context)

                val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                channel.setMethodCallHandler { call, result ->
                    if (call.method == "rescheduleComplete") {
                        succeeded.set(true)
                        finished.countDown()
                    }
                    result.success(null)
                }

                engine.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint.createDefault()
                )

                var attempt = 0
                fun invokeReschedule() {
                    if (finished.count == 0L) return
                    if (attempt++ >= MAX_INVOKE_ATTEMPTS) {
                        Log.w(TAG, "Dart handler never became ready — giving up")
                        finished.countDown()
                        return
                    }
                    channel.invokeMethod(
                        "rescheduleAlarms",
                        mapOf("dismissedAlarmId" to dismissedAlarmId),
                        object : MethodChannel.Result {
                            override fun success(result: Any?) = Unit
                            override fun error(code: String, message: String?, details: Any?) {
                                mainHandler.postDelayed({ invokeReschedule() }, INVOKE_RETRY_MILLIS)
                            }

                            override fun notImplemented() {
                                mainHandler.postDelayed({ invokeReschedule() }, INVOKE_RETRY_MILLIS)
                            }
                        }
                    )
                }
                invokeReschedule()
            } catch (e: Exception) {
                Log.e(TAG, "Reschedule worker could not start the Flutter engine", e)
                finished.countDown()
            }
        }

        val completed = finished.await(MAX_WAIT_MILLIS, TimeUnit.MILLISECONDS)
        mainHandler.post { engineRef.get()?.destroy() }

        return if (succeeded.get()) {
            Log.d(TAG, "Reschedule completed (dismissedAlarmId=$dismissedAlarmId)")
            if (dismissedAlarmId >= 0) {
                notifyDismissed(dismissedAlarmId)
            }
            Result.success()
        } else {
            Log.w(
                TAG,
                "Reschedule did not confirm completion (awaitCompleted=$completed) — " +
                    "alarms stay scheduled via the native path and the next app launch"
            )
            Result.failure()
        }
    }

    /**
     * Tells a live app instance that [alarmId] was dismissed so its alarm list
     * can refresh. Sent from here — after the database write has landed —
     * rather than when the notification is tapped, otherwise the UI would
     * reload the state from before the dismissal.
     *
     * Package-scoped, so it is a no-op when the app is not running.
     */
    private fun notifyDismissed(alarmId: Int) {
        try {
            val intent = Intent(AlarmRingingService.ACTION_ALARM_DISMISSED).apply {
                setPackage(context.packageName)
                putExtra("alarmId", alarmId)
            }
            context.sendBroadcast(intent)
            Log.d(TAG, "Broadcast alarm $alarmId dismissal for UI refresh")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to broadcast alarm dismissal", e)
        }
    }
}
