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
  static Future<void> _rescheduleAllNotifications() async {
    developer.log('Rescheduling all medication reminders...', name: 'BootService');

    try {
      final db = DatabaseHelper.instance;
      final schedules = await db.getMedicationSchedules();

      int rescheduled = 0;
      for (final schedule in schedules) {
        final enabled = schedule['enabled'] as int? ?? 0;
        if (enabled == 1) {
          final id = schedule['id'] as int?;
          final medicationId = schedule['medication_id'] as int?;
          final reminderTime = schedule['reminder_time'] as String?;
          final daysOfWeek = schedule['days_of_week'] as String?;
          
          if (id != null && medicationId != null && reminderTime != null) {
            // Get medication name
            final configs = await db.getMedicationConfigs();
            final config = configs.firstWhere(
              (c) => c['id'] == medicationId,
              orElse: () => {'naam': 'Medicatie'},
            );
            final name = config['naam'] as String? ?? 'Medicatie';
            
            // Parse days
            final days = daysOfWeek?.split(',').map(int.parse).toList() ?? [1,2,3,4,5,6,7];
            
            await NotificationHelper.instance.scheduleMedicationReminder(
              id: id,
              medicationName: name,
              time: reminderTime,
              days: days,
            );
            rescheduled++;
          }
        }
      }

      developer.log(
        'Rescheduled $rescheduled medication reminders',
        name: 'BootService',
      );
    } catch (e, stackTrace) {
      developer.log(
        'Failed to reschedule notifications',
        name: 'BootService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Manually trigger a reschedule (for testing or recovery).
  static Future<void> rescheduleNow() async {
    await _rescheduleAllNotifications();
  }
}
