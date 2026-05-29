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
        final timezoneInfo = await FlutterTimezone.getLocalTimezone();
        final String timeZoneName = timezoneInfo.identifier;
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
        return;
      }
      
      // Schedule daily reminder
      await _scheduleDailyReminder();
    } catch (e) {
      debugPrint('Notificatie initialisatie error: $e');
    }
  }

  Future<bool> _requestPermissions() async {
    if (kIsWeb) return true;
    
    try {
      // Use permission_handler for explicit permission request on Android 13+
      if (!kIsWeb) {
        final status = await Permission.notification.status;
        if (status.isDenied || status.isRestricted) {
          final result = await Permission.notification.request();
          if (!result.isGranted) {
            AppLogger.warning('Notification permission denied via permission_handler');
            return false;
          }
        } else if (status.isPermanentlyDenied) {
          AppLogger.warning('Notification permission permanently denied');
          return false;
        }
      }

      // Also request via flutter_local_notifications for older Android versions
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        if (granted == null || !granted) {
          AppLogger.warning('Android notificatie permissies geweigerd');
          return false;
        }
        
        // Request exact alarm permission for Android 12+
        try {
          final exactAlarmGranted = await androidPlugin.requestExactAlarmsPermission();
          if (exactAlarmGranted == null || !exactAlarmGranted) {
            AppLogger.info('Exact alarm permission denied - scheduled notifications may not work');
          } else {
            AppLogger.debug('Exact alarm permission granted');
          }
        } catch (e) {
          AppLogger.warning('Could not request exact alarm permission: $e');
        }
      }

      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        if (granted == null || !granted) {
          AppLogger.warning('iOS notificatie permissies geweigerd');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      AppLogger.error('Permissie aanvraag error', error: e);
      return false;
    }
  }

  /// Check if notification permissions are granted
  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return true;
    
    try {
      // Check via permission_handler first
      final status = await Permission.notification.status;
      if (status.isGranted) return true;
      
      // Fallback: check via flutter_local_notifications
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final enabled = await androidPlugin.areNotificationsEnabled();
        return enabled ?? false;
      }
      
      return false;
    } catch (e) {
      AppLogger.error('Error checking notification status', error: e);
      return false;
    }
  }

  /// Open app settings to allow user to enable notifications
  Future<void> openNotificationSettings() async {
    await openAppSettings();
  }

  Future<void> _scheduleDailyReminder() async {
    if (kIsWeb) return;

    try {
      // Cancel any existing scheduled notification
      await _notifications.cancelAll();

      // Schedule for 20:00 local time daily
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        20,
        0,
      );

      // If 20:00 has passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        'daily_reminder',
        'Dagelijkse herinnering',
        channelDescription: 'Herinnert je aan je dagelijkse check-in',
        importance: Importance.high,
        priority: Priority.high,
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
        'Tijd voor je dagelijkse check-in!',
        'Heb je vandaag je stemming en SRM-activiteiten al ingevuld?',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('=== DAGELIJKSE HERINNERING GEPLAND ===');
      debugPrint('Scheduled for: $scheduledDate');
      debugPrint('Current device time: ${DateTime.now()}');
    } catch (e) {
      debugPrint('Herinnering planning error: $e');
    }
  }

  /// Schedule a medication reminder at a specific time on specific days.
  /// 
  /// [id] - Unique ID for this reminder (used for cancellation)
  /// [medicationName] - Name of the medication to display
  /// [time] - Time in "HH:MM" format (24h)
  /// [days] - List of weekdays (1=Monday, 7=Sunday)
  Future<void> scheduleMedicationReminder({
    required int id,
    required String medicationName,
    required String time,
    required List<int> days,
  }) async {
    if (kIsWeb) return;

    try {
      // Parse time
      final parts = time.split(':');
      if (parts.length != 2) {
        debugPrint('Invalid time format: $time');
        return;
      }
      final hour = int.tryParse(parts[0]) ?? 8;
      final minute = int.tryParse(parts[1]) ?? 0;

      // Cancel existing reminder with this ID
      await cancelMedicationReminder(id);

      // Schedule for each day
      for (final day in days) {
        final now = tz.TZDateTime.now(tz.local);
        var scheduledDate = _nextInstanceOfDayTime(day, hour, minute);

        // Skip if the calculated date is somehow in the past
        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 7));
        }

        final androidDetails = AndroidNotificationDetails(
          'medication_reminders',
          'Medicatie herinneringen',
          channelDescription: 'Herinneringen voor medicatie inname',
          importance: Importance.high,
          priority: Priority.high,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.reminder,
          actions: const [
            AndroidNotificationAction(
              'taken',
              '✓ Genomen',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'skip',
              '⏭ Overslaan',
              showsUserInterface: false,
            ),
          ],
        );

        const iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

        final details = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        // Use unique ID per day: baseId + day offset
        final notificationId = id * 10 + day;

        await _notifications.zonedSchedule(
          notificationId,
          '💊 $medicationName',
          'Het is tijd om je medicatie te nemen',
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }

      debugPrint('Medicatie herinnering gepland: $medicationName om $time op dagen $days');
    } catch (e) {
      debugPrint('Medicatie herinnering planning error: $e');
    }
  }

  /// Cancel a specific medication reminder.
  Future<void> cancelMedicationReminder(int id) async {
    if (kIsWeb) return;

    // Cancel all day variants for this medication
    for (int day = 1; day <= 7; day++) {
      await _notifications.cancel(id * 10 + day);
    }
  }

  /// Cancel all scheduled reminders.
  Future<void> cancelAllReminders() async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
  }

  /// Find the next occurrence of a specific day and time.
  tz.TZDateTime _nextInstanceOfDayTime(int day, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Adjust to the target day of week
    final currentDay = scheduledDate.weekday;
    int daysUntilTarget = day - currentDay;
    if (daysUntilTarget < 0) {
      daysUntilTarget += 7;
    }
    
    scheduledDate = scheduledDate.add(Duration(days: daysUntilTarget));

    // If the time has already passed today, move to next week
    if (daysUntilTarget == 0 && scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    return scheduledDate;
  }

  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    try {
      const androidDetails = AndroidNotificationDetails(
        'immediate_channel',
        'Directe notificaties',
        channelDescription: 'Directe notificaties van SunUP of app',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        enableLights: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
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
      debugPrint('Afspraak herinnering planning error: $e');
      rethrow;
    }
  }

  Future<void> cancelAppointmentReminder(int appointmentId) async {
    if (kIsWeb) return;
    
    try {
      final notificationId = (appointmentId * 100) % 100000;
      await _notifications.cancel(notificationId);
      debugPrint('Afspraak herinnering geannuleerd voor ID: $appointmentId');
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
