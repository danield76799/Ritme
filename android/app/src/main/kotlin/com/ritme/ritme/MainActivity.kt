package com.ritme.ritme

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val BOOT_CHANNEL = "com.ritme.ritme/boot"
    private val WIDGET_CHANNEL = "com.ritme.ritme/widget"

    companion object {
        var pendingMoodValue: Double? = null
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
        handleWidgetIntent(intent)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        handleWidgetIntent(intent)
    }

    private fun handleWidgetIntent(intent: android.content.Intent?) {
        if (intent?.action == QuickCheckInWidget.ACTION_MOOD_SELECTED) {
            val moodValue = intent.getDoubleExtra(QuickCheckInWidget.EXTRA_MOOD_VALUE, 0.0)
            pendingMoodValue = moodValue
            // Notify Flutter side
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, WIDGET_CHANNEL).invokeMethod(
                    "onMoodSelected",
                    mapOf("mood" to moodValue)
                )
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Boot receiver channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BOOT_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "rescheduleNotifications" -> {
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Widget channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIDGET_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingMood" -> {
                    result.success(pendingMoodValue)
                    pendingMoodValue = null
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Medication reminders channel
            val medicationChannel = NotificationChannel(
                "medication_reminders",
                "Medicatie herinneringen",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Herinneringen voor medicatie inname"
                enableVibration(true)
                enableLights(true)
            }
            notificationManager.createNotificationChannel(medicationChannel)

            // Daily reminder channel
            val dailyChannel = NotificationChannel(
                "daily_reminder",
                "Dagelijkse herinnering",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Dagelijkse check-in herinnering"
                enableVibration(true)
                enableLights(true)
            }
            notificationManager.createNotificationChannel(dailyChannel)
        }
    }
}
