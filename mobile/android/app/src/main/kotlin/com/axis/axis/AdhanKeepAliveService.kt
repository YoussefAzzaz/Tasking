package com.axis.axis

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import androidx.core.app.NotificationCompat

class AdhanKeepAliveService : Service() {

    companion object {
        const val PREFS_NAME = "axis_adhan_prefs"
        const val KEY_KEEP_ALIVE_ENABLED = "keep_alive_enabled"

        const val ACTION_START = "com.axis.axis.action.START_KEEP_ALIVE"
        const val ACTION_STOP = "com.axis.axis.action.STOP_KEEP_ALIVE"
        const val ACTION_TRIGGER_ADHAN_ALARM = "com.axis.axis.action.TRIGGER_ADHAN_ALARM"

        const val CHANNEL_ID = "axis_adhan_keep_alive"
        const val WAKEUP_CHANNEL_ID = "axis_adhan_wakeup_silent"
        const val NOTIFICATION_ID = 9001
        const val WAKEUP_NOTIFICATION_ID = 9002

        const val EXTRA_PRAYER_ID = "prayer_id"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_PRAYER_NAME_AR = "prayer_name_ar"
        const val EXTRA_PRAYER_TIME = "prayer_time"

        @Volatile
        var isRunning: Boolean = false
            private set

        fun isKeepAliveEnabled(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getBoolean(KEY_KEEP_ALIVE_ENABLED, false)
        }

        fun setKeepAliveEnabled(context: Context, enabled: Boolean) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putBoolean(KEY_KEEP_ALIVE_ENABLED, enabled).apply()
        }

        fun startService(context: Context) {
            setKeepAliveEnabled(context, true)
            val intent = Intent(context, AdhanKeepAliveService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            setKeepAliveEnabled(context, false)
            context.stopService(Intent(context, AdhanKeepAliveService::class.java))
        }

        fun cancelWakeupNotification(context: Context) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.cancel(WAKEUP_NOTIFICATION_ID)
        }

        fun buildMainActivityAdhanIntent(
            context: Context,
            prayerId: String?,
            prayerName: String?,
            prayerNameAr: String?,
            prayerTime: String?,
        ): Intent {
            return Intent(context, MainActivity::class.java).apply {
                action = "com.axis.axis.LAUNCH_ADHAN_ALARM"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                putExtra("launch_adhan_screen", true)
                putExtra(EXTRA_PRAYER_ID, prayerId ?: "")
                putExtra(EXTRA_PRAYER_NAME, prayerName ?: "Prayer")
                putExtra(EXTRA_PRAYER_NAME_AR, prayerNameAr ?: "الصلاة")
                putExtra(EXTRA_PRAYER_TIME, prayerTime ?: "")
            }
        }

