import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'pages/splash_screen.dart';
import 'screens/login_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/notification_helper.dart';
import '../screens/login_screen.dart';
import '../screens/mood_screen.dart';
import '../screens/activity_screen.dart';
import '../screens/medication_screen.dart';
import '../screens/event_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/settings_screen.dart';
import 'database/database_repository.dart';
import 'database/database_helper.dart';
import 'database/hive_database_helper.dart';

// Service locator - selects the right database based on platform
late DatabaseRepository db;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the appropriate database
  if (kIsWeb) {
    // Use Hive for web
    await Hive.initFlutter();
    await HiveDatabaseHelper.init();
    db = HiveDatabaseHelper.instance;
  } else {
    // Use SQLite for mobile
    db = DatabaseHelper.instance;
    
    // Initialize notifications for mobile
    await NotificationHelper.instance.initialize();
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4FB2C1),
          primary: const Color(0xFF4FB2C1),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
      routes: {
        '/mood': (context) => const MoodScreen(),
        '/activity': (context) => const ActivityScreen(),
        '/medication': (context) => const MedicationScreen(),
        '/event': (context) => GebeurtenisScherm(),
        '/settings': (context) => InstellingenScherm(),
      },
    );
  }
}
