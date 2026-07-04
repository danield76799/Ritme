package com.ritme.ritme.v2

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Calendar

class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "RitmeBootReceiver"
        private const val ALARM_REQUEST_CODE = 10001
        private const val ACTION_RESCHEDULE = "com.ritme.ritme.ACTION_RESCHEDULE_NOTIFICATIONS"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            ACTION_RESCHEDULE,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                Log.i(TAG, "Boot/package event received: ${intent.action}")
                scheduleRescheduleAlarm(context)
            }
        }
    }

    /**
     * Schedule a near-future alarm that will bring the Flutter app to the
     * foreground via MainActivity. When the app launches, the Dart side can
     * reschedule notifications from the database.
     *
     * This avoids spawning a full Flutter engine from a BroadcastReceiver,
     * which is unreliable on Android 12+ and frequently causes ANRs.
     */
    private fun scheduleRescheduleAlarm(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            // Use exact alarm only if allowed; otherwise fall back to inexact.
            val canScheduleExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                alarmManager.canScheduleExactAlarms()
            } else {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
            }

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                action = ACTION_RESCHEDULE
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                ALARM_REQUEST_CODE,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            // Schedule 10 seconds from now so the device is awake enough to
            // launch the app reliably, but not so far in the future that it
            // feels broken to the user.
            val triggerAtMillis = System.currentTimeMillis() + 10_000L

            if (canScheduleExact) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAtMillis,
                        pendingIntent,
                    )
                } else {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        triggerAtMillis,
                        pendingIntent,
                    )
                }
            } else {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAtMillis,
                        pendingIntent,
                    )
                } else {
                    alarmManager.set(
                        AlarmManager.RTC_WAKEUP,
                        triggerAtMillis,
                        pendingIntent,
                    )
                }
            }

            Log.i(TAG, "Reschedule alarm set for ${triggerAtMillis}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule reschedule alarm", e)
        }
    }
}