        fun bringAppToForegroundForAdhan(
            context: Context,
            prayerId: String?,
            prayerName: String?,
            prayerNameAr: String?,
            prayerTime: String?,
        ) {
            val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            val isScreenOn = pm?.isInteractive ?: false

            val launchIntent = buildMainActivityAdhanIntent(
                context,
                prayerId,
                prayerName,
                prayerNameAr,
                prayerTime,
            )

            val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            val fullScreenPendingIntent = PendingIntent.getActivity(
                context,
                WAKEUP_NOTIFICATION_ID,
                launchIntent,
                pendingFlags,
            )

            // Post notification
            try {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                if (nm != null) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        nm.getNotificationChannel(WAKEUP_CHANNEL_ID) == null
                    ) {
                        val ch = NotificationChannel(
                            WAKEUP_CHANNEL_ID,
                            "Adhan Screen Wakeup",
                            NotificationManager.IMPORTANCE_HIGH,
                        ).apply {
                            description = "Adhan notification at prayer time"
                            setSound(null, null)
                            enableVibration(false)
                            setShowBadge(false)
                            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                        }
                        nm.createNotificationChannel(ch)
                    }

                    val title = "Adhan: ${prayerName ?: "Prayer"}"
                    val body = if (!prayerTime.isNullOrEmpty()) {
                        "It is time for ${prayerName ?: "Prayer"} ($prayerTime)"
                    } else {
                        "Time for prayer"
                    }

                    val notifBuilder = NotificationCompat.Builder(context, WAKEUP_CHANNEL_ID)
                        .setSmallIcon(R.mipmap.ic_launcher)
                        .setContentTitle(title)
                        .setContentText(body)
                        .setPriority(NotificationCompat.PRIORITY_MAX)
                        .setCategory(NotificationCompat.CATEGORY_ALARM)
                        .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                        .setOngoing(false)
                        .setAutoCancel(true)
                        .setSilent(true)
                        .setContentIntent(fullScreenPendingIntent)

                    // If phone is ON (screen interactive), fullScreenIntent can also be attached.
                    // If phone is OFF, do NOT set fullScreenIntent so screen does not wake into the activity!
                    if (isScreenOn) {
                        notifBuilder.setFullScreenIntent(fullScreenPendingIntent, true)
                    }

                    nm.notify(WAKEUP_NOTIFICATION_ID, notifBuilder.build())
                }
            } catch (_: Exception) {}

            // When the phone is ON (screen is interactive): bring MainActivity forward to show adhan screen with sound!
            // When the phone is OFF: do NOT launch activity, notification only.
            if (isScreenOn) {
                try {
                    val wakeLock = pm?.newWakeLock(
                        PowerManager.PARTIAL_WAKE_LOCK,
                        "axis:adhan_wakeup_lock",
                    )
                    wakeLock?.acquire(15_000L)
                } catch (_: Exception) {}

                try {
                    context.startActivity(launchIntent)
                } catch (_: Exception) {
                    try {
                        fullScreenPendingIntent.send()
                    } catch (_: Exception) {}
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        ensureKeepAliveChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                setKeepAliveEnabled(this, false)
                isRunning = false
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_TRIGGER_ADHAN_ALARM -> {
                promoteToForeground()
                bringAppToForegroundForAdhan(
                    context = this,
                    prayerId = intent.getStringExtra(EXTRA_PRAYER_ID),
                    prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME),
                    prayerNameAr = intent.getStringExtra(EXTRA_PRAYER_NAME_AR),
                    prayerTime = intent.getStringExtra(EXTRA_PRAYER_TIME),
                )
                return START_STICKY
            }
            else -> {
                setKeepAliveEnabled(this, true)
                promoteToForeground()
                return START_STICKY
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
        if (isKeepAliveEnabled(this)) {
            scheduleRestart(1500L)
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        if (isKeepAliveEnabled(this)) {
            scheduleRestart(1500L)
        }
    }

    private fun scheduleRestart(delayMs: Long) {
        try {
            val restartIntent = Intent(applicationContext, AdhanKeepAliveService::class.java).apply {
                action = ACTION_START
            }
            val flags = PendingIntent.FLAG_ONE_SHOT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                PendingIntent.getForegroundService(applicationContext, 9003, restartIntent, flags)
            } else {
                PendingIntent.getService(applicationContext, 9003, restartIntent, flags)
            }
            val alarmManager = applicationContext.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            val triggerAt = SystemClock.elapsedRealtime() + delayMs
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager?.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent)
            } else {
                alarmManager?.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent)
            }
        } catch (_: Exception) {}
    }

    private fun ensureKeepAliveChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            if (nm != null && nm.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Adhan Background Service",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "Keeps Axis ready to sound Adhan alarms reliably on time"
                    setSound(null, null)
                    enableVibration(false)
                    setShowBadge(false)
                    lockscreenVisibility = Notification.VISIBILITY_SECRET
                }
                nm.createNotificationChannel(channel)
            }
        }
    }

    private fun promoteToForeground() {
        ensureKeepAliveChannel()
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        val pendingIntent = PendingIntent.getActivity(this, 0, openAppIntent, flags)

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Axis Adhan Guardian Active")
            .setContentText("Monitoring prayer times in the background")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setSilent(true)
            .setShowWhen(false)
            .setContentIntent(pendingIntent)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        isRunning = true
    }
}

