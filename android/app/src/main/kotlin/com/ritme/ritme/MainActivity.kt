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

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BOOT_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "rescheduleNotifications" -> {
                    // The Flutter side will handle the actual rescheduling
                    // This is just a bridge from the BootReceiver
                    result.success(null)
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
