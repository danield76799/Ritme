package com.ritme.ritme

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
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
