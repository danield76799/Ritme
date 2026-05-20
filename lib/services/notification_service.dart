import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone data
    tz_data.initializeTimeZones();

    // Android settings
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap - could navigate to medication screen
    print('Notification tapped: ${response.payload}');
  }

  Future<bool> requestPermissions() async {
    // Android 13+ needs notification permission
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      final bool? granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }

    // iOS
    final bool? iosGranted = await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    return iosGranted ?? false;
  }

  Future<void> scheduleMedicationReminder({
    required int medicationId,
    required String medicationName,
    required String dosage,
    required String time,
    required List<int> daysOfWeek,
  }) async {
    // Parse time string (HH:MM)
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    // Cancel existing notifications for this medication
    await cancelMedicationReminder(medicationId);

    // Schedule for each day of the week
    for (final day in daysOfWeek) {
      final notificationId = medicationId * 10 + day;
      
      await _notifications.zonedSchedule(
        notificationId,
        'Medicatie herinnering',
        'Neem $medicationName ($dosage)',
        _nextInstanceOfTime(hour, minute, day),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Medicatie herinneringen',
            channelDescription: 'Herinneringen voor medicatie inname',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            playSound: true,
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
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            categoryIdentifier: 'medication',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'medication:$medicationId',
      );
    }
  }

  Future<void> cancelMedicationReminder(int medicationId) async {
    // Cancel all notifications for this medication (up to 7 days)
    for (int day = 1; day <= 7; day++) {
      await _notifications.cancel(medicationId * 10 + day);
    }
  }

  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute, int dayOfWeek) {
    final now = tz.TZDateTime.now(tz.local);
    
    // Flutter weekday: 1=Monday, 7=Sunday
    // But we want to schedule for specific days
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Find next occurrence of this day
    while (scheduledDate.weekday != dayOfWeek || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  Future<void> showImmediateNotification({
    required String title,
    required String body,
  }) async {
    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'general',
          'Algemeen',
          channelDescription: 'Algemene notificaties',
          importance: Importance.low,
          priority: Priority.low,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
