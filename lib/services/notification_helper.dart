import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationHelper {
  static final NotificationHelper instance = NotificationHelper._();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  NotificationHelper._();

  Future<void> initialize() async {
    // Skip on web
    if (kIsWeb) return;

    try {
      tz.initializeTimeZones();

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
        debugPrint('Notificatie initialisatie mislukt of geweigerd');
        return;
      }
      
      // Request permissions on Android 13+
      final permissionsGranted = await _requestPermissions();
      if (!permissionsGranted) {
        debugPrint('Notificatie permissies geweigerd');
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
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        if (granted == null || !granted) {
          debugPrint('Android notificatie permissies geweigerd');
          return false;
        }
        
        // Request exact alarm permission for Android 12+
        try {
          final exactAlarmGranted = await androidPlugin.requestExactAlarmsPermission();
          if (exactAlarmGranted == null || !exactAlarmGranted) {
            debugPrint('Exact alarm permission denied - scheduled notifications may not work');
          } else {
            debugPrint('Exact alarm permission granted');
          }
        } catch (e) {
          debugPrint('Could not request exact alarm permission: $e');
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
          debugPrint('iOS notificatie permissies geweigerd');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('Permissie aanvraag error: $e');
      return false;
    }
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
        playSound: true, // Sound + vibration
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true, // Sound + vibration
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

  Future<void> scheduleMedicationReminder({
    required int medicationId,
    required String medicationName,
    required String dosage,
    required String time,
    required List<int> daysOfWeek,
  }) async {
    if (kIsWeb) return;

    debugPrint('=== SCHEDULE MEDICATION REMINDER ===');
    debugPrint('Medication: $medicationName, Time: $time, Days: $daysOfWeek');

    try {
      // Parse time string (HH:MM)
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      debugPrint('Parsed time - Hour: $hour, Minute: $minute');

      // Cancel existing notifications for this medication
      await cancelMedicationReminder(medicationId);
      
      // Request permissions first
      final permissionsGranted = await _requestPermissions();
      if (!permissionsGranted) {
        debugPrint('Cannot schedule notification - permissions denied');
        throw Exception('Notificatie permissies geweigerd');
      }

      // Schedule for each day of the week
      for (final day in daysOfWeek) {
        // Use smaller notification ID to prevent overflow
        final notificationId = (medicationId * 10 + day) % 100000;
        
        final scheduledDate = _nextInstanceOfTime(hour, minute, day);
        
        const androidDetails = AndroidNotificationDetails(
          'medication_reminders',
          'Medicatie herinneringen',
          channelDescription: 'Herinneringen voor medicatie inname',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true, // Sound + vibration
          actions: [
            AndroidNotificationAction(
              'taken',
              '✓ Ingenomen',
              showsUserInterface: false,
            ),
            AndroidNotificationAction(
              'skip',
              '✗ Overslaan',
              showsUserInterface: false,
            ),
          ],
        );

        const iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true, // Sound + vibration
          categoryIdentifier: 'medication',
        );

        const details = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        await _notifications.zonedSchedule(
          notificationId,
          '💊 Medicatie herinnering',
          'Neem $medicationName ($dosage)',
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'medication:$medicationId',
        );
      }
      debugPrint('Medicatie herinnering gepland voor $medicationName om $time');
      
      // Check pending notifications
      final pending = await _notifications.pendingNotificationRequests();
      debugPrint('=== PENDING NOTIFICATIONS: ${pending.length} ===');
      for (var n in pending) {
        debugPrint('  - ID: ${n.id}, Title: ${n.title}, Body: ${n.body}');
      }
    } catch (e) {
      debugPrint('Medicatie herinnering planning error: $e');
      rethrow;
    }
  }

  Future<void> cancelMedicationReminder(int medicationId) async {
    if (kIsWeb) return;
    
    try {
      // Cancel all notifications for this medication (up to 7 days)
      // Use modulo to match the smaller IDs
      final baseId = medicationId % 100000;
      for (int day = 1; day <= 7; day++) {
        await _notifications.cancel((baseId * 10 + day) % 100000);
      }
      debugPrint('Medicatie herinneringen geannuleerd voor ID: $medicationId');
    } catch (e) {
      debugPrint('Medicatie herinnering annulering error: $e');
    }
  }

  Future<void> cancelAllReminders() async {
    if (kIsWeb) return;
    
    try {
      await _notifications.cancelAll();
      debugPrint('Alle notificaties geannuleerd');
    } catch (e) {
      debugPrint('Annulering error: $e');
    }
  }

  Future<void> showTestNotification() async {
    if (kIsWeb) return;
    
    try {
      const androidDetails = AndroidNotificationDetails(
        'test_channel',
        'Test Notificaties',
        channelDescription: 'Test kanaal voor notificaties',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true, // Sound + vibration
        enableLights: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true, // Sound + vibration
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        99999,
        '🧪 Test Notificatie',
        'Als je dit ziet, werken notificaties!',
        details,
      );
      debugPrint('Test notificatie verzonden (alleen tril)');
    } catch (e) {
      debugPrint('Test notificatie error: $e');
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute, int dayOfWeek) {
    final now = tz.TZDateTime.now(tz.local);
    debugPrint('=== _nextInstanceOfTime ===');
    debugPrint('Input: hour=$hour, minute=$minute, dayOfWeek=$dayOfWeek');
    debugPrint('Current time: $now');
    
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    debugPrint('Initial scheduledDate: $scheduledDate, weekday: ${scheduledDate.weekday}');

    // If the time has already passed today, start from tomorrow
    if (scheduledDate.isBefore(now)) {
      debugPrint('Time already passed today, moving to tomorrow');
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Advance to the correct weekday
    while (scheduledDate.weekday != dayOfWeek) {
      debugPrint('Wrong weekday (${scheduledDate.weekday}), advancing to next day');
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    debugPrint('Final scheduledDate: $scheduledDate');
    return scheduledDate;
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
    if (reminderDays <= 0) return; // No reminder

    try {
      // Parse appointment date/time
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

      // Calculate reminder date/time
      final appointmentDateTime = tz.TZDateTime(
        tz.local,
        year,
        month,
        day,
        hour,
        minute,
      );
      
      final reminderDateTime = appointmentDateTime.subtract(Duration(days: reminderDays));
      
      // Don't schedule if reminder time has passed
      final now = tz.TZDateTime.now(tz.local);
      if (reminderDateTime.isBefore(now)) {
        debugPrint('Appointment reminder time has passed, skipping');
        return;
      }

      // Use smaller notification ID
      final notificationId = (appointmentId * 100) % 100000;

      const androidDetails = AndroidNotificationDetails(
        'appointment_reminders',
        'Afspraak herinneringen',
        channelDescription: 'Herinneringen voor medische afspraken',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true, // Sound + vibration
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
        presentSound: true, // Sound + vibration
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
}