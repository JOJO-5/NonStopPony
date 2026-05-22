package com.example.alarm_clock

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground Service that plays the alarm sound in a loop and vibrates
 * continuously until the user explicitly dismisses the alarm.
 *
 * This is the core fix for Bug #2: `flutter_local_notifications` only
 * plays the notification sound once for a few seconds. A real alarm
 * needs continuous ringing + vibration until the user dismisses it.
 *
 * When started by [AlarmReceiver], it also shows a high-priority
 * alarm notification with fullScreenIntent and a STOP action button.
 */
class AlarmRingingService : Service() {

    companion object {
        private const val TAG = "AlarmRingingService"
        const val CHANNEL_ID = "alarm_ringing_channel"
        const val NOTIFICATION_ID = 20001
        const val ACTION_START = "com.example.alarm_clock.ACTION_START_ALARM"
        const val ACTION_STOP = "com.example.alarm_clock.ACTION_STOP_ALARM"

        private var mediaPlayer: MediaPlayer? = null
        private var vibrator: Vibrator? = null
        private val vibrationHandler = Handler(Looper.getMainLooper())
        private var isRinging = false

        // Current alarm info for notification
        private var currentAlarmId: Int = -1
        private var currentTitle: String = "战马闹钟"
        private var currentBody: String = "闹钟响了"

        /** Vibration pattern: [delay, on, off, on, off, ...] in milliseconds */
        private val vibrationTimings = longArrayOf(0, 500, 200, 500, 200, 500)
        /** Amplitudes for the vibration pattern (0-255) */
        private val vibrationAmplitudes = intArrayOf(0, 255, 0, 200, 0, 255)

        /**
         * Performs a single vibration pattern.
         * Uses VibrationEffect.createWaveform for API 26+.
         * Repeated via [vibrationRunnable] to keep vibrating continuously.
         */
        @JvmStatic
        private fun vibrateOnce() {
            try {
                vibrator?.let { vib ->
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val effect = VibrationEffect.createWaveform(
                            vibrationTimings,
                            vibrationAmplitudes,
                            -1
                        )
                        vib.vibrate(effect)
                    } else {
                        @Suppress("DEPRECATION")
                        vib.vibrate(vibrationTimings, -1)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        private val vibrationRunnable = object : Runnable {
            override fun run() {
                if (!isRinging) return
                vibrateOnce()
                // Re-post every 2 seconds to keep vibrating
                vibrationHandler.postDelayed(this, 2000)
            }
        }

        /**
         * Convenience method to start the ringing service from any Context.
         */
        fun start(context: Context) {
            val intent = Intent(context, AlarmRingingService::class.java).apply {
                action = ACTION_START
            }
            context.startForegroundService(intent)
        }

        /**
         * Convenience method to stop the ringing service from any Context.
         */
        fun stop(context: Context) {
            val intent = Intent(context, AlarmRingingService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: action=${intent?.action}, alarmId=${intent?.getIntExtra("alarmId", -1)}")
        when (intent?.action) {
            ACTION_STOP -> {
                stopRinging()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                // Read alarm info from intent extras
                intent.getIntExtra("alarmId", -1).let { if (it >= 0) currentAlarmId = it }
                intent.getStringExtra("title")?.let { currentTitle = it }
                intent.getStringExtra("body")?.let { currentBody = it }

                val notification = buildForegroundNotification()
                startForeground(NOTIFICATION_ID, notification)
                startRinging()
            }
            else -> {
                // If no action specified, default to start
                val notification = buildForegroundNotification()
                startForeground(NOTIFICATION_ID, notification)
                startRinging()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        stopRinging()
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        stopRinging()
        super.onTaskRemoved(rootIntent)
    }

    /**
     * Starts the alarm sound (MediaPlayer looping) and vibration.
     */
    private fun startRinging() {
        if (isRinging) return
        isRinging = true

        Log.d(TAG, "Starting alarm ringing: alarmId=$currentAlarmId, title=$currentTitle")

        // --- MediaPlayer: loop alarm sound ---
        try {
            mediaPlayer = MediaPlayer.create(applicationContext, R.raw.alarm_sound).apply {
                isLooping = true
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setLegacyStreamType(AudioManager.STREAM_ALARM)
                        .build()
                )
                setVolume(1.0f, 1.0f)
                start()
            }
        } catch (e: Exception) {
            Log.e(TAG, "MediaPlayer create failed", e)
            // Fallback: try creating with different method
            try {
                mediaPlayer = MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .setLegacyStreamType(AudioManager.STREAM_ALARM)
                            .build()
                    )
                    setDataSource(
                        applicationContext,
                        android.net.Uri.parse("android.resource://${packageName}/${R.raw.alarm_sound}")
                    )
                    isLooping = true
                    setVolume(1.0f, 1.0f)
                    prepare()
                    start()
                }
            } catch (e2: Exception) {
                Log.e(TAG, "MediaPlayer fallback also failed", e2)
            }
        }

        // --- Vibrator: continuous vibration pattern ---
        initVibrator()
        vibrateOnce()
        vibrationHandler.postDelayed(vibrationRunnable, 2000)
    }

    /**
     * Stops the alarm sound and vibration, then stops the service.
     */
    private fun stopRinging() {
        Log.d(TAG, "Stopping alarm ringing")
        isRinging = false

        // Stop MediaPlayer
        try {
            mediaPlayer?.apply {
                if (isPlaying) {
                    stop()
                }
                release()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        mediaPlayer = null

        // Stop Vibrator
        try {
            vibrator?.cancel()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        vibrator = null
        vibrationHandler.removeCallbacks(vibrationRunnable)

        // Also cancel the alarm notification (from flutter_local_notifications)
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(currentAlarmId)
        } catch (_: Exception) {}

        // Reset state
        currentAlarmId = -1
        currentTitle = "战马闹钟"
        currentBody = "闹钟响了"

        // Stop foreground and service
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        stopSelf()
    }

    /**
     * Initializes the Vibrator service, compatible with Android 12+
     * (VibratorManager) and older versions (deprecated Vibrator service).
     */
    private fun initVibrator() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager =
                getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            vibrator = vibratorManager?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

        // Check if device has a vibrator
        if (vibrator == null || !(vibrator?.hasVibrator() ?: false)) {
            vibrator = null
        }
    }

    /**
     * Creates the notification channel for the foreground service notification.
     * Required on Android 8+ (API 26+).
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "闹钟响铃",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "战马闹钟响铃通知"
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                enableVibration(true)
                // Don't set sound — MediaPlayer handles audio
                setSound(null, null)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    /**
     * Builds the foreground service notification.
     *
     * Uses HIGH importance so it shows as a heads-up notification.
     * Contains:
     * - Full-screen intent (launches MainActivity for lock screen display)
     * - STOP action button
     * - Ongoing flag so it can't be swiped away
     */
    private fun buildForegroundNotification(): Notification {
        // Intent to open the app when notification is tapped
        val contentIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("alarmId", currentAlarmId)
            putExtra("alarm_ring", true)
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this,
            currentAlarmId,
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Intent to stop the alarm via notification action
        val stopIntent = Intent(this, AlarmRingingService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Full-screen intent for lock screen display
        val fullScreenIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("alarmId", currentAlarmId)
            putExtra("alarm_ring", true)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            currentAlarmId + 10000,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(currentTitle)
            .setContentText(currentBody)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setAutoCancel(false)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setDefaults(0) // No default sound/vibration — MediaPlayer handles it
            .setSound(null)
            .setContentIntent(contentPendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "关闭闹钟",
                stopPendingIntent
            )
            .build()
    }
}
