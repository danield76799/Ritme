package com.ritme.ritme

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Home screen widget for quick Ritme check-in.
 *
 * Allows users to log their mood directly from the home screen:
 * - Tap 😞 for negative mood (-3)
 * - Tap 😐 for neutral mood (0)
 * - Tap 😄 for positive mood (+3)
 *
 * Each tap opens the app and passes the selected mood via intent extras.
 */
class QuickCheckInWidget : AppWidgetProvider() {

    companion object {
        const val ACTION_MOOD_SELECTED = "com.ritme.ritme.MOOD_SELECTED"
        const val EXTRA_MOOD_VALUE = "mood_value"

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.quick_checkin_widget)

            // Set up mood buttons with pending intents
            views.setOnClickPendingIntent(
                R.id.btn_mood_bad,
                createMoodPendingIntent(context, appWidgetId, -3.0)
            )
            views.setOnClickPendingIntent(
                R.id.btn_mood_ok,
                createMoodPendingIntent(context, appWidgetId, 0.0)
            )
            views.setOnClickPendingIntent(
                R.id.btn_mood_good,
                createMoodPendingIntent(context, appWidgetId, 3.0)
            )

            // Open app button
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context,
                0,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_open_app, openAppPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun createMoodPendingIntent(context: Context, appWidgetId: Int, moodValue: Double): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = ACTION_MOOD_SELECTED
                putExtra(EXTRA_MOOD_VALUE, moodValue)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(
                context,
                appWidgetId + moodValue.toInt(), // Unique request code
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }
}
