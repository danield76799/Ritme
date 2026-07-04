import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/intl.dart';
import '../service_locator.dart';
import '../utils/logger.dart';

class NotificationHelper {
  static final NotificationHelper instance = NotificationHelper._();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  NotificationHelper._();

  Future<void> initialize() async {
    if (kIsWeb) return;

    try {
      tz.initializeTimeZones();
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

      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );
      if (initialized == null || !initialized) {
        AppLogger.warning('Notificatie initialisatie mislukt of geweigerd');
        return;
      }
      
      // Request runtime permissions (notification + exact alarm).
      // This is required on Android 12+ for medication reminders to fire on time.
      await requestNotificationPermissions();
    } catch (e) {
      AppLogger.error('Notificatie initialisatie error', error: e);
    }
  }

  /// Check and request all required permissions at runtime.
  /// Shows system settings when needed and returns true if all critical
  /// permissions are granted.
  Future<bool> requestNotificationPermissions() async {
    if (kIsWeb) return true;

    try {
      // POST_NOTIFICATIONS (Android 13+)
      final notifStatus = await Permission.notification.request();
      if (!notifStatus.isGranted) {
        AppLogger.warning('Notification permission denied');
        return false;
      }

      // Exact alarm (Android 12+). SCHEDULE_EXACT_ALARM is a special permission:
      // it can only be granted by the user through the system settings.
      final androidImpl = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final canScheduleExact = await androidImpl.canScheduleExactNotifications() ?? false;
        if (!canScheduleExact) {
          AppLogger.warning('Exact alarm permission not granted; opening system settings');
          await androidImpl.requestExactAlarmsPermission();
        }
      }

      return true;
    } catch (e) {
      AppLogger.error('Permission request error', error: e);
      return false;
    }
  }

  /// Open the system battery optimization settings so the user can disable
  /// battery optimization for this app. Without this, scheduled alarms may not
  /// fire reliably in the background.
  Future<bool> openBatteryOptimizationSettings() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        final result = await Permission.ignoreBatteryOptimizations.request();
        return result.isGranted;
      }
      return true;
    } catch (e) {
      AppLogger.error('Battery optimization request error', error: e);
      return false;
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      // Standard notification permission
      final notifStatus = await Permission.notification.request();
      if (!notifStatus.isGranted) return false;

      // Exact alarm permission (Android 12+ — required for exactAllowWhileIdle)
      try {
        final alarmStatus = await Permission.scheduleExactAlarm.request();
        if (!alarmStatus.isGranted) {
          AppLogger.warning('Exact alarm permission denied — notifications may be delayed');
        }
      } catch (_) {
        // scheduleExactAlarm only exists on Android 12+
      }

      return true;
    } catch (e) {
      AppLogger.error('Permission request error', error: e);
      return false;
    }
  }

  /// Reschedule all medication reminders from the database. Useful after
  Future<int> rescheduleAllMedicationReminders() async {
    if (kIsWeb) return 0;

    try {
      await ensureInitialized();
      final configs = await db.getMedicationConfigs();
      final schedules = await db.getMedicationSchedules();

      int rescheduled = 0;
      for (final schedule in schedules) {
        final enabledStr = schedule['enabled']?.toString() ?? '0';
        final enabled = enabledStr == '1' || enabledStr.toLowerCase() == 'true';
        if (!enabled) continue;

        final idRaw = schedule['id'];
        final medicationIdRaw = schedule['medication_id'];
        final reminderTime = schedule['reminder_time']?.toString();
        final daysOfWeekRaw = schedule['days_of_week']?.toString();

        final id = idRaw is int ? idRaw : int.tryParse(idRaw.toString());
        final medicationId = medicationIdRaw is int ? medicationIdRaw : int.tryParse(medicationIdRaw.toString());
        if (id == null || medicationId == null || reminderTime == null) continue;

        final config = configs.firstWhere(
          (c) {
            final cid = c['id'];
            final cvalue = cid is int ? cid : int.tryParse(cid.toString());
            return cvalue == medicationId;
          },
          orElse: () => {'naam': 'Medicatie'},
        );
        final name = config['naam']?.toString() ?? 'Medicatie';
        final days = daysOfWeekRaw?.split(',').map((s) => int.tryParse(s.trim())).whereType<int>().toList() ??
            [1, 2, 3, 4, 5, 6, 7];

        await scheduleMedicationReminder(
          id: id,
          medicationName: name,
          time: reminderTime,
          days: days,
        );
        rescheduled++;
      }

      AppLogger.info('Rescheduled $rescheduled medication reminders from DB');
      return rescheduled;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to reschedule medication reminders', error: e, stackTrace: stackTrace);
      return 0;
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

  /// Schedule medication reminder with optional days-of-week filter
  Future<void> scheduleMedicationReminder({
    required int id,
    required String medicationName,
    required String time,
    List<int> days = const [1, 2, 3, 4, 5, 6, 7],
  }) async {
    if (kIsWeb) return;

    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final dayNames = ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo'];
      final daysStr = days.map((d) => dayNames[d - 1]).join(', ');

      const androidDetails = AndroidNotificationDetails(
        'medication_reminders',
        'Medicatie Herinneringen',
        channelDescription: 'Herinneringen voor medicatie inname',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
        ticker: 'Medicatie herinnering',
        actions: [
          AndroidNotificationAction('taken', '✅ Ingenomen'),
          AndroidNotificationAction('skip', '⏭ Sla over'),
          AndroidNotificationAction('snooze', '⏳ Snooze (15m)'),
        ],
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true, presentBadge: true, presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );
      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      // Use unique ID to avoid collisions — add 100_000 offset
      final notificationId = (id % 90000) + 10000;

      // Cancel any prior version of this notification first to avoid
      // orphaned or duplicate scheduled notifications.
      await _notifications.cancel(notificationId);

      // Re-validate the alarm permission right before scheduling.
      // Android 14+ can revoke SCHEDULE_EXACT_ALARM silently.
      final androidImpl = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canScheduleExact = await androidImpl?.canScheduleExactNotifications() ?? false;
      if (!canScheduleExact) {
        AppLogger.warning('Exact alarm permission missing — scheduling with inexact mode');
      }

      await _notifications.zonedSchedule(
        notificationId,
        '💊 $medicationName',
        'Tijd om je medicatie in te nemen! ($daysStr)',
        scheduledDate,
        details,
        androidScheduleMode: canScheduleExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'medication:$id',
        matchDateTimeComponents: DateTimeComponents.time, // Correct for daily repeat
      );
      AppLogger.info('Medication reminder scheduled: $medicationName at $scheduledDate (id=$notificationId, exact=$canScheduleExact)');
    } catch (e) {
      AppLogger.error('Medication scheduling error for $medicationName', error: e);
    }
  }
  Future<void> cancelMedicationReminder(int id) async {
    if (kIsWeb) return;
    try {
      final notificationId = (id % 90000) + 10000;
      await _notifications.cancel(notificationId);
      AppLogger.info('Medication reminder cancelled: $id (notificationId=$notificationId)');
    } catch (e) {
      AppLogger.error('Cancel medication error for id=$id', error: e);
    }
  }

  Future<void> cancelAllReminders() async {
    if (kIsWeb) return;
    try {
      await _notifications.cancelAll();
      debugPrint('All reminders cancelled');
    } catch (e) {
      debugPrint('Cancel all error: $e');
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

  void _onNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    final actionId = response.actionId;

    if (payload != null && payload.startsWith('medication:')) {
      final medicationId = int.tryParse(payload.split(':')[1]);
      if (medicationId != null) {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

        await ensureInitialized();

        if (actionId == 'taken') {
          await db.insertMedicationIntakeMap({
            'medication_id': medicationId,
            'date': today,
            'aantal_ingenomen': 1,
          });
          AppLogger.debug('Medication $medicationId marked as taken');
        } else if (actionId == 'skip') {
          await db.insertMedicationIntakeMap({
            'medication_id': medicationId,
            'date': today,
            'aantal_ingenomen': 0,
          });
          AppLogger.debug('Medication $medicationId marked as skipped');
        } else if (actionId == 'snooze') {
          // Snooze for 15 minutes
          final snoozeTime = DateTime.now().add(const Duration(minutes: 15));
          
          // We need the medication name to reschedule. 
          // For now, we'll use a generic "Medicatie" or fetch it from DB if available.
          // Since we don't have easy access to the name here without a DB call, 
          // we'll use the payload to identify it.
          
          debugPrint('Snoozing medication $medicationId for 15 minutes...');
          
          // Reschedule a one-time notification for 15 mins from now
          await _notifications.zonedSchedule(
            (medicationId % 90000) + 10000,
            '💊 Herinnering',
            'Tijd om je medicatie in te nemen! (Snoozed)',
            tz.TZDateTime.now(tz.local).add(const Duration(minutes: 15)),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'medication_reminders',
                'Medicatie Herinneringen',
                importance: Importance.max,
                priority: Priority.max,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            payload: 'medication:$medicationId',
          );
        }
      }
    }
  }
}
