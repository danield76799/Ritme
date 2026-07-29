import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

// Services
import 'services/boot_service.dart';
import 'services/notification_helper.dart';
import 'services/widget_service.dart';
import 'services/work_manager_service.dart';

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
import 'services/theme_service.dart';

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

    // Vraag expliciet permissies en herplan pas daarna.
    // Zonder SCHEDULE_EXACT_ALARM gaan medicatieherinneringen niet af op tijd.
    final permissionsOk = await NotificationHelper.instance.ensurePermissions();
    // Vraag battery optimization uitzetting — kritiek voor achtergrondnotificaties
    await NotificationHelper.instance.openBatteryOptimizationSettings();
    // Plan ALTIJD herinneringen, ook als exact alarm niet gegeven is (fallback naar inexact)
    final rescheduled = await NotificationHelper.instance.rescheduleAllMedicationReminders();
    AppLogger.info('Startup reschedule completed: $rescheduled medication reminders scheduled (exactAlarm=$permissionsOk)');

    // Verzeker dat medicatieherinneringen hersteld zijn na een reboot of als Android
    // ze heeft weggehaald door batterijoptimalisatie. Zonder deze check blijven ze
    // stil als er geen pending notificaties meer zijn.
    final recovered = await BootService.rescheduleIfEmpty();
    if (recovered > 0) {
      AppLogger.info('Recovered $recovered reminders after empty pending queue');
    }

    await WidgetService.initialize();

    // WorkManager periodic task: reschedules medication reminders every 12
    // hours in the background, surviving Android Doze mode. This prevents
    // reminders from going silent after a few days of inactivity.
    await WorkManagerService.initialize();
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
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
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

class RitmeApp extends StatefulWidget {
  const RitmeApp({super.key});

  /// Globale toegang tot de actieve app-state zodat schermen de thema-modus
  /// kunnen wijzigen (bijv. vanuit Instellingen).
  static _RitmeAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_RitmeAppState>();

  @override
  State<RitmeApp> createState() => _RitmeAppState();
}

class _RitmeAppState extends State<RitmeApp> {
  ThemeMode themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final mode = await ThemeService.instance.getThemeMode();
    if (mounted) setState(() => themeMode = mode);
  }

  void setThemeMode(ThemeMode mode) {
    setState(() => themeMode = mode);
    ThemeService.instance.setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ritme - SRT Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
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
