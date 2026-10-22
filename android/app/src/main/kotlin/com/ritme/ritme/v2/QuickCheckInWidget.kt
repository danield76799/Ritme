package com.ritme.ritme.v2

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.Toast

/**
 * Home screen widget for quick Ritme check-in.
 *
 * Allows users to log their mood directly from the home screen:
 * - Tap 😞 for negative mood (-3)
 * - Tap 😐 for neutral mood (0)
 * - Tap 😄 for positive mood (+3)
 *
 * Uses BroadcastReceiver pattern to avoid Android 14+ background activity restrictions.
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
            val intent = Intent(context, QuickCheckInWidget::class.java).apply {
                action = ACTION_MOOD_SELECTED
                putExtra(EXTRA_MOOD_VALUE, moodValue)
                putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            // Unique request code per widget + mood value
            val requestCode = appWidgetId * 10 + when (moodValue) {
                -3.0 -> 1
                0.0 -> 2
                3.0 -> 3
                else -> 0
            }
            return PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_MOOD_SELECTED) {
            val moodValue = intent.getDoubleExtra(EXTRA_MOOD_VALUE, 0.0)
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putString("flutter.pendingMoodValue", moodValue.toString()).apply()
            // Also store in legacy location for MainActivity
            MainActivity.pendingMoodValue = moodValue
            
            val moodText = when (moodValue) {
                -3.0 -> "Slecht (-3)"
                0.0 -> "OK (0)"
                3.0 -> "Goed (+3)"
                else -> moodValue.toString()
            }
            Toast.makeText(context, "Stemming opgeslagen: $moodText", Toast.LENGTH_SHORT).show()
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
