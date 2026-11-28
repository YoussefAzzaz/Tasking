package com.axis.axis

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AdhanBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON"
        ) {
            if (AdhanKeepAliveService.isKeepAliveEnabled(context)) {
                try {
                    AdhanKeepAliveService.startService(context)
                } catch (_: Exception) {}
            }
            // Root-cause fix: Android wipes AlarmManager alarms on device reboot or app replacement,
            // so restore all non-expired saved Adhan alarms immediately on boot.
            AdhanAlarmStore.rescheduleSavedAlarms(context)
            WidgetUiHelper.broadcastWidgetUpdate(context, TodayTasksWidgetProvider::class.java)
            WidgetUiHelper.broadcastWidgetUpdate(context, HabitStreakWidgetProvider::class.java)
            WidgetUiHelper.broadcastWidgetUpdate(context, PrayerTimesWidgetProvider::class.java)
        }
    }
}
