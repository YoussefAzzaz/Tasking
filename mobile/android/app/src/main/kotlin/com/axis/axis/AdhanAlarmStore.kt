package com.axis.axis

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject

/**
 * Persists scheduled native Adhan alarms in SharedPreferences and restores them
 * safely across device reboots and Android 12+ exact-alarm permission states.
 */
internal object AdhanAlarmStore {
    private const val KEY_SCHEDULED_ALARMS = "scheduled_adhan_alarms_v1"

    fun scheduleAndPersist(
        context: Context,
        requestCode: Int,
        triggerAtMillis: Long,
        prayerId: String,
        prayerName: String,
        prayerNameAr: String,
        prayerTime: String,
    ): Boolean {
        val scheduled = applyAlarmManagerSchedule(
            context = context,
            requestCode = requestCode,
            triggerAtMillis = triggerAtMillis,
            prayerId = prayerId,
            prayerName = prayerName,
            prayerNameAr = prayerNameAr,
            prayerTime = prayerTime,
        )
        if (scheduled) {
            saveEntry(
                context = context,
                requestCode = requestCode,
                triggerAtMillis = triggerAtMillis,
                prayerId = prayerId,
                prayerName = prayerName,
                prayerNameAr = prayerNameAr,
                prayerTime = prayerTime,
            )
        }
        return scheduled
    }

    fun cancelAndRemove(context: Context, requestCode: Int): Boolean {
        removeEntry(context, requestCode)
        return try {
            val alarmIntent = Intent(context, AdhanWakeupReceiver::class.java)
            val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            val pi = PendingIntent.getBroadcast(
                context,
                requestCode,
                alarmIntent,
                pendingFlags,
            )
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            alarmManager?.cancel(pi)
            pi.cancel()
            true
        } catch (_: Exception) {
            false
        }
    }

    fun rescheduleSavedAlarms(context: Context) {
        val prefs = context.getSharedPreferences(AdhanKeepAliveService.PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_SCHEDULED_ALARMS, null) ?: return
        val now = System.currentTimeMillis()
        try {
            val map = JSONObject(raw)
            val updated = JSONObject()
            val keys = map.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                val reqCode = key.toIntOrNull() ?: continue
                val entry = map.optJSONObject(key) ?: continue
                val triggerAt = entry.optLong("triggerAtMillis", 0L)
                if (triggerAt <= now) continue
                val ok = applyAlarmManagerSchedule(
                    context = context,
                    requestCode = reqCode,
                    triggerAtMillis = triggerAt,
                    prayerId = entry.optString("prayerId", ""),
                    prayerName = entry.optString("prayerName", "Prayer"),
                    prayerNameAr = entry.optString("prayerNameAr", "الصلاة"),
                    prayerTime = entry.optString("prayerTime", ""),
                )
                if (ok) {
                    updated.put(key, entry)
                }
            }
            prefs.edit().putString(KEY_SCHEDULED_ALARMS, updated.toString()).apply()
        } catch (_: Exception) {}
    }

    private fun applyAlarmManagerSchedule(
        context: Context,
        requestCode: Int,
        triggerAtMillis: Long,
        prayerId: String,
        prayerName: String,
        prayerNameAr: String,
        prayerTime: String,
    ): Boolean {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: return false
        val alarmIntent = Intent(context, AdhanWakeupReceiver::class.java).apply {
            putExtra(AdhanKeepAliveService.EXTRA_PRAYER_ID, prayerId)
            putExtra(AdhanKeepAliveService.EXTRA_PRAYER_NAME, prayerName)
            putExtra(AdhanKeepAliveService.EXTRA_PRAYER_NAME_AR, prayerNameAr)
            putExtra(AdhanKeepAliveService.EXTRA_PRAYER_TIME, prayerTime)
        }
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        val operationIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            alarmIntent,
            pendingFlags,
        )
        val showActivityIntent = AdhanKeepAliveService.buildMainActivityAdhanIntent(
            context,
            prayerId,
            prayerName,
            prayerNameAr,
            prayerTime,
        )
        val showPendingIntent = PendingIntent.getActivity(
            context,
            requestCode + 5000,
            showActivityIntent,
            pendingFlags,
        )

        val canUseExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            alarmManager.canScheduleExactAlarms()
        if (canUseExact && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val clockInfo = AlarmManager.AlarmClockInfo(triggerAtMillis, showPendingIntent)
            alarmManager.setAlarmClock(clockInfo, operationIntent)
        } else if (canUseExact) {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, operationIntent)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, operationIntent)
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, operationIntent)
        }
        return true
    }

    private fun saveEntry(
        context: Context,
        requestCode: Int,
        triggerAtMillis: Long,
        prayerId: String,
        prayerName: String,
        prayerNameAr: String,
        prayerTime: String,
    ) {
        val prefs = context.getSharedPreferences(AdhanKeepAliveService.PREFS_NAME, Context.MODE_PRIVATE)
        val root = try {
            JSONObject(prefs.getString(KEY_SCHEDULED_ALARMS, null) ?: "{}")
        } catch (_: Exception) {
            JSONObject()
        }
        val obj = JSONObject().apply {
            put("triggerAtMillis", triggerAtMillis)
            put("prayerId", prayerId)
            put("prayerName", prayerName)
            put("prayerNameAr", prayerNameAr)
            put("prayerTime", prayerTime)
        }
        root.put(requestCode.toString(), obj)
        prefs.edit().putString(KEY_SCHEDULED_ALARMS, root.toString()).apply()
    }

    private fun removeEntry(context: Context, requestCode: Int) {
        val prefs = context.getSharedPreferences(AdhanKeepAliveService.PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_SCHEDULED_ALARMS, null) ?: return
        try {
            val root = JSONObject(raw)
            root.remove(requestCode.toString())
            prefs.edit().putString(KEY_SCHEDULED_ALARMS, root.toString()).apply()
        } catch (_: Exception) {}
    }
}
