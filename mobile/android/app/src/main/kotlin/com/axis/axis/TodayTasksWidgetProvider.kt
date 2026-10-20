package com.axis.axis

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class TodayTasksWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_today_tasks).apply {
                val title = widgetData.getString("today_tasks_title", "AXIS • TODAY") ?: "AXIS • TODAY"
                val count = widgetData.getString("today_tasks_count", "0/0 DONE") ?: "0/0 DONE"
                val content = widgetData.getString("today_tasks_content", "No tasks scheduled for today.")
                    ?: "No tasks scheduled for today."

                setTextViewText(R.id.widget_tasks_title, title)
                setTextViewText(R.id.widget_tasks_count, count)
                setTextViewText(R.id.widget_tasks_content, content)

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_today_tasks_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
