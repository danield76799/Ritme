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
      debugPrint('Dagelijkse herinnering gepland voor: $scheduledDate');
    } catch (e) {
      debugPrint('Herinnering planning error: $e');
    }
  }

  Future<void> showTestNotification() async {
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test notificaties',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1,
      'Test notificatie',
      'Ritme notificaties werken!',
      details,
    );
  }
}
