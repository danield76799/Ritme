package com.ritme.ritme.v2

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Ontvangt boot- en update-events.
 *
 * BELANGRIJK: deze receiver start de app NIET op.
 *
 * Eerdere versies deden dat wel via een AlarmManager-alarm plus een directe
 * `startActivity()`, zodat het Dart-gedeelte de notificaties kon herplannen.
 * Omdat ACTION_MY_PACKAGE_REPLACED direct na een installatie of update afgaat,
 * werd de app daardoor gestart vóórdat de gebruiker hem zelf opende: het
 * alarm vuurde 10 seconden later, en de startActivity gebeurde meteen.
 *
 * Het herplannen gebeurt nu native door
 * `ScheduledNotificationBootReceiver` van flutter_local_notifications
 * (geregistreerd in AndroidManifest.xml). Die leest de opgeslagen
 * notificaties en herplant ze zonder de UI te openen. Een activity vanuit de
 * achtergrond starten is sinds Android 10 bovendien aan banden gelegd.
 *
 * Deze receiver blijft bestaan zodat een expliciet
 * ACTION_RESCHEDULE-broadcast nog steeds gelogd wordt; de notificaties worden
 * daarnaast bij elke app-start hersteld via BootService.rescheduleIfEmpty().
 */
class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "RitmeBootReceiver"
        const val ACTION_RESCHEDULE = "com.ritme.ritme.ACTION_RESCHEDULE_NOTIFICATIONS"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            ACTION_RESCHEDULE,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" ->
                Log.i(TAG, "Boot/package event received: ${intent.action}")
        }
    }
}
