import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'pages/splash_screen.dart';
import 'screens/login_screen.dart';
import 'services/notification_helper.dart';
import 'screens/mood_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/medication_screen.dart';
import 'screens/event_screen.dart';
import 'screens/statistics_screen.dart' show StatistiekenScherm;
import 'screens/insights_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/medication_schedule_screen.dart';
import 'screens/weight_screen.dart';
import 'screens/appointments_screen.dart';
import 'service_locator.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the appropriate database
  await initDatabase();
  
  // Initialize notifications for mobile only
  if (!kIsWeb) {
    try {
      await NotificationHelper.instance.initialize();
    } catch (e) {
      debugPrint('Notification initialization error: $e');
    }
  }
  
  runApp(const RitmeApp());
}

class RitmeApp extends StatelessWidget {
  const RitmeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ritme - SRT Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      routes: {
        '/mood': (context) => const MoodScreen(),
        '/activity': (context) => const ActivityScreen(),
        '/medication': (context) => const MedicationScreen(),
        '/event': (context) => GebeurtenisScherm(),
        '/settings': (context) => InstellingenScherm(),
        '/medication-schedule': (context) => const MedicationScheduleScreen(),
        '/weight': (context) => const WeightScreen(),
        '/appointments': (context) => const AppointmentsScreen(),
        '/insights': (context) => const InsightsScreen(),
        '/statistics': (context) => StatistiekenScherm(),
      },
    );
  }
}
