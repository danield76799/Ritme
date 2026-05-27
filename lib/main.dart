import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'pages/splash_screen.dart' show SplashScreenWrapper;
import 'screens/login_screen.dart';
import 'services/notification_helper.dart';
import 'services/sunup_service.dart';
import 'screens/mood_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/medication_screen.dart';
import 'screens/event_screen.dart';
import 'screens/statistics_screen.dart' show StatistiekenScherm;
import 'screens/insights_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/medication_schedule_screen.dart';
import 'screens/weight_screen.dart';
import 'screens/sociaal_ritme_meter_screen.dart';
import 'screens/appointments_screen.dart';
import 'screens/sleep_detail_screen.dart';
import 'screens/rhythm_detail_screen.dart';
import 'screens/life_events_screen.dart';
import 'screens/activities_detail_screen.dart';
import 'screens/database_debug_screen.dart';
import 'screens/help_screen.dart';
import 'screens/voortekenen_screen.dart';
import 'screens/crisisplan_screen.dart';
import 'screens/episodes_screen.dart';
import 'screens/rapport_screen.dart';
import 'service_locator.dart';
import 'theme/app_theme.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize date formatting for Dutch locale
  await initializeDateFormatting('nl_NL', null);
  
  // Initialize the appropriate database
  await initDatabase();
  
  // Initialize notifications for mobile only
  if (!kIsWeb) {
    // Initialize notifications (SunUP primary, local fallback)
    try {
      await SunUpService.instance.initialize();
      debugPrint('SunUP mode: ${SunUpService.instance.mode}');
    } catch (e) {
      debugPrint('SunUP init error: $e');
      // Fallback to pure local
      await NotificationHelper.instance.initialize();
    }
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
  
  // Set up notification action handler
  if (!kIsWeb) {
    await _setupNotificationActionHandler();
  }
  
  runApp(
    ErrorBoundary(
      child: const RitmeApp(),
    ),
  );
}

Future<void> _setupNotificationActionHandler() async {
  try {
    final notifications = FlutterLocalNotificationsPlugin();
    
    // Handle notification actions
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
            
            if (actionId == 'taken') {
              // Mark medication as taken
              await db.insertMedicationIntakeMap({
                'medication_id': medicationId,
                'date': today,
                'aantal_ingenomen': 1,
              });
              AppLogger.debug('Medication $medicationId marked as taken');
            } else if (actionId == 'skip') {
              // Mark medication as skipped (0 intake)
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
      themeMode: ThemeMode.system,
      home: const SplashScreenWrapper(),
      routes: {
        '/mood': (context) => const MoodScreen(),
        '/activity': (context) => const ActivityScreen(),
        '/medication': (context) => const MedicationScreen(),
        '/event': (context) => const EventScreen(),
        '/database-debug': (context) => const DatabaseDebugScreen(),
        '/database-debug': (context) => const DatabaseDebugScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/medication-schedule': (context) => const MedicationScheduleScreen(),
        '/weight': (context) => const WeightScreen(),
        '/sociaal-ritme': (context) => const SociaalRitmeMeterScreen(),
        '/appointments': (context) => const AppointmentsScreen(),
        '/insights': (context) => const InsightsScreen(),
        '/statistics': (context) => StatistiekenScherm(),
        '/sleep-detail': (context) => const SleepDetailScreen(),
        '/rhythm-detail': (context) => const RhythmDetailScreen(),
        '/activities-detail': (context) => const ActivitiesDetailScreen(),
        '/life-events': (context) => const LifeEventsScreen(),
        '/help': (context) => const HelpScreen(),
        '/voortekenen': (context) => const VoortekenenScreen(),
        '/crisisplan': (context) => const CrisisPlanScreen(),
        '/episodes': (context) => const EpisodesScreen(),
        '/rapport': (context) => const RapportScreen(),
      },
    );
  }
}
