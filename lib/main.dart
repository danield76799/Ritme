import 'package:flutter/material.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/mood_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/medication_screen.dart';
import 'screens/event_screen.dart';
import 'screens/statistics_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();
  runApp(const RitmeApp());
}

class RitmeApp extends StatelessWidget {
  const RitmeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ritme - SRT Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4FB2C1),
          primary: const Color(0xFF4FB2C1),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
      routes: {
        '/mood': (context) => const MoodScreen(),
        '/activity': (context) => const ActivityScreen(),
        '/medication': (context) => const MedicationScreen(),
        '/event': (context) => const EventScreen(),
        '/statistics': (context) => const StatisticsScreen(),
      },
    );
  }
}
