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
 * Foreground Service that plays the timer alarm sound in a loop and vibrates
 * continuously until the user explicitly dismisses the timer.
 *
 * Mirrors [AlarmRingingService] but uses the timer notification channel
 * and timer-specific fullScreenIntent extras.
 */
class TimerRingingService : Service() {

    companion object {
        private const val TAG = "TimerRingingService"
        const val CHANNEL_ID = "timer_ringing_channel"
        const val NOTIFICATION_ID = 30001
        const val ACTION_START = "com.example.alarm_clock.ACTION_START_TIMER"
        const val ACTION_STOP = "com.example.alarm_clock.ACTION_STOP_TIMER"

        private var mediaPlayer: MediaPlayer? = null
        private var vibrator: Vibrator? = null
        private val vibrationHandler = Handler(Looper.getMainLooper())
        private var isRinging = false

        private val vibrationTimings = longArrayOf(0, 500, 200, 500, 200, 500)
        private val vibrationAmplitudes = intArrayOf(0, 255, 0, 200, 0, 255)

        @JvmStatic
        private fun vibrateOnce() {
            try {
                vibrator?.let { vib ->
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val effect = VibrationEffect.createWaveform(
                            vibrationTimings, vibrationAmplitudes, -1
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
                vibrationHandler.postDelayed(this, 2000)
            }
        }

        fun start(context: Context) {
            val intent = Intent(context, TimerRingingService::class.java).apply {
                action = ACTION_START
            }
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, TimerRingingService::class.java).apply {
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
        when (intent?.action) {
            ACTION_STOP -> {
                stopRinging()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                val notification = buildForegroundNotification()
                startForeground(NOTIFICATION_ID, notification)
                startRinging()
            }
            else -> {
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

    private fun startRinging() {
        if (isRinging) return
        isRinging = true

        Log.d(TAG, "Starting timer ringing")

        // MediaPlayer: loop timer alarm sound
        try {
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setLegacyStreamType(AudioManager.STREAM_ALARM)
                .build()

            mediaPlayer = MediaPlayer.create(applicationContext, R.raw.alarm_sound).apply {
                isLooping = true
                setAudioAttributes(audioAttributes)
                setVolume(1.0f, 1.0f)
                start()
            }
        } catch (e: Exception) {
            Log.e(TAG, "MediaPlayer create failed", e)
        }

        // Vibrator
        initVibrator()
        vibrateOnce()
        vibrationHandler.postDelayed(vibrationRunnable, 2000)
    }

    private fun stopRinging() {
        Log.d(TAG, "Stopping timer ringing")
        isRinging = false

        try {
            mediaPlayer?.apply {
                if (isPlaying) stop()
                release()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        mediaPlayer = null

        try {
            vibrator?.cancel()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        vibrator = null
        vibrationHandler.removeCallbacks(vibrationRunnable)

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

    private fun initVibrator() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager =
                getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            vibrator = vibratorManager?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
        if (vibrator == null || !(vibrator?.hasVibrator() ?: false)) {
            vibrator = null
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "计时器响铃",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "计时器完成响铃通知"
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                enableVibration(true)
                setSound(null, null)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildForegroundNotification(): Notification {
        // Content intent: open app
        val contentIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("timer_ring", true)
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this,
            NOTIFICATION_ID,
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Stop action
        val stopIntent = Intent(this, TimerRingingService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            2,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Full-screen intent for lock screen display
        val fullScreenIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("timer_ring", true)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            NOTIFICATION_ID + 10000,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("计时完成")
            .setContentText("时间到!")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setAutoCancel(false)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setDefaults(0)
            .setSound(null)
            .setContentIntent(contentPendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "关闭计时器",
                stopPendingIntent
            )
            .build()
    }
}
