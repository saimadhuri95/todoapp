package com.sai.knot

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/// Home-screen "Today" widget (TASKS.md 6.24). All formatting is done in Dart
/// (HomeWidgetService); this only renders the two saved strings and wires a
/// tap to open the app.
class TodayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val headline = widgetData.getString("headline", "Knot") ?: "Knot"
        val body = widgetData.getString("body", "") ?: ""

        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.today_widget).apply {
                setTextViewText(R.id.today_widget_headline, headline)
                setTextViewText(R.id.today_widget_titles, body)
                setOnClickPendingIntent(R.id.today_widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
