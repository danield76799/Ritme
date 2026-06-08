import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import '../utils/logger.dart';

class NotificationHelper {
  static final NotificationHelper instance = NotificationHelper._();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  NotificationHelper._();

  Future<void> initialize() async {
    // Skip on web
    if (kIsWeb) return;

    try {
      tz.initializeTimeZones();
      // Initialize local timezone using flutter_timezone
      try {
        final timeZoneName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        debugPrint('Timezone set to: $timeZoneName');
      } catch (e) {
        debugPrint('Failed to set local timezone: $e');
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final initialized = await _notifications.initialize(initSettings);
      if (initialized == null || !initialized) {
        AppLogger.warning('Notificatie initialisatie mislukt of geweigerd');
        return;
      }
      
      // Request permissions on Android 13+ using permission_handler
      final permissionsGranted = await _requestPermissions();
      if (!permissionsGranted) {
        AppLogger.warning('Notificatie permissies geweigerd');
      }
    } catch (e) {
      AppLogger.error('Notificatie initialisatie error', error: e);
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      // Request notification permission
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (e) {
      AppLogger.error('Permission request error', error: e);
      return false;
    }
  }

  Future<void> scheduleDailyNotification({
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;

    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        'daily_reminders',
        'Dagelijkse Herinneringen',
        channelDescription: 'Dagelijkse herinneringen voor ritualen',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        0,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint('Daily notification scheduled for $hour:${minute.toString().padLeft(2, '0')}');
    } catch (e) {
      AppLogger.error('Daily notification scheduling error', error: e);
    }
  }

  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'immediate_notifications',
        'Directe Notificaties',
        channelDescription: 'Direct getoonde notificaties',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Immediate notification error: $e');
    }
  }

  Future<void> showTestNotification() async {
    await showImmediateNotification(
      title: '🧪 Test Notificatie',
      body: 'Als je dit ziet, werken notificaties!',
    );
  }

  Future<void> showTestNotificationAt({required int hour, required int minute}) async {
    if (kIsWeb) return;
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledTime = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute,
      );
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        'test_notifications', 'Test Notificaties',
        channelDescription: 'Test notificaties voor verifieren van instellingen',
        importance: Importance.high, priority: Priority.high,
        showWhen: true, enableVibration: true, playSound: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true, presentBadge: true, presentSound: true,
      );
      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _notifications.zonedSchedule(
        99999,
        '🧪 Test Notificatie',
        'Dit is je test notificatie om ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('Test notification scheduled for $scheduledTime');
    } catch (e) {
      debugPrint('Test notification scheduling error: $e');
      rethrow;
    }
  }

  Future<void> scheduleAppointmentReminder({
    required int appointmentId,
    required String title,
    required String doctorName,
    required String appointmentDate,
    required String appointmentTime,
    required int reminderDays,
  }) async {
    if (kIsWeb) return;
    if (reminderDays <= 0) return;

    try {
      final dateParts = appointmentDate.split('-');
      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);
      
      int hour = 9, minute = 0;
      if (appointmentTime.isNotEmpty) {
        final timeParts = appointmentTime.split(':');
        hour = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);
      }

      final appointmentDateTime = tz.TZDateTime(
        tz.local,
        year,
        month,
        day,
        hour,
        minute,
      );
      
      final reminderDateTime = appointmentDateTime.subtract(Duration(days: reminderDays));
      
      final now = tz.TZDateTime.now(tz.local);
      if (reminderDateTime.isBefore(now)) {
        debugPrint('Appointment reminder time has passed, skipping');
        return;
      }

      final notificationId = (appointmentId * 100) % 100000;

      const androidDetails = AndroidNotificationDetails(
        'appointment_reminders',
        'Afspraak herinneringen',
        channelDescription: 'Herinneringen voor medische afspraken',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        actions: [
          AndroidNotificationAction(
            'open',
            'Openen',
            showsUserInterface: false,
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'appointment',
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        notificationId,
        '📅 Afspraak herinnering',
        '$title${doctorName.isNotEmpty ? ' met $doctorName' : ''} over $reminderDays dag${reminderDays > 1 ? 'en' : ''}',
        reminderDateTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'appointment:$appointmentId',
      );
      debugPrint('Afspraak herinnering gepland voor $title op $reminderDateTime');
    } catch (e) {
      debugPrint('Afspraak herinnering error: $e');
    }
  }

  Future<void> cancelAppointmentReminder(int appointmentId) async {
    if (kIsWeb) return;
    try {
      final notificationId = (appointmentId * 100) % 100000;
      await _notifications.cancel(notificationId);
      debugPrint('Afspraak herinnering geannuleerd');
    } catch (e) {
      debugPrint('Afspraak herinnering annulering error: $e');
    }
  }

  Future<int> getPendingNotificationCount() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      return pending.length;
    } catch (e) {
      debugPrint('Error getting pending: $e');
      return 0;
    }
  }
}
