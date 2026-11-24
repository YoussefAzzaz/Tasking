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

class TodayTasksWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val REQUEST_MIDNIGHT_REFRESH = 4101
        private val ROW_IDS = intArrayOf(
            R.id.widget_task_row_0,
            R.id.widget_task_row_1,
            R.id.widget_task_row_2,
            R.id.widget_task_row_3,
            R.id.widget_task_row_4,
        )
        private val DOT_IDS = intArrayOf(
            R.id.widget_task_dot_0,
            R.id.widget_task_dot_1,
            R.id.widget_task_dot_2,
            R.id.widget_task_dot_3,
            R.id.widget_task_dot_4,
        )
        private val TITLE_IDS = intArrayOf(
            R.id.widget_task_title_0,
            R.id.widget_task_title_1,
            R.id.widget_task_title_2,
            R.id.widget_task_title_3,
            R.id.widget_task_title_4,
        )
        private val META_IDS = intArrayOf(
            R.id.widget_task_meta_0,
            R.id.widget_task_meta_1,
            R.id.widget_task_meta_2,
            R.id.widget_task_meta_3,
            R.id.widget_task_meta_4,
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
                val views = RemoteViews(context.packageName, R.layout.widget_today_tasks).apply {
                    val title = widgetData.getString("today_tasks_title", "AXIS • TODAY") ?: "AXIS • TODAY"
                    val count = widgetData.getString("today_tasks_count", "0/0 DONE") ?: "0/0 DONE"
                    val syncDate = widgetData.getString("today_tasks_sync_date", "") ?: ""
                    val date = if (syncDate == todayKey) {
                        widgetData.getString("today_tasks_date", "TODAY") ?: "TODAY"
                    } else {
                        "${WidgetUiHelper.englishShortGregorianDate()} • ${WidgetUiHelper.hijriDateString(arabic = false, includeYear = false)}"
                    }
                    val city = widgetData.getString("today_tasks_city", "") ?: ""
                    val footerSummary = widgetData.getString("today_tasks_footer_summary", "All clear for today")
                        ?: "All clear for today"
                    val emptyQuote = widgetData.getString("today_tasks_empty_quote", "Clean slate for today — stay focused")
                        ?: "Clean slate for today — stay focused"
                    val percent = try {
                        widgetData.getInt("today_tasks_percent", 0)
                    } catch (_: Throwable) {
                        try {
                            widgetData.getLong("today_tasks_percent", 0L).toInt()
                        } catch (_: Throwable) {
                            0
                        }
                    }.coerceIn(0, 100)

                    setTextViewText(R.id.widget_tasks_title, title)
                    setTextViewText(R.id.widget_tasks_count, count)
                    setTextViewText(R.id.widget_tasks_date, date)
                    setTextViewText(R.id.widget_tasks_footer_summary, footerSummary)
                    setTextViewText(R.id.widget_tasks_percent_text, "$percent%")
                    setTextViewText(R.id.widget_tasks_empty_quote, emptyQuote)
                    setProgressBar(R.id.widget_tasks_progressbar, 100, percent, false)

                    if (city.isNotEmpty()) {
                        setTextViewText(R.id.widget_tasks_city, city.uppercase())
                        setViewVisibility(R.id.widget_tasks_city, View.VISIBLE)
                    } else {
                        setViewVisibility(R.id.widget_tasks_city, View.GONE)
                    }

                    val rawJson = widgetData.getString("today_tasks_items_json", null)
                    val itemsArray = try {
                        if (!rawJson.isNullOrBlank()) JSONArray(rawJson) else null
                    } catch (_: Throwable) {
                        null
                    }

                    if (itemsArray != null && itemsArray.length() > 0) {
                        setViewVisibility(R.id.widget_tasks_list_container, View.VISIBLE)
                        setViewVisibility(R.id.widget_tasks_empty_container, View.GONE)

                        val countRows = itemsArray.length().coerceAtMost(ROW_IDS.size)
                        for (i in ROW_IDS.indices) {
                            if (i < countRows) {
                                val obj = itemsArray.optJSONObject(i)
                                if (obj != null) {
                                    val taskTitle = obj.optString("title", "")
                                    val isDone = obj.optBoolean("done", false)
                                    val priority = obj.optInt("priority", 0)
                                    val meta = obj.optString("time", "")
                                    val overdue = obj.optBoolean("overdue", false)

                                    val dotColor = when {
                                        isDone -> 0xFF475569.toInt()
                                        priority == 1 -> 0xFFEF4444.toInt()
                                        priority == 2 -> 0xFFF59E0B.toInt()
                                        priority == 3 -> 0xFF10B981.toInt()
                                        else -> 0xFF38BDF8.toInt()
                                    }

                                    setViewVisibility(ROW_IDS[i], View.VISIBLE)
                                    setInt(DOT_IDS[i], "setColorFilter", dotColor)
                                    setTextViewText(
                                        TITLE_IDS[i],
                                        WidgetUiHelper.applyStrikethrough(taskTitle, isDone),
                                    )
                                    setTextColor(
                                        TITLE_IDS[i],
                                        if (isDone) 0xFF64748B.toInt() else 0xFFF1F5F9.toInt(),
                                    )

                                    if (meta.isNotEmpty()) {
                                        setViewVisibility(META_IDS[i], View.VISIBLE)
                                        setTextViewText(META_IDS[i], meta)
                                        if (overdue) {
                                            setTextColor(META_IDS[i], 0xFFEF4444.toInt())
                                            setInt(META_IDS[i], "setBackgroundResource", R.drawable.widget_pill_red)
                                            setViewPadding(META_IDS[i], 8, 2, 8, 2)
                                        } else {
                                            setTextColor(META_IDS[i], 0xFF94A3B8.toInt())
                                            setInt(META_IDS[i], "setBackgroundResource", 0)
                                            setViewPadding(META_IDS[i], 0, 0, 0, 0)
                                        }
                                    } else {
                                        setViewVisibility(META_IDS[i], View.GONE)
                                    }
                                } else {
                                    setViewVisibility(ROW_IDS[i], View.GONE)
                                }
                            } else {
                                setViewVisibility(ROW_IDS[i], View.GONE)
                            }
                        }
                    } else {
                        setViewVisibility(R.id.widget_tasks_list_container, View.GONE)
                        setViewVisibility(R.id.widget_tasks_empty_container, View.VISIBLE)
                    }

                    val pendingIntent = WidgetUiHelper.buildFastLaunchIntent(
                        context,
                        MainActivity::class.java,
                        Uri.parse("axis://widget/today"),
                        WidgetUiHelper.REQ_LAUNCH_TODAY_WIDGET,
                    )
                    setOnClickPendingIntent(R.id.widget_today_tasks_root, pendingIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Throwable) {
                Log.e("TodayTasksWidget", "Error updating today tasks widget", e)
            }
        }

        WidgetUiHelper.scheduleTransitionUpdate(
            context,
            TodayTasksWidgetProvider::class.java,
            WidgetUiHelper.nextMidnightMillis(),
            REQUEST_MIDNIGHT_REFRESH,
        )
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WidgetUiHelper.cancelTransitionUpdate(
            context,
            TodayTasksWidgetProvider::class.java,
            REQUEST_MIDNIGHT_REFRESH,
        )
    }
}
