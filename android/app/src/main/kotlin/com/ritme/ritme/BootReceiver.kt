package com.ritme.ritme

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "RitmeBootReceiver"
        private const val CHANNEL = "com.ritme.ritme/boot"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                Log.i(TAG, "Boot/package event received: ${intent.action}")
                rescheduleNotifications(context)
            }
        }
    }

    private fun rescheduleNotifications(context: Context) {
        try {
            // Start a background Flutter engine to reschedule notifications
            val flutterEngine = FlutterEngine(context)
            
            flutterEngine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )

            val channel = MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                CHANNEL
            )

            channel.invokeMethod("rescheduleNotifications", null, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    Log.i(TAG, "Notifications rescheduled successfully")
                    flutterEngine.destroy()
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.e(TAG, "Failed to reschedule notifications: $errorCode - $errorMessage")
                    flutterEngine.destroy()
                }

                override fun notImplemented() {
                    Log.w(TAG, "rescheduleNotifications not implemented")
                    flutterEngine.destroy()
                }
            })
        } catch (e: Exception) {
            Log.e(TAG, "Error rescheduling notifications", e)
        }
    }
}
