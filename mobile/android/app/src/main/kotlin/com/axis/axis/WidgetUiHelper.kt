package com.axis.axis

import android.app.Activity
import android.app.ActivityOptions
import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.icu.util.Calendar as IcuCalendar
import android.icu.util.IslamicCalendar
import android.net.Uri
import android.os.Build
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StrikethroughSpan
import android.util.Log
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

internal object WidgetUiHelper {
    const val REQ_LAUNCH_TODAY_WIDGET = 3101
    const val REQ_LAUNCH_HABITS_WIDGET = 3102
    const val REQ_LAUNCH_PRAYER_WIDGET = 3103

    private val ARABIC_HIJRI_MONTHS = arrayOf(
        "محرم",
        "صفر",
        "ربيع الأول",
        "ربيع الثاني",
        "جمادى الأولى",
        "جمادى الآخرة",
        "رجب",
        "شعبان",
        "رمضان",
        "شوال",
        "ذو القعدة",
        "ذو الحجة",
    )

    private val ENGLISH_SHORT_HIJRI_MONTHS = arrayOf(
        "MUH",
        "SAF",
        "RAB I",
        "RAB II",
        "JUM I",
        "JUM II",
        "RAJ",
        "SHA",
        "RAM",
        "SHAW",
        "DHU Q",
        "DHU H",
    )

