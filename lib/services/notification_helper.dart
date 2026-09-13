import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/notif_strings.dart';
import '../utils/checkin_status.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/intl.dart';
import '../service_locator.dart';
import '../utils/logger.dart';

class NotificationHelper {
  static final NotificationHelper instance = NotificationHelper._();

  /// Route die geopend moet worden nadat de gebruiker op een check-in
  /// notificatie heeft getikt. De navigator leest dit uit zodra de app weer
  /// vooraan staat; daarna wordt het gewist.
  String? _pendingCheckinRoute;

  /// Pakt (en wist) de wachtende check-in route, of null als er niets wacht.
  String? consumePendingCheckinRoute() {
    final route = _pendingCheckinRoute;
    _pendingCheckinRoute = null;
    return route;
  }
  /// Is de tijdzone in DEZE isolate al gezet?
  ///
  /// Bewust per isolate: de WorkManager-taak draait in een eigen isolate met
  /// eigen globals. Statisch overerving helpt daar niet.
  static bool _tzReady = false;

  /// Zet de lokale tijdzone, precies één keer per isolate.
  ///
  /// WAAROM DIT EEN EIGEN METHODE IS
  /// [tz.initializeTimeZones] zet de lokale zone op **UTC** (zie
  /// timezone/lib/src/env.dart: `_local = _UTC`). Zonder een volgende
  /// [tz.setLocalLocation] rekent alles in UTC — in Nederland scheelt dat in de
  /// zomer 2 uur, dus een melding van 19:30 komt dan om 21:30.
  ///
  /// Dat gebeurde op twee plekken:
  ///  1. de fallback in de catch deed alleen een debugPrint en zette dus niets;
  ///  2. de WorkManager-taak riep initialize() nooit aan, waardoor `tz.local`
  ///     in die isolate zelfs een LateInitializationError gooide en de hele
  ///     herplanning stil mislukte.
  ///
  /// Vandaar: idempotent, en aangeroepen op ELK pad dat plant.
  Future<void> _ensureTimeZoneInitialized() async {
    if (_tzReady) return;

    // initializeTimeZones() reset de lokale zone naar UTC, dus mag maar één
    // keer per isolate gebeuren. De _tzReady-guard hierboven regelt dat.
    tz.initializeTimeZones();

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      // flutter_timezone 5.0.x geeft een object wiens identifier de IANA-naam is.
      final String timeZoneName = timezoneInfo.identifier.isNotEmpty
          ? timezoneInfo.identifier
          : timezoneInfo.toString();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      _tzReady = true;
      debugPrint('Timezone set to: $timeZoneName');
      return;
    } catch (e) {
      debugPrint('Kon tijdzone niet via de plugin bepalen: $e');
    }

