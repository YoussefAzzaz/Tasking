package com.axis.axis

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class AdhanWakeupReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return
        val prayerId = intent.getStringExtra(AdhanKeepAliveService.EXTRA_PRAYER_ID)
        val prayerName = intent.getStringExtra(AdhanKeepAliveService.EXTRA_PRAYER_NAME)
        val prayerNameAr = intent.getStringExtra(AdhanKeepAliveService.EXTRA_PRAYER_NAME_AR)
        val prayerTime = intent.getStringExtra(AdhanKeepAliveService.EXTRA_PRAYER_TIME)

        // Keep horizontal Prayer Times home screen widget in sync when Adhan transitions
        WidgetUiHelper.broadcastWidgetUpdate(context, PrayerTimesWidgetProvider::class.java)

        // Ensure the foreground keep-alive service processes the wakeup cleanly & launches MainActivity
        val serviceIntent = Intent(context, AdhanKeepAliveService::class.java).apply {
            action = AdhanKeepAliveService.ACTION_TRIGGER_ADHAN_ALARM
            putExtra(AdhanKeepAliveService.EXTRA_PRAYER_ID, prayerId)
            putExtra(AdhanKeepAliveService.EXTRA_PRAYER_NAME, prayerName)
            putExtra(AdhanKeepAliveService.EXTRA_PRAYER_NAME_AR, prayerNameAr)
            putExtra(AdhanKeepAliveService.EXTRA_PRAYER_TIME, prayerTime)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (_: Exception) {
            AdhanKeepAliveService.bringAppToForegroundForAdhan(
                context = context,
                prayerId = prayerId,
                prayerName = prayerName,
                prayerNameAr = prayerNameAr,
                prayerTime = prayerTime,
            )
        }
    }
}

