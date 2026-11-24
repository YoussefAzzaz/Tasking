package com.axis.axis

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class HabitStreakWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val REQUEST_MIDNIGHT_REFRESH = 4102
        private val ROW_IDS = intArrayOf(
            R.id.widget_habit_row_0,
            R.id.widget_habit_row_1,
            R.id.widget_habit_row_2,
            R.id.widget_habit_row_3,
            R.id.widget_habit_row_4,
        )
        private val DOT_IDS = intArrayOf(
            R.id.widget_habit_dot_0,
            R.id.widget_habit_dot_1,
            R.id.widget_habit_dot_2,
            R.id.widget_habit_dot_3,
            R.id.widget_habit_dot_4,
        )
        private val NAME_IDS = intArrayOf(
            R.id.widget_habit_name_0,
            R.id.widget_habit_name_1,
            R.id.widget_habit_name_2,
            R.id.widget_habit_name_3,
            R.id.widget_habit_name_4,
        )
        private val STATUS_IDS = intArrayOf(
            R.id.widget_habit_status_0,
            R.id.widget_habit_status_1,
            R.id.widget_habit_status_2,
            R.id.widget_habit_status_3,
            R.id.widget_habit_status_4,
        )
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val todayKey = WidgetUiHelper.todayKey()
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_habit_streak).apply {
                    val streakDays = widgetData.getString("habit_streak_days", "0 DAYS") ?: "0 DAYS"
                    val streakNum = try {
                        widgetData.getInt("habit_streak_num", 0)
                    } catch (_: Throwable) {
                        try {
                            widgetData.getLong("habit_streak_num", 0L).toInt()
                        } catch (_: Throwable) {
                            0
                        }
                    }
                    val progress = widgetData.getString("habit_streak_progress", "0 of 0 habits completed today (0%)")
                        ?: "0 of 0 habits completed today (0%)"
                    val badge = widgetData.getString("habit_streak_badge", "0/0 DONE") ?: "0/0 DONE"
                    val quote = widgetData.getString("habit_streak_quote", "Consistency creates mastery • Tap to open")
                        ?: "Consistency creates mastery • Tap to open"
                    val syncDate = widgetData.getString("habit_streak_sync_date", "") ?: ""
                    val hijriShort = if (syncDate == todayKey) {
                        widgetData.getString("habit_streak_hijri", null)
                    } else {
                        null
                    } ?: WidgetUiHelper.hijriDateString(arabic = false, includeYear = false)

                    val percent = try {
                        widgetData.getInt("habit_streak_percent", 0)
                    } catch (_: Throwable) {
                        try {
                            widgetData.getLong("habit_streak_percent", 0L).toInt()
                        } catch (_: Throwable) {
                            0
                        }
                    }.coerceIn(0, 100)

                    setTextViewText(R.id.widget_habit_header_label, "AXIS • HABITS • $hijriShort")
                    setTextViewText(R.id.widget_habit_streak_days, streakDays)
                    setTextViewText(R.id.widget_habit_progress, progress)
                    setTextViewText(R.id.widget_habit_badge, badge)
                    setTextViewText(R.id.widget_habit_quote, quote)
                    setProgressBar(R.id.widget_habit_progressbar, 100, percent, false)

                    val streakBgRes = when {
                        streakNum >= 7 -> R.drawable.widget_streak_pill_hot
                        streakNum >= 1 -> R.drawable.widget_streak_pill_warm
                        else -> R.drawable.widget_streak_pill_zero
                    }
                    setInt(R.id.widget_habit_streak_pill, "setBackgroundResource", streakBgRes)
                    setInt(
                        R.id.widget_habit_flame_icon,
                        "setColorFilter",
                        when {
                            streakNum >= 7 -> 0xFFEF4444.toInt()
                            streakNum >= 1 -> 0xFFF59E0B.toInt()
                            else -> 0xFF64748B.toInt()
                        },
                    )

                    val rawJson = widgetData.getString("habit_streak_items_json", null)
                    val itemsArray = try {
                        if (!rawJson.isNullOrBlank()) JSONArray(rawJson) else null
                    } catch (_: Throwable) {
                        null
                    }

                    if (itemsArray != null && itemsArray.length() > 0) {
                        setViewVisibility(R.id.widget_habits_list_container, View.VISIBLE)
                        setViewVisibility(R.id.widget_habits_empty_container, View.GONE)

                        val countRows = itemsArray.length().coerceAtMost(ROW_IDS.size)
                        for (i in ROW_IDS.indices) {
                            if (i < countRows) {
                                val obj = itemsArray.optJSONObject(i)
                                if (obj != null) {
                                    val name = obj.optString("name", "")
                                    val colorHex = obj.optString("color", "#10B981")
                                    val isDone = obj.optBoolean("done", false)
                                    val dotColor = WidgetUiHelper.parseColorSafe(colorHex, 0xFF10B981.toInt())

                                    setViewVisibility(ROW_IDS[i], View.VISIBLE)
                                    setInt(DOT_IDS[i], "setColorFilter", dotColor)
                                    setTextViewText(
                                        NAME_IDS[i],
                                        WidgetUiHelper.applyStrikethrough(name, isDone),
                                    )
                                    setTextColor(
                                        NAME_IDS[i],
                                        if (isDone) 0xFF64748B.toInt() else 0xFFF1F5F9.toInt(),
                                    )
                                    setTextViewText(STATUS_IDS[i], if (isDone) "✓" else "○")
                                    setTextColor(
                                        STATUS_IDS[i],
                                        if (isDone) 0xFF10B981.toInt() else 0xFF64748B.toInt(),
                                    )
                                } else {
                                    setViewVisibility(ROW_IDS[i], View.GONE)
                                }
                            } else {
                                setViewVisibility(ROW_IDS[i], View.GONE)
                            }
                        }
                    } else {
                        setViewVisibility(R.id.widget_habits_list_container, View.GONE)
                        setViewVisibility(R.id.widget_habits_empty_container, View.VISIBLE)
                    }

                    // Deep-link directly to /habits when tapped
                    val pendingIntent = WidgetUiHelper.buildFastLaunchIntent(
                        context,
                        MainActivity::class.java,
                        Uri.parse("axis://widget/habits"),
                        WidgetUiHelper.REQ_LAUNCH_HABITS_WIDGET,
                    )
                    setOnClickPendingIntent(R.id.widget_habit_streak_root, pendingIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Throwable) {
                Log.e("HabitStreakWidget", "Error updating habit streak widget", e)
            }
        }

        WidgetUiHelper.scheduleTransitionUpdate(
            context,
            HabitStreakWidgetProvider::class.java,
            WidgetUiHelper.nextMidnightMillis(),
            REQUEST_MIDNIGHT_REFRESH,
        )
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WidgetUiHelper.cancelTransitionUpdate(
            context,
            HabitStreakWidgetProvider::class.java,
            REQUEST_MIDNIGHT_REFRESH,
        )
    }
}
