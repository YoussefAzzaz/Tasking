package com.axis.axis

import android.app.AlarmManager
import android.app.KeyguardManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SETTINGS_CHANNEL = "com.axis.axis/settings"
    private val UPDATER_CHANNEL = "com.axis.axis/updater"
    private var settingsChannel: MethodChannel? = null
    private var updaterChannel: MethodChannel? = null
    private var pendingAdhanPayload: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val updater = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL)
        updaterChannel = updater
        updater.setMethodCallHandler { call, result ->
            when (call.method) {
                "fetchJson" -> {
                    val url = call.argument<String>("url")
                    val headers = call.argument<Map<String, String>>("headers")
                    if (url.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "Missing url", null)
                    } else {
                        NativeUpdateDownloader.fetchJson(applicationContext, url, headers, result)
                    }
                }
                "downloadFile" -> {
                    val url = call.argument<String>("url")
                    val destPath = call.argument<String>("destinationPath")
                    val expectedSize = (call.argument<Number>("expectedSize"))?.toLong() ?: 0L
                    if (url.isNullOrBlank() || destPath.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "Missing url or destinationPath", null)
                    } else {
                        NativeUpdateDownloader.downloadFile(
                            context = applicationContext,
                            urlStr = url,
                            destinationPath = destPath,
                            expectedSize = expectedSize,
                            onProgress = { receivedBytes, totalBytes ->
                                updaterChannel?.invokeMethod(
                                    "onDownloadProgress",
                                    mapOf(
                                        "receivedBytes" to receivedBytes,
                                        "totalBytes" to totalBytes,
                                    ),
                                )
                            },
                            result = result,
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL)
        settingsChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "openDndSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            try {
                                val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (_: Exception) {
                                // Fallback to application details if OEM restricts policy settings intent
                                val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.parse("package:$packageName")
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(fallback)
                                result.success(true)
                            }
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.localizedMessage, null)
                    }
                }
                "openExactAlarmSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            try {
                                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                    data = Uri.parse("package:$packageName")
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (_: Exception) {
                                val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.parse("package:$packageName")
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(fallback)
                                result.success(true)
                            }
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.localizedMessage, null)
                    }
                }
                "openAppNotificationSettings" -> {
                    try {
                        val intent = Intent().apply {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            } else {
                                action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                                data = Uri.parse("package:$packageName")
                            }
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        try {
                            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(fallback)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("INTENT_ERROR", e2.localizedMessage, null)
                        }
                    }
                }
                "isDndOverrideGranted" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                        result.success(nm?.isNotificationPolicyAccessGranted == true)
                    } else {
                        result.success(true)
                    }
                }
                "isExactAlarmGranted" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                        result.success(alarmManager?.canScheduleExactAlarms() == true)
                    } else {
                        result.success(true)
                    }
                }
                "isNotificationGranted" -> {
                    val granted = NotificationManagerCompat.from(this).areNotificationsEnabled()
                    result.success(granted)
                }
                "startKeepAliveService" -> {
                    try {
                        AdhanKeepAliveService.startService(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.localizedMessage, null)
                    }
                }
                "stopKeepAliveService" -> {
                    try {
                        AdhanKeepAliveService.stopService(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.localizedMessage, null)
                    }
                }
                "isKeepAliveRunning" -> {
                    result.success(
                        AdhanKeepAliveService.isRunning ||
                            AdhanKeepAliveService.isKeepAliveEnabled(applicationContext),
                    )
                }
                "cancelNativeWakeupNotification" -> {
                    AdhanKeepAliveService.cancelWakeupNotification(applicationContext)
                    result.success(true)
                }
                "bringToForegroundForAdhan" -> {
                    val prayerId = call.argument<String>("prayerId")
                    val prayerName = call.argument<String>("prayerName")
                    val prayerNameAr = call.argument<String>("prayerNameAr")
                    val prayerTime = call.argument<String>("prayerTime")
                    AdhanKeepAliveService.bringAppToForegroundForAdhan(
                        context = applicationContext,
                        prayerId = prayerId,
                        prayerName = prayerName,
                        prayerNameAr = prayerNameAr,
                        prayerTime = prayerTime,
                    )
                    result.success(true)
                }
                "consumePendingAdhanLaunch" -> {
                    val payload = pendingAdhanPayload
                    pendingAdhanPayload = null
                    result.success(payload)
                }
                "scheduleNativeAdhanAlarm" -> {
                    try {
                        val requestCode = call.argument<Int>("requestCode") ?: 0
                        val triggerAtMillis = (call.argument<Number>("triggerAtMillis"))?.toLong()
                        if (triggerAtMillis == null || triggerAtMillis <= System.currentTimeMillis()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val prayerId = call.argument<String>("prayerId") ?: ""
                        val prayerName = call.argument<String>("prayerName") ?: "Prayer"
                        val prayerNameAr = call.argument<String>("prayerNameAr") ?: "الصلاة"
                        val prayerTime = call.argument<String>("prayerTime") ?: ""

                        val alarmIntent = Intent(applicationContext, AdhanWakeupReceiver::class.java).apply {
                            putExtra(AdhanKeepAliveService.EXTRA_PRAYER_ID, prayerId)
                            putExtra(AdhanKeepAliveService.EXTRA_PRAYER_NAME, prayerName)
                            putExtra(AdhanKeepAliveService.EXTRA_PRAYER_NAME_AR, prayerNameAr)
                            putExtra(AdhanKeepAliveService.EXTRA_PRAYER_TIME, prayerTime)
                        }
                        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
                        val operationIntent = PendingIntent.getBroadcast(
                            applicationContext,
                            requestCode,
                            alarmIntent,
                            pendingFlags,
                        )
                        val showActivityIntent = AdhanKeepAliveService.buildMainActivityAdhanIntent(
                            applicationContext,
                            prayerId,
                            prayerName,
                            prayerNameAr,
                            prayerTime,
                        )
                        val showPendingIntent = PendingIntent.getActivity(
                            applicationContext,
                            requestCode + 5000,
                            showActivityIntent,
                            pendingFlags,
                        )
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                        if (alarmManager != null) {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                val clockInfo = AlarmManager.AlarmClockInfo(triggerAtMillis, showPendingIntent)
                                alarmManager.setAlarmClock(clockInfo, operationIntent)
                            } else {
                                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, operationIntent)
                            }
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("ALARM_ERROR", e.localizedMessage, null)
                    }
                }
                "cancelNativeAdhanAlarm" -> {
                    try {
                        val requestCode = call.argument<Int>("requestCode") ?: 0
                        val alarmIntent = Intent(applicationContext, AdhanWakeupReceiver::class.java)
                        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
                        val pi = PendingIntent.getBroadcast(
                            applicationContext,
                            requestCode,
                            alarmIntent,
                            pendingFlags,
                        )
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                        alarmManager?.cancel(pi)
                        pi.cancel()
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                "isBatteryOptimizationIgnored" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        result.success(pm?.isIgnoringBatteryOptimizations(packageName) == true)
                    } else {
                        result.success(true)
                    }
                }
                "requestIgnoreBatteryOptimizations" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            try {
                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = Uri.parse("package:$packageName")
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (_: Exception) {
                                val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(fallback)
                                result.success(true)
                            }
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.localizedMessage, null)
                    }
                }
                "isOverlayPermissionGranted" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(this))
                    } else {
                        result.success(true)
                    }
                }
                "openOverlaySettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            try {
                                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                                    data = Uri.parse("package:$packageName")
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (_: Exception) {
                                val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.parse("package:$packageName")
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(fallback)
                                result.success(true)
                            }
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableLockScreenWakeFlags()
        extractAdhanPayload(intent)?.let { pendingAdhanPayload = it }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        enableLockScreenWakeFlags()
        extractAdhanPayload(intent)?.let { payload ->
            val channel = settingsChannel
            if (channel != null) {
                runOnUiThread {
                    channel.invokeMethod("onAdhanTrigger", payload)
                }
            } else {
                pendingAdhanPayload = payload
            }
        }
    }

    private fun enableLockScreenWakeFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            km?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun extractAdhanPayload(intent: Intent?): Map<String, String>? {
        if (intent == null || !intent.getBooleanExtra("launch_adhan_screen", false)) {
            return null
        }
        val payload = mapOf(
            "prayerId" to (intent.getStringExtra(AdhanKeepAliveService.EXTRA_PRAYER_ID) ?: ""),
            "prayerName" to (intent.getStringExtra(AdhanKeepAliveService.EXTRA_PRAYER_NAME) ?: "Prayer"),
            "prayerNameAr" to (intent.getStringExtra(AdhanKeepAliveService.EXTRA_PRAYER_NAME_AR) ?: "الصلاة"),
            "prayerTime" to (intent.getStringExtra(AdhanKeepAliveService.EXTRA_PRAYER_TIME) ?: ""),
        )
        intent.removeExtra("launch_adhan_screen")
        return payload
    }
}

