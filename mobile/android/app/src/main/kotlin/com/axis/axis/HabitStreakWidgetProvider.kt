package com.axis.axis

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class HabitStreakWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_habit_streak).apply {
                val streakDays = widgetData.getString("habit_streak_days", "🔥 0 DAYS") ?: "🔥 0 DAYS"
                val progress = widgetData.getString("habit_streak_progress", "0 of 0 habits completed today (0%)")
                    ?: "0 of 0 habits completed today (0%)"
                val badge = widgetData.getString("habit_streak_badge", "0/0 DONE") ?: "0/0 DONE"
                val content = widgetData.getString("habit_streak_content", "No habits created yet. Tap to add.")
                    ?: "No habits created yet. Tap to add."
                val quote = widgetData.getString("habit_streak_quote", "Consistency creates mastery • Tap to open")
                    ?: "Consistency creates mastery • Tap to open"
                val percent = widgetData.getInt("habit_streak_percent", 0)

                setTextViewText(R.id.widget_habit_streak_days, streakDays)
                setTextViewText(R.id.widget_habit_progress, progress)
                setTextViewText(R.id.widget_habit_badge, badge)
                setTextViewText(R.id.widget_habit_content, content)
                setTextViewText(R.id.widget_habit_quote, quote)
                setProgressBar(R.id.widget_habit_progressbar, 100, percent, false)

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_habit_streak_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