    fun todayKey(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    fun englishShortGregorianDate(): String =
        SimpleDateFormat("EEE, MMM d", Locale.US).format(Date()).uppercase(Locale.US)

    fun englishCompactGregorianDate(): String =
        SimpleDateFormat("EEE, d MMM", Locale.US).format(Date())

    fun <T : Activity> buildFastLaunchIntent(
        context: Context,
        activityClass: Class<T>,
        uri: Uri,
        requestCode: Int,
    ): PendingIntent {
        val intent = Intent(context, activityClass).apply {
            data = uri
            action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        var piFlags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            piFlags = piFlags or PendingIntent.FLAG_IMMUTABLE
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return PendingIntent.getActivity(context, requestCode, intent, piFlags)
        }

        val options = ActivityOptions.makeBasic()
        if (Build.VERSION.SDK_INT >= 35) {
            options.setPendingIntentCreatorBackgroundActivityStartMode(
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED,
            )
        } else {
            options.pendingIntentBackgroundActivityStartMode =
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
        }
        return PendingIntent.getActivity(context, requestCode, intent, piFlags, options.toBundle())
    }

    fun hijriDateString(arabic: Boolean, includeYear: Boolean): String {
        return try {
            val islamicCal = IslamicCalendar().apply {
                calculationType = IslamicCalendar.CalculationType.ISLAMIC_UMALQURA
                timeInMillis = System.currentTimeMillis()
            }
            val hDay = islamicCal.get(IcuCalendar.DAY_OF_MONTH)
            val hMonthIdx = islamicCal.get(IcuCalendar.MONTH).coerceIn(0, 11)
            val hYear = islamicCal.get(IcuCalendar.YEAR)

            if (arabic) {
                if (includeYear) "$hDay ${ARABIC_HIJRI_MONTHS[hMonthIdx]} $hYear"
                else "$hDay ${ARABIC_HIJRI_MONTHS[hMonthIdx]}"
            } else {
                if (includeYear) "$hDay ${ENGLISH_SHORT_HIJRI_MONTHS[hMonthIdx]} $hYear"
                else "$hDay ${ENGLISH_SHORT_HIJRI_MONTHS[hMonthIdx]}"
            }
        } catch (t: Throwable) {
            Log.w("WidgetUiHelper", "Falling back to Kuwaiti Hijri calc", t)
            kuwaitiFallbackHijri(arabic, includeYear)
        }
    }

    private fun kuwaitiFallbackHijri(arabic: Boolean, includeYear: Boolean): String {
        val cal = Calendar.getInstance()
        var y = cal.get(Calendar.YEAR)
        var m = cal.get(Calendar.MONTH) + 1
        val d = cal.get(Calendar.DAY_OF_MONTH)
        if (m <= 2) {
            y -= 1
            m += 12
        }
        val a = y / 100
        val b = 2 - a + (a / 4)
        val jd = kotlin.math.floor(365.25 * (y + 4716)).toInt() +
            kotlin.math.floor(30.6001 * (m + 1)).toInt() + d + b - 1524
        var l = jd - 1948440 + 10632
        val n = (l - 1) / 10631
        l = l - 10631 * n + 354
        val j = ((10985 - l) / 5316) * ((50 * l) / 17719) +
            (l / 5670) * ((43 * l) / 15238)
        l = l - ((30 - j) / 15) * ((17719 * j) / 50) -
            (j / 16) * ((15238 * j) / 43) + 29
        val hMonth = (24 * l) / 709
        val hDay = l - (709 * hMonth) / 24
        val hYear = 30 * n + j - 30
        val monthIdx = (hMonth - 1).coerceIn(0, 11)
        return if (arabic) {
            if (includeYear) "$hDay ${ARABIC_HIJRI_MONTHS[monthIdx]} $hYear"
            else "$hDay ${ARABIC_HIJRI_MONTHS[monthIdx]}"
        } else {
            if (includeYear) "$hDay ${ENGLISH_SHORT_HIJRI_MONTHS[monthIdx]} $hYear"
            else "$hDay ${ENGLISH_SHORT_HIJRI_MONTHS[monthIdx]}"
        }
    }

    fun applyStrikethrough(text: String, strike: Boolean): CharSequence {
        if (!strike || text.isEmpty()) return text
        return SpannableString(text).apply {
            setSpan(StrikethroughSpan(), 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }

    fun parseColorSafe(hex: String?, fallback: Int): Int {
        val raw = hex?.trim().orEmpty()
        if (raw.isEmpty()) return fallback
        return try {
            val normalized = if (raw.startsWith("#")) raw else "#$raw"
            Color.parseColor(normalized)
        } catch (_: Throwable) {
            fallback
        }
    }

    fun broadcastWidgetUpdate(context: Context, providerClass: Class<*>) {
        try {
            val manager = AppWidgetManager.getInstance(context.applicationContext)
            val ids = manager.getAppWidgetIds(ComponentName(context.applicationContext, providerClass))
            if (ids.isNotEmpty()) {
                val intent = Intent(context.applicationContext, providerClass).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
                context.sendBroadcast(intent)
            }
        } catch (t: Throwable) {
            Log.w("WidgetUiHelper", "Error broadcasting update for ${providerClass.simpleName}", t)
        }
    }

    fun scheduleTransitionUpdate(
        context: Context,
        providerClass: Class<*>,
        triggerAtMillis: Long,
        requestCode: Int,
    ) {
        if (triggerAtMillis <= System.currentTimeMillis()) return
        try {
            val appCtx = context.applicationContext
            val manager = AppWidgetManager.getInstance(appCtx)
            val ids = manager.getAppWidgetIds(ComponentName(appCtx, providerClass))
            if (ids.isEmpty()) return

            val intent = Intent(appCtx, providerClass).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                flags = flags or PendingIntent.FLAG_IMMUTABLE
            }
            val pendingIntent = PendingIntent.getBroadcast(appCtx, requestCode, intent, flags)
            val alarmManager = appCtx.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                } else {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            }
        } catch (t: Throwable) {
            Log.w("WidgetUiHelper", "Unable to schedule transition alarm", t)
        }
    }

    fun cancelTransitionUpdate(context: Context, providerClass: Class<*>, requestCode: Int) {
        try {
            val appCtx = context.applicationContext
            val intent = Intent(appCtx, providerClass).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            }
            var flags = PendingIntent.FLAG_NO_CREATE
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                flags = flags or PendingIntent.FLAG_IMMUTABLE
            }
            val pi = PendingIntent.getBroadcast(appCtx, requestCode, intent, flags) ?: return
            val alarmManager = appCtx.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            alarmManager?.cancel(pi)
            pi.cancel()
        } catch (_: Throwable) {}
    }

    fun nextMidnightMillis(): Long {
        val cal = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 5)
            set(Calendar.MILLISECOND, 0)
        }
        return cal.timeInMillis
    }
}
