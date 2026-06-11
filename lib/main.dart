import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

// Services
import 'services/boot_service.dart';
import 'services/notification_helper.dart';
import 'services/widget_service.dart';

// Screens
import 'screens/activities_detail_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/appointments_screen.dart';
import 'screens/crisisplan_screen.dart';
import 'screens/database_debug_screen.dart';
import 'screens/episodes_screen.dart';
import 'screens/event_screen.dart';
import 'screens/help_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/life_events_screen.dart';
import 'screens/medication_schedule_screen.dart';
import 'screens/medication_screen.dart';
import 'screens/mood_screen.dart';
import 'screens/quick_checkin_screen.dart';
import 'screens/rapport_screen.dart';
import 'screens/rhythm_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sleep_detail_screen.dart';
import 'screens/sociaal_ritme_meter_screen.dart';
import 'screens/statistics_screen.dart' show StatistiekenScherm;
import 'screens/voortekenen_screen.dart';
import 'screens/weight_screen.dart';

// Pages & Utils
import 'pages/splash_screen.dart' show SplashScreenWrapper;
import 'service_locator.dart';
import 'theme/app_theme.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting for Dutch locale
  await initializeDateFormatting('nl_NL', null);

  // Initialize the appropriate database
  await initDatabase();

  // Initialize notifications (local only, no external push)
  if (!kIsWeb) {
    await NotificationHelper.instance.initialize();
    await BootService.initialize();
    await WidgetService.initialize();
    await _setupNotificationActionHandler();
  }

  // Set up error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error(
      'Flutter error',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  runApp(
    ErrorBoundary(
      child: const RitmeApp(),
    ),
  );
}

Future<void> _setupNotificationActionHandler() async {
  try {
    final notifications = FlutterLocalNotificationsPlugin();

    notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
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
            }
          }
        }
      },
    );
  } catch (e) {
    AppLogger.error('Failed to setup notification action handler', error: e);
  }
}

class ErrorBoundary extends StatefulWidget {
  final Widget child;

  const ErrorBoundary({super.key, required this.child});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  FlutterErrorDetails? _error;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Er is iets misgegaan',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!.exception.toString(),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                    });
                  },
                  child: const Text('Opnieuw proberen'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}

class RitmeApp extends StatelessWidget {
  const RitmeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ritme - SRT Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: SplashScreenWrapper(),
      routes: {
        '/mood': (context) => MoodScreen(),
        '/activity': (context) => ActivityScreen(),
        '/medication': (context) => MedicationScreen(),
        '/event': (context) => EventScreen(),
        '/database-debug': (context) => DatabaseDebugScreen(),
        '/settings': (context) => SettingsScreen(),
        '/medication-schedule': (context) => MedicationScheduleScreen(),
        '/weight': (context) => WeightScreen(),
        '/sociaal-ritme': (context) => SociaalRitmeMeterScreen(),
        '/appointments': (context) => AppointmentsScreen(),
        '/insights': (context) => InsightsScreen(),
        '/statistics': (context) => StatistiekenScherm(),
        '/sleep-detail': (context) => SleepDetailScreen(),
        '/rhythm-detail': (context) => RhythmDetailScreen(),
        '/activities-detail': (context) => ActivitiesDetailScreen(),
        '/life-events': (context) => LifeEventsScreen(),
        '/help': (context) => HelpScreen(),
        '/voortekenen': (context) => VoortekenenScreen(),
        '/crisisplan': (context) => CrisisPlanScreen(),
        '/episodes': (context) => EpisodesScreen(),
        '/rapport': (context) => RapportScreen(),
        '/quick-checkin': (context) => QuickCheckInScreen(),
      },
    );
  }
}
