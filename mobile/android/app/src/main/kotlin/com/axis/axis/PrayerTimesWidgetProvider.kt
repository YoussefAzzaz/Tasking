package com.axis.axis

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar

class PrayerTimesWidgetProvider : HomeWidgetProvider() {

    private data class PrayerSlot(
        val code: String,
        val arabicName: String,
        val defaultTime: String,
        val colorHex: Int,
        val activeBgRes: Int,
        val timerBgRes: Int,
        val colId: Int,
        val nameId: Int,
        val timeId: Int,
    )

    companion object {
        private const val REQUEST_NEXT_TRANSITION = 4103
        private const val REQUEST_MIDNIGHT_REFRESH = 4104

        private val SLOTS = listOf(
            PrayerSlot(
                code = "fajr",
                arabicName = "الفجر",
                defaultTime = "05:30",
                colorHex = 0xFF06B6D4.toInt(),
                activeBgRes = R.drawable.widget_prayer_active_fajr,
                timerBgRes = R.drawable.widget_prayer_timer_fajr,
                colId = R.id.widget_prayer_col_fajr,
                nameId = R.id.widget_prayer_name_fajr,
                timeId = R.id.widget_prayer_time_fajr,
            ),
            PrayerSlot(
                code = "dhuhr",
                arabicName = "الظهر",
                defaultTime = "12:45",
                colorHex = 0xFFF59E0B.toInt(),
                activeBgRes = R.drawable.widget_prayer_active_dhuhr,
                timerBgRes = R.drawable.widget_prayer_timer_dhuhr,
                colId = R.id.widget_prayer_col_dhuhr,
                nameId = R.id.widget_prayer_name_dhuhr,
                timeId = R.id.widget_prayer_time_dhuhr,
            ),
            PrayerSlot(
                code = "asr",
                arabicName = "العصر",
                defaultTime = "15:45",
                colorHex = 0xFFF97316.toInt(),
                activeBgRes = R.drawable.widget_prayer_active_asr,
                timerBgRes = R.drawable.widget_prayer_timer_asr,
                colId = R.id.widget_prayer_col_asr,
                nameId = R.id.widget_prayer_name_asr,
                timeId = R.id.widget_prayer_time_asr,
            ),
            PrayerSlot(
                code = "maghrib",
                arabicName = "المغرب",
                defaultTime = "18:20",
                colorHex = 0xFFEF4444.toInt(),
                activeBgRes = R.drawable.widget_prayer_active_maghrib,
                timerBgRes = R.drawable.widget_prayer_timer_maghrib,
                colId = R.id.widget_prayer_col_maghrib,
                nameId = R.id.widget_prayer_name_maghrib,
                timeId = R.id.widget_prayer_time_maghrib,
            ),
            PrayerSlot(
                code = "isha",
                arabicName = "العشاء",
                defaultTime = "19:45",
                colorHex = 0xFF8B5CF6.toInt(),
                activeBgRes = R.drawable.widget_prayer_active_isha,
                timerBgRes = R.drawable.widget_prayer_timer_isha,
                colId = R.id.widget_prayer_col_isha,
                nameId = R.id.widget_prayer_name_isha,
                timeId = R.id.widget_prayer_time_isha,
            ),
        )

        private fun parseTimeMillisToday(hhMm: String, dayOffset: Int = 0): Long? {
            val clean = hhMm.trim()
            val parts = clean.split(":")
            if (parts.size < 2) return null
            val h = parts[0].trim().toIntOrNull() ?: return null
            val m = parts[1].trim().replace(Regex("[^0-9]"), "").toIntOrNull() ?: return null
            if (h !in 0..23 || m !in 0..59) return null
            return Calendar.getInstance().apply {
                if (dayOffset != 0) add(Calendar.DAY_OF_YEAR, dayOffset)
                set(Calendar.HOUR_OF_DAY, h)
                set(Calendar.MINUTE, m)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val now = System.currentTimeMillis()
        val todayKey = WidgetUiHelper.todayKey()
        val syncDate = widgetData.getString("prayer_widget_date_key", "") ?: ""

        val gregorianAr = if (syncDate == todayKey) {
            widgetData.getString("prayer_widget_gregorian", null)
        } else {
            null
        } ?: WidgetUiHelper.arabicGregorianDate()

        val hijriAr = if (syncDate == todayKey) {
            widgetData.getString("prayer_widget_hijri", null)
        } else {
            null
        } ?: WidgetUiHelper.hijriDateString(arabic = true, includeYear = true)

        val sunriseTime = widgetData.getString("prayer_widget_sunrise", "07:05") ?: "07:05"
        val sunriseMillis = parseTimeMillisToday(sunriseTime) ?: now

        val times = SLOTS.map { slot ->
            widgetData.getString("prayer_widget_${slot.code}_time", slot.defaultTime) ?: slot.defaultTime
        }
        val todayMillis = SLOTS.indices.map { i ->
            parseTimeMillisToday(times[i]) ?: now
        }
        val tomorrowFajrStr = widgetData.getString("prayer_widget_fajr_tomorrow_time", times[0]) ?: times[0]
        val tomorrowFajrMillis = parseTimeMillisToday(tomorrowFajrStr, dayOffset = 1)
            ?: (todayMillis[0] + 86_400_000L)

        // Compute current active prayer window & upcoming prayer target
        val fajrMs = todayMillis[0]
        val dhuhrMs = todayMillis[1]
        val asrMs = todayMillis[2]
        val maghribMs = todayMillis[3]
        val ishaMs = todayMillis[4]

        val currentCode: String
        val nextSlot: PrayerSlot
        val nextTargetMillis: Long
        var transitionMillis: Long

        when {
            now < fajrMs -> {
                currentCode = "isha"
                nextSlot = SLOTS[0]
                nextTargetMillis = fajrMs
                transitionMillis = fajrMs
            }
            now < sunriseMillis -> {
                currentCode = "fajr"
                nextSlot = SLOTS[1]
                nextTargetMillis = dhuhrMs
                transitionMillis = sunriseMillis
            }
            now < dhuhrMs -> {
                currentCode = "sunrise"
                nextSlot = SLOTS[1]
                nextTargetMillis = dhuhrMs
                transitionMillis = dhuhrMs
            }
            now < asrMs -> {
                currentCode = "dhuhr"
                nextSlot = SLOTS[2]
                nextTargetMillis = asrMs
                transitionMillis = asrMs
            }
            now < maghribMs -> {
                currentCode = "asr"
                nextSlot = SLOTS[3]
                nextTargetMillis = maghribMs
                transitionMillis = maghribMs
            }
            now < ishaMs -> {
                currentCode = "maghrib"
                nextSlot = SLOTS[4]
                nextTargetMillis = ishaMs
                transitionMillis = ishaMs
            }
            else -> {
                currentCode = "isha"
                nextSlot = SLOTS[0]
                nextTargetMillis = tomorrowFajrMillis
                transitionMillis = tomorrowFajrMillis
            }
        }

        val remainingMillis = (nextTargetMillis - now).coerceAtLeast(1000L)
        val chronoBase = SystemClock.elapsedRealtime() + remainingMillis

        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_prayer_times).apply {
                    setTextViewText(R.id.widget_prayer_gregorian, gregorianAr)
                    setTextViewText(R.id.widget_prayer_hijri, hijriAr)
                    setTextViewText(R.id.widget_prayer_sunrise, "الشروق $sunriseTime")

                    for (i in SLOTS.indices) {
                        val slot = SLOTS[i]
                        val isDone = widgetData.getBoolean("prayer_widget_${slot.code}_done", false)
                        val isCurrent = currentCode == slot.code ||
                            (currentCode == "sunrise" && slot.code == nextSlot.code)
                        val isPast = now >= todayMillis[i] && currentCode != slot.code

                        setTextViewText(slot.nameId, slot.arabicName)
                        setTextViewText(slot.timeId, times[i])

                        if (isCurrent) {
                            setInt(slot.colId, "setBackgroundResource", slot.activeBgRes)
                            setTextColor(slot.nameId, slot.colorHex)
                            setTextColor(slot.timeId, 0xFFFFFFFF.toInt())
                        } else {
                            setInt(slot.colId, "setBackgroundResource", R.drawable.widget_prayer_inactive_bg)
                            val nameColor = when {
                                isDone -> 0xFF10B981.toInt()
                                isPast -> 0xFF64748B.toInt()
                                else -> 0xFFE2E8F0.toInt()
                            }
                            val timeColor = when {
                                isDone -> 0xFF34D399.toInt()
                                isPast -> 0xFF475569.toInt()
                                else -> 0xFF94A3B8.toInt()
                            }
                            setTextColor(slot.nameId, nameColor)
                            setTextColor(slot.timeId, timeColor)
                        }
                    }

                    // Configure Upcoming Prayer Countdown Pill
                    setInt(R.id.widget_prayer_timer_box, "setBackgroundResource", nextSlot.timerBgRes)
                    setTextViewText(R.id.widget_prayer_next_label, "${nextSlot.arabicName} بعد")
                    setTextColor(R.id.widget_prayer_next_label, nextSlot.colorHex)
                    setChronometer(R.id.widget_prayer_chronometer, chronoBase, null, true)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        setChronometerCountDown(R.id.widget_prayer_chronometer, true)
                    }

                    // Tap opens main screen (/today)
                    val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("axis://widget/prayers"),
                    )
                    setOnClickPendingIntent(R.id.widget_prayer_times_root, pendingIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Throwable) {
                Log.e("PrayerTimesWidget", "Error updating prayer times widget", e)
            }
        }

        // Auto-refresh at exact next prayer/sunrise transition and midnight
        WidgetUiHelper.scheduleTransitionUpdate(
            context,
            PrayerTimesWidgetProvider::class.java,
            transitionMillis + 1200L,
            REQUEST_NEXT_TRANSITION,
        )
        WidgetUiHelper.scheduleTransitionUpdate(
            context,
            PrayerTimesWidgetProvider::class.java,
            WidgetUiHelper.nextMidnightMillis(),
            REQUEST_MIDNIGHT_REFRESH,
        )
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WidgetUiHelper.cancelTransitionUpdate(
            context,
            PrayerTimesWidgetProvider::class.java,
            REQUEST_NEXT_TRANSITION,
        )
        WidgetUiHelper.cancelTransitionUpdate(
            context,
            PrayerTimesWidgetProvider::class.java,
            REQUEST_MIDNIGHT_REFRESH,
        )
    }
}