    // Fallback: bouw een vaste zone op basis van de UTC-offset van het toestel.
    // Nodig omdat tz zonder setLocalLocation op UTC blijft en alle meldingen
    // dan uren verschoven worden.
    try {
      final offset = DateTime.now().timeZoneOffset;
      final uren = offset.inHours;
      if (offset.inMinutes % 60 != 0) {
        // Halve/hele-kwartierzones (bijv. India) zijn niet als Etc/GMT-zone
        // uit te drukken. Dan blijft het bij UTC + een duidelijke waarschuwing.
        AppLogger.warning(
            'Tijdzone heeft een niet-heel-uur offset ($offset); valt terug op UTC');
        _tzReady = true;
        return;
      }
      // Let op het teken: in de tz-database betekent Etc/GMT+2 juist UTC-2.
      final naam = 'Etc/GMT${uren >= 0 ? '-' : '+'}${uren.abs()}';
      tz.setLocalLocation(tz.getLocation(naam));
      _tzReady = true;
      debugPrint('Fallback tijdzone gezet op $naam (offset=$offset)');
    } catch (e) {
      AppLogger.warning('Kon ook geen fallback-tijdzone zetten: $e');
      _tzReady = true; // niet blijven proberen; UTC is dan het beste wat we hebben
    }
  }

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  NotificationHelper._();

  Future<void> initialize() async {
    if (kIsWeb) return;

    try {
      await _ensureTimeZoneInitialized();

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

      // Koude start vanuit een notificatie: als de app niet liep toen de
      // gebruiker tikte, komt de payload NIET via de callback hierboven maar
      // via de launch-details van de plugin. Zonder deze regel zou tikken op
      // een melding bij een afgesloten app de app wel openen, maar niet
      // doornavigeren naar de check-in.
      final launchDetails = await _notifications.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        final payload = launchDetails?.notificationResponse?.payload;
        if (payload != null) {
          _onNotificationResponse(launchDetails!.notificationResponse!);
        }
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

  /// Controleer of alle benodigde notificatiepermissies zijn gegeven.
  /// Opent de systeeminstellingen als SCHEDULE_EXACT_ALARM ontbreekt.
  /// Geeft true terug als het veilig is om exacte alarmen in te plannen.
  Future<bool> ensurePermissions() async {
    if (kIsWeb) return true;
    try {
      final notifStatus = await Permission.notification.request();
      if (!notifStatus.isGranted) {
        AppLogger.warning('Notification permission denied');
        return false;
      }

      final androidImpl = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl == null) return true;

      final canScheduleExact = await androidImpl.canScheduleExactNotifications() ?? false;
      if (!canScheduleExact) {
        AppLogger.warning('Exact alarm permission denied; opening settings');
        await androidImpl.requestExactAlarmsPermission();
        // Return false; app will reschedule on next startup or user can manually retry.
        return false;
      }
      return true;
    } catch (e) {
      AppLogger.error('ensurePermissions error', error: e);
      return false;
    }
  }

  /// Reschedule all medication reminders from the database. Useful after
  /// reboot or app restart. **Important:** Cancels ALL existing medication
  /// reminders first to prevent duplicates from multiple app launches.
  Future<int> rescheduleAllMedicationReminders() async {
    if (kIsWeb) return 0;

    try {
      await ensureInitialized();
      // De tijdsberekeningen hieronder gebruiken tz.local; in een verse
      // isolate (WorkManager) is die nog niet gezet.
      await _ensureTimeZoneInitialized();

      // CRITICAL: Clean up orphaned/duplicate DB schedules and cancel ALL
      // existing local notifications before rescheduling. This prevents stale
      // reminders from deleted/disabled medications from reappearing.
      await db.cleanupMedicationSchedulesAndCancelNotifications();
      await cancelAllReminders();
      
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
          orElse: () => {'naam': NotifStrings.medication},
        );
        final name = config['naam']?.toString() ?? NotifStrings.medication;
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

      AppLogger.info('Rescheduled $rescheduled medication reminders');
      // De check-in herinneringen worden hier — en niet bij de aanroeper —
      // gepland, omdat de cancelAllReminders() hierboven ALLE notificaties wist.
      // Alles wat vóór die aanroep is gepland, verdwijnt weer. Door dit hier te
      // doen kan geen enkele aanroeper de volgorde nog verkeerd hebben.
      //
      // In een EIGEN try/catch: een fout hierin mag de medicatie-herinneringen
      // niet als mislukt laten gelden — die zijn op dit punt al gepland.
      try {
        await rescheduleCheckinReminders();
      } catch (e, stackTrace) {
        AppLogger.error('Check-in herinneringen plannen mislukt (medicatie is wel gepland)',
            error: e, stackTrace: stackTrace);
      }
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

      final androidDetails = AndroidNotificationDetails(
        'daily_reminders',
        NotifStrings.dailyReminders,
        channelDescription: NotifStrings.dailyRemindersDesc,
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

      final details = NotificationDetails(
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

      final details = NotificationDetails(
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

      // Controleer of het icoon er echt is. R8/shrinkResources kan het
      // notificatie-icoon uit de bundle gooien (het wordt alleen via een
      // string aangeduid, niet vanuit XML), en dan mislukt een notificatie
      // ZONDER foutmelding: de aanroep hierboven slaagt gewoon. Zonder deze
      // controle meldt de app "verstuurd" terwijl er niets verschijnt.
      final androidImpl = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await androidImpl?.areNotificationsEnabled();
      if (enabled == false) {
        AppLogger.warning(
            'Notificatie verstuurd, maar meldingen staan UIT voor deze app '
            '(systeeminstelling). De gebruiker ziet nu niets.');
      }
    } catch (e, stackTrace) {
      // Niet stil inslikken: de aanroeper moet kunnen tonen dat het mislukte.
      // Eerder stond hier alleen een debugPrint, waardoor een echte fout
      // onzichtbaar bleef en de UI 'verstuurd' meldde.
      AppLogger.error('Immediate notification error', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> showTestNotification() async {
    await showImmediateNotification(
      title: NotifStrings.testNotification,
      body: NotifStrings.testNotificationBody,
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

      final androidDetails = AndroidNotificationDetails(
        'test_notifications', NotifStrings.testNotifications,
        channelDescription: NotifStrings.testNotificationsDesc,
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
      final localTzName = now.timeZoneName;
      AppLogger.info('Scheduling $medicationName for ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} (device tz=$localTzName, offset=${now.timeZoneOffset})');

      final dayNames = NotifStrings.dayNames;
      final daysStr = days.map((d) => dayNames[d - 1]).join(', ');

      final androidDetails = AndroidNotificationDetails(
        'medication_reminders',
        NotifStrings.medicationReminders,
        channelDescription: NotifStrings.medicationRemindersDesc,
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
        ticker: NotifStrings.medicationReminder,
        actions: [
          AndroidNotificationAction('taken', NotifStrings.taken),
          AndroidNotificationAction('skip', NotifStrings.skip),
          AndroidNotificationAction('snooze', NotifStrings.snooze),
        ],
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true, presentBadge: true, presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );
      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      // Use unique ID to avoid collisions — add 100_000 offset
      final notificationId = (id % 90000) + 10000;

      // Cancel any prior version of this notification first
      await _notifications.cancel(notificationId);

      // Check exact alarm permission, but ALWAYS schedule — fallback to inexact
      final androidImpl = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canScheduleExact = await androidImpl?.canScheduleExactNotifications() ?? false;

      if (days.length == 7) {
        // Every day — use daily repeating schedule
        var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }

        await _notifications.zonedSchedule(
          notificationId,
          '💊 $medicationName',
          NotifStrings.timeToTakeMedication(daysStr),
          scheduledDate,
          details,
          androidScheduleMode: canScheduleExact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'medication:$id',
          matchDateTimeComponents: DateTimeComponents.time,
        );
        AppLogger.info('Medication reminder scheduled (daily): $medicationName at $scheduledDate (id=$notificationId, exact=$canScheduleExact)');
      } else {
        // Specific days — schedule each day of the week separately
        // ISO weekday: Monday=1, Sunday=7
        // tz.TZDateTime: weekday: Monday=1, Sunday=7 (same as ISO)
        for (final dayOfWeek in days) {
          final dayNotificationId = notificationId * 10 + dayOfWeek;
          await _notifications.cancel(dayNotificationId);

          var scheduledDate = _nextWeekday(now, dayOfWeek, hour, minute);

          await _notifications.zonedSchedule(
            dayNotificationId,
            '💊 $medicationName',
            NotifStrings.timeToTakeMedication(daysStr),
            scheduledDate,
            details,
            androidScheduleMode: canScheduleExact
                ? AndroidScheduleMode.exactAllowWhileIdle
                : AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: 'medication:$id',
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
          AppLogger.info('Medication reminder scheduled (day $dayOfWeek): $medicationName at $scheduledDate (id=$dayNotificationId, exact=$canScheduleExact)');
        }
      }
    } catch (e) {
      AppLogger.error('Medication scheduling error for $medicationName', error: e);
    }
  }

  /// Calculate the next occurrence of a specific weekday at the given time.
  /// weekday: Monday=1, Sunday=7 (ISO standard)
  tz.TZDateTime _nextWeekday(tz.TZDateTime now, int weekday, int hour, int minute) {
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    final currentWeekday = now.weekday;
    var daysToAdd = weekday - currentWeekday;
    if (daysToAdd < 0) daysToAdd += 7;
    if (daysToAdd == 0 && scheduled.isBefore(now)) {
      daysToAdd = 7;
    }
    scheduled = scheduled.add(Duration(days: daysToAdd));
    return scheduled;
  }
  Future<void> cancelMedicationReminder(int id) async {
    if (kIsWeb) return;
    try {
      final notificationId = (id % 90000) + 10000;
      await _notifications.cancel(notificationId);
      // Also cancel per-day-of-week variants (id*10 + dayOfWeek)
      for (var dayOfWeek = 1; dayOfWeek <= 7; dayOfWeek++) {
        await _notifications.cancel(notificationId * 10 + dayOfWeek);
      }
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

      final androidDetails = AndroidNotificationDetails(
        'appointment_reminders',
        NotifStrings.appointmentReminders,
        channelDescription: NotifStrings.appointmentRemindersDesc,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        actions: [
          AndroidNotificationAction(
            'open',
            NotifStrings.open,
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

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        notificationId,
        NotifStrings.appointmentReminder,
        NotifStrings.appointmentBody(title, doctorName, reminderDays),
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

  /// Toont direct een voorbeeld van de ochtend-herinnering, inclusief de
  /// "gisteren nog niet ingevuld"-regel wanneer die van toepassing is.
  /// Alleen bedoeld om de melding te beoordelen — plant niets in.
  Future<void> showCheckinPreview() async {
    if (kIsWeb) return;
    final gisteren = DateTime.now().subtract(const Duration(days: 1));
    final status = await CheckinStatus.voor(CheckinStatus.dateKey(gisteren));

    await showImmediateNotification(
      title: NotifStrings.checkinTitle(
          ochtend: true, gisterenGemist: !status.ochtend),
      body: NotifStrings.checkinBody(
          ochtend: true, gisterenGemist: !status.ochtend),
      payload: 'checkin:ochtend',
    );
  }

  // ---------------------------------------------------------------------------
  // Check-in herinneringen (ochtend + avond)
  // ---------------------------------------------------------------------------

  /// Vaste ID's buiten het bereik dat medicatie (<10000 + id) en afspraken
  /// (id*100 % 100000, dus <100000) gebruiken, zodat er geen collisie is.
  static const int _ochtendNotifId = 900001;
  static const int _avondNotifId = 900002;

  static const String _ochtendKey = 'notif_ochtend_tijd';
  static const String _avondKey = 'notif_avond_tijd';
  static const String _ochtendAanKey = 'notif_ochtend_aan';
  static const String _avondAanKey = 'notif_avond_aan';

  /// Standaardtijden wanneer de gebruiker niets heeft ingesteld.
  static const String defaultOchtendTijd = '08:00';
  static const String defaultAvondTijd = '21:00';

  /// Wanneer gaat deze herinnering daadwerkelijk af?
  ///
  /// Nodig omdat het instellen van een tijd die vandaag al voorbij is niet
  /// "niets doet": de melding gaat dan naar morgen. Zonder deze terugkoppeling
  /// lijkt dat op een storing — de gebruiker kiest 19:30 om 19:34 en er
  /// gebeurt niets.
  ///
  /// Geeft (moment, isMorgen) terug.
  static ({DateTime moment, bool morgen}) volgendeMoment(String tijd) {
    final parts = tijd.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 8;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;

    final now = DateTime.now();
    var moment = DateTime(now.year, now.month, now.day, hour, minute);
    var morgen = false;
    if (!moment.isAfter(now)) {
      moment = moment.add(const Duration(days: 1));
      morgen = true;
    }
    return (moment: moment, morgen: morgen);
  }

  /// Leest de instellingen en plant beide check-in herinneringen opnieuw.
  ///
  /// Wordt aangeroepen bij app-start, na het opslaan van Instellingen, en door
  /// de periodieke WorkManager-taak (Android kan alarms laten vallen na een
  /// tijd in Doze).
  Future<void> rescheduleCheckinReminders() async {
    if (kIsWeb) return;
    try {
      // Ook hier: dit pad loopt in de WorkManager-isolate, waar de tijdzone
      // nog niet gezet is. Zonder deze regel rekent hij in UTC of gooit hij.
      await _ensureTimeZoneInitialized();
      final settings = await db.getSettings() ?? <String, dynamic>{};

      final ochtendAan = _asBool(settings[_ochtendAanKey], true);
      final avondAan = _asBool(settings[_avondAanKey], true);
      final ochtendTijd =
          settings[_ochtendKey]?.toString() ?? defaultOchtendTijd;
      final avondTijd = settings[_avondKey]?.toString() ?? defaultAvondTijd;

      if (ochtendAan) {
        await _scheduleCheckin(
          id: _ochtendNotifId,
          tijd: ochtendTijd,
          ochtend: true,
        );
      } else {
        await _notifications.cancel(_ochtendNotifId);
      }

      if (avondAan) {
        await _scheduleCheckin(
          id: _avondNotifId,
          tijd: avondTijd,
          ochtend: false,
        );
      } else {
        await _notifications.cancel(_avondNotifId);
      }

      AppLogger.info(
          'Check-in herinneringen gepland: ochtend=$ochtendAan@$ochtendTijd, avond=$avondAan@$avondTijd');
    } catch (e) {
      AppLogger.error('Check-in herinneringen plannen mislukt', error: e);
    }
  }

  static bool _asBool(dynamic v, bool fallback) {
    if (v == null) return fallback;
    final s = v.toString().toLowerCase();
    if (s == '1' || s == 'true') return true;
    if (s == '0' || s == 'false') return false;
    return fallback;
  }

  Future<void> _scheduleCheckin({
    required int id,
    required String tijd,
    required bool ochtend,
  }) async {
    final parts = tijd.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? (ochtend ? 8 : 21);
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;

    // Was de check-in van GISTEREN nog niet (volledig) ingevuld? Dan krijgt de
    // melding een extra waarschuwingsregel. Dit wordt bij ELKE herplanning
    // opnieuw bepaald, zodat WorkManager het oordeel ververst zonder dat er een
    // achtergrondtaak met eigen DB-toegang nodig is.
    final gisteren = DateTime.now().subtract(const Duration(days: 1));
    final status = await CheckinStatus.voor(CheckinStatus.dateKey(gisteren));
    final gisterenGemist = ochtend ? !status.ochtend : !status.avond;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final androidDetails = AndroidNotificationDetails(
      'checkin_reminders',
      NotifStrings.checkinReminders,
      channelDescription: NotifStrings.checkinRemindersDesc,
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

    // Zelfde aanpak als de medicatie-planning: vraag het native kanaal of
    // exacte alarms mogen, en zak anders terug naar inexact — een melding die
    // iets later komt is beter dan een die niet komt.
    final androidImpl =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final canScheduleExact =
        await androidImpl?.canScheduleExactNotifications() ?? false;

    await _notifications.cancel(id);
    await _notifications.zonedSchedule(
      id,
      NotifStrings.checkinTitle(ochtend: ochtend, gisterenGemist: gisterenGemist),
      NotifStrings.checkinBody(ochtend: ochtend, gisterenGemist: gisterenGemist),
      scheduled,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: ochtend ? 'checkin:ochtend' : 'checkin:avond',
    );

    AppLogger.info(
        'Check-in herinnering gepland: ${ochtend ? 'ochtend' : 'avond'} om $tijd '
        '(gisterenGemist=$gisterenGemist)');
  }

  void _onNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    final actionId = response.actionId;

    // Check-in herinnering: stuur de app naar het juiste scherm. De payload
    // wordt door de navigator opgepikt zodra de app weer vooraan staat.
    if (payload != null && payload.startsWith('checkin:')) {
      // Expliciete mapping in plaats van de routenaam uit de payload bouwen:
      // de payload zegt 'ochtend'/'avond' (NL, want dat is de stabiele
      // interne naam) maar de routes heten /morning-checkin en
      // /evening-checkin. Stringconcatenatie leverde hier een niet-bestaande
      // route op, waardoor tikken op de melding niets deed.
      final soort = payload.split(':').length > 1 ? payload.split(':')[1] : '';
      _pendingCheckinRoute = const {
        'ochtend': '/morning-checkin',
        'avond': '/evening-checkin',
      }[soort];
      AppLogger.debug('Check-in notificatie geopend: $_pendingCheckinRoute');
      return;
    }

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
            NotifStrings.medicationReminderShort,
            NotifStrings.timeToTakeMedicationSnoozed(),
            tz.TZDateTime.now(tz.local).add(const Duration(minutes: 15)),
            NotificationDetails(
              android: AndroidNotificationDetails(
                'medication_reminders',
                NotifStrings.medicationReminders,
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
