import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unifiedpush/unifiedpush.dart';
import 'package:unifiedpush_platform_interface/data/failed_reason.dart';
import 'notification_helper.dart';

/// SunUP / UnifiedPush notification service
/// Primary: SunUP push via UnifiedPush
/// Fallback: Local notifications via NotificationHelper
enum PushMode { sunup, local, none }

class SunUpService {
  static final SunUpService instance = SunUpService._();
  SunUpService._();

  PushMode _mode = PushMode.none;
  String? _pushEndpoint;
  bool _initialized = false;

  PushMode get mode => _mode;
  String? get pushEndpoint => _pushEndpoint;
  bool get isSunUpActive => _mode == PushMode.sunup && _pushEndpoint != null;

  /// Initialize SunUP. If it fails, falls back to local notifications.
  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    try {
      await _initSunUp();
      _initialized = true;
    } catch (e) {
      debugPrint('SunUP init failed: $e');
      _mode = PushMode.local;
      _initialized = true;
    }
  }

  Future<void> _initSunUp() async {
    // Try to use existing distributor (SunUP, ntfy, etc.)
    final hasDistributor = await UnifiedPush.initialize(
      onNewEndpoint: (PushEndpoint endpoint, String instance) async {
        debugPrint('SunUP endpoint: ${endpoint.url}');
        _pushEndpoint = endpoint.url;
        _mode = PushMode.sunup;
        await _saveEndpoint(endpoint.url);
      },
      onRegistrationFailed: (FailedReason reason, String instance) {
        debugPrint('SunUP registration failed: $reason');
        _mode = PushMode.local;
      },
      onUnregistered: (String instance) {
        debugPrint('SunUP unregistered');
        _pushEndpoint = null;
        _mode = PushMode.local;
      },
      onMessage: (PushMessage message, String instance) {
        _handlePushMessage(message);
      },
    );

    if (hasDistributor == true) {
      await UnifiedPush.register();
    } else {
      // No external distributor — try to auto-select or fallback
      final distributors = await UnifiedPush.getDistributors();
      if (distributors.isNotEmpty) {
        // Auto-select first available distributor (SunUP, ntfy, etc.)
        await UnifiedPush.saveDistributor(distributors.first);
        await UnifiedPush.register();
      } else {
        debugPrint('No UP distributor available, falling back to local');
        _mode = PushMode.local;
      }
    }
  }

  void _handlePushMessage(PushMessage message) {
    try {
      final payload = utf8.decode(message.content);
      final data = jsonDecode(payload);
      final title = data['title'] ?? 'Ritme';
      final body = data['body'] ?? '';
      final type = data['type'] ?? 'general';

      NotificationHelper.instance.showImmediateNotification(
        title: title,
        body: body,
        payload: type,
      );
    } catch (e) {
      debugPrint('Push message parse error: $e');
    }
  }

  Future<void> _saveEndpoint(String endpoint) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sunup_endpoint', endpoint);
    } catch (e) {
      debugPrint('Failed to save endpoint: $e');
    }
  }

  /// Manually switch to local mode (user disabled SunUP)
  Future<void> disableSunUp() async {
    try {
      await UnifiedPush.unregister();
    } catch (_) {}
    _mode = PushMode.local;
    _pushEndpoint = null;
  }

  /// Re-enable SunUP
  Future<void> enableSunUp() async {
    _mode = PushMode.none;
    await initialize();
  }

  /// Schedule a medication reminder using the best available method
  Future<void> scheduleMedicationReminder({
    required int medicationId,
    required String medicationName,
    required String dosage,
    required String time,
    required List<int> daysOfWeek,
  }) async {
    // Always schedule local fallback
    await NotificationHelper.instance.scheduleMedicationReminder(
      medicationId: medicationId,
      medicationName: medicationName,
      dosage: dosage,
      time: time,
      daysOfWeek: daysOfWeek,
    );

    // If SunUP is active, also register with server
    if (isSunUpActive) {
      await _registerServerReminder(
        medicationId: medicationId,
        name: medicationName,
        dosage: dosage,
        time: time,
        days: daysOfWeek,
      );
    }
  }

  Future<void> _registerServerReminder({
    required int medicationId,
    required String name,
    required String dosage,
    required String time,
    required List<int> days,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminders = jsonDecode(prefs.getString('sunup_reminders') ?? '[]') as List;
      reminders.removeWhere((r) => r['id'] == medicationId);
      reminders.add({
        'id': medicationId,
        'name': name,
        'dosage': dosage,
        'time': time,
        'days': days,
        'endpoint': _pushEndpoint,
      });
      await prefs.setString('sunup_reminders', jsonEncode(reminders));
    } catch (e) {
      debugPrint('Server reminder registration failed: $e');
    }
  }

  Future<void> cancelMedicationReminder(int medicationId) async {
    // Cancel local
    await NotificationHelper.instance.cancelMedicationReminder(medicationId);

    // Cancel server-side if SunUP active
    if (isSunUpActive) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final reminders = jsonDecode(prefs.getString('sunup_reminders') ?? '[]') as List;
        reminders.removeWhere((r) => r['id'] == medicationId);
        await prefs.setString('sunup_reminders', jsonEncode(reminders));
      } catch (e) {
        debugPrint('Server reminder cancellation failed: $e');
      }
    }
  }

  /// Show immediate notification (works with both modes)
  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await NotificationHelper.instance.showImmediateNotification(
      title: title,
      body: body,
      payload: payload,
    );
  }
}
