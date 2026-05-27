import 'dart:developer' as developer;

import 'package:flutter/services.dart';

import '../database/database_helper.dart';

/// Service that handles home screen widget interactions.
///
/// When user taps a mood button on the widget, the Android side
/// stores the mood value and notifies Flutter via MethodChannel.
/// This service picks up that value and saves it to the database.
class WidgetService {
  static const MethodChannel _channel =
      MethodChannel('com.ritme.ritme/widget');
  static bool _initialized = false;

  /// Initialize the widget service. Call this in main() before runApp().
  static Future<void> initialize() async {
    if (_initialized) return;

    _channel.setMethodCallHandler(_handleMethodCall);
    _initialized = true;

    // Check if there's a pending mood from a widget tap
    await _checkPendingMood();

    developer.log('WidgetService initialized', name: 'WidgetService');
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onMoodSelected':
        final mood = call.arguments['mood'] as double?;
        if (mood != null) {
          await _saveMood(mood);
        }
        return null;
      default:
        throw MissingPluginException('Method ${call.method} not implemented');
    }
  }

  /// Check if there's a pending mood value from a widget tap
  /// that occurred while the app was closed.
  static Future<void> _checkPendingMood() async {
    try {
      final pendingMood = await _channel.invokeMethod('getPendingMood');
      if (pendingMood != null) {
        final mood = pendingMood is double
            ? pendingMood
            : double.tryParse(pendingMood.toString());
        if (mood != null) {
          await _saveMood(mood);
        }
      }
    } catch (e) {
      developer.log('No pending mood from widget', name: 'WidgetService');
    }
  }

  /// Save mood to daily_logs with default sleep hours.
  static Future<void> _saveMood(double mood) async {
    try {
      final now = DateTime.now();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final db = DatabaseHelper.instance;

      // Get existing log to preserve sleep hours if already entered
      final existing = await db.getDailyLog(today);
      final sleepHours = existing?['uren_slaap'] as double? ?? 7.0;

      await db.upsertDailyLog({
        'date': today,
        'stemming_hoog': mood,
        'stemming_laag': mood,
        'gesplitste_stemming': false,
        'uren_slaap': sleepHours,
      });

      developer.log('Widget mood saved: $mood', name: 'WidgetService');
    } catch (e, stackTrace) {
      developer.log('Failed to save widget mood',
          name: 'WidgetService', error: e, stackTrace: stackTrace);
    }
  }
}
