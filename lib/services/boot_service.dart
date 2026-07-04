import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';

import '../database/database_helper.dart';
import 'notification_helper.dart';

/// Service that reschedules all medication reminders after device reboot.
/// 
/// This is critical for medication adherence — if the phone reboots,
/// all scheduled local notifications are lost. This service restores them.
class BootService {
  static const MethodChannel _channel = MethodChannel('com.ritme.ritme/boot');
  static bool _initialized = false;

  /// Initialize the boot service. Call this in main() before runApp().
  static Future<void> initialize() async {
    if (_initialized) return;

    _channel.setMethodCallHandler(_handleMethodCall);
    _initialized = true;

    developer.log('BootService initialized', name: 'BootService');
  }

  /// Handle method calls from the Android BootReceiver
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'rescheduleNotifications':
        await _rescheduleAllNotifications();
        return null;
      default:
        throw MissingPluginException('Method ${call.method} not implemented');
    }
  }

  /// Reschedule all medication reminders from the database.
  /// 
  /// This is called:
  /// - After device reboot (via BootReceiver)
  /// - After app update (via MY_PACKAGE_REPLACED intent)
  /// - Manually for recovery
  /// Returns the number of reminders that were rescheduled.
  static Future<int> _rescheduleAllNotifications() async {
    developer.log('Rescheduling all medication reminders...', name: 'BootService');
    return await NotificationHelper.instance.rescheduleAllMedicationReminders();
  }

  /// Check if any medication reminders are scheduled. If not (e.g. Android
  /// killed them due to battery optimization), reschedule all from DB.
  /// Call this on every app startup to ensure reliability.
  static Future<int> rescheduleIfEmpty() async {
    try {
      final pendingCount = await NotificationHelper.instance.getPendingNotificationCount();
      if (pendingCount == 0) {
        developer.log(
          'No pending notifications found — likely killed by battery optimization. Rescheduling...',
          name: 'BootService',
        );
        return await _rescheduleAllNotifications();
      } else {
        developer.log(
          'Found $pendingCount pending notifications — no reschedule needed',
          name: 'BootService',
        );
        return 0;
      }
    } catch (e) {
      developer.log(
        'Error checking pending notifications: $e',
        name: 'BootService',
        error: e,
      );
      return 0;
    }
  }

  /// Manually trigger a reschedule (for testing or recovery).
  /// Returns the number of reminders that were rescheduled.
  static Future<int> rescheduleNow() async {
    return await _rescheduleAllNotifications();
  }
}