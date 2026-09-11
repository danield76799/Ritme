import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../service_locator.dart';
import '../services/notification_helper.dart';
import '../services/bipolar_alert_service.dart';
import '../utils/logger.dart';
import '../widgets/weekly_mood_chart.dart';
import 'login_screen.dart';
import 'mood_assessment_screen.dart';
import 'morning_checkin_screen.dart';
import 'evening_checkin_screen.dart';
import 'dagboek_screen.dart';
import 'activity_screen.dart';
import 'medication_screen.dart';
import 'weight_screen.dart';
import 'appointments_screen.dart';
import 'voortekenen_screen.dart';
import 'crisisplan_screen.dart';
import 'rapport_screen.dart';
import '../generated/l10n/app_localizations.dart';

enum AlertSeverity { high, medium }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _settings;
  bool _isLoading = true;
  double _sleepQuality = 0.0;
  double _rhythmStability = 0.0;
  int _weeklyActivities = 0;
  int _loggedDaysCount = 0;
  DateTime? _lastUpdated;
  List<Map<String, dynamic>> _weeklyLogs = [];
  List<Map<String, dynamic>> _dailyLogs = [];
  Set<String> _checkinTypes = {};
  List<Map<String, dynamic>> _srmActivitiesList = [];
  List<Alert> _alerts = [];

  int _dagStreak = 0;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _setupNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final startDateStr = '${weekAgo.year}-${weekAgo.month.toString().padLeft(2, '0')}-${weekAgo.day.toString().padLeft(2, '0')}';
      final endDateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final results = await Future.wait([
        db.getSettings(),
        db.getDailyLogsRange(startDateStr, endDateStr),
        db.getSrmActivitiesRange(startDateStr, endDateStr),
      ]);

      final settings = results[0] as Map<String, dynamic>?;
      final dailyLogs = results[1] as List<Map<String, dynamic>>;
      final weeklyActivities = results[2] as List<Map<String, dynamic>>;

      final todayStr = endDateStr;
      final todayLog = dailyLogs.where((l) => l['date'] == todayStr).firstOrNull;
      final todayActs = weeklyActivities.where((a) => a['date'] == todayStr).toList();

      final checkinTypesToday = <String>{};
      if (todayLog != null) {
        final s = todayLog['uren_slaap'];
        final sNum = s is num ? s.toDouble() : double.tryParse(s?.toString() ?? '');
        final a = todayLog['awake_minutes'];
        final aNum = a is num ? a.toInt() : int.tryParse(a?.toString() ?? '') ?? 0;
        final q = todayLog['q4_slaapbehoefte'];
        if ((sNum != null && sNum > 0) || (aNum > 0) || q != null) {
          checkinTypesToday.add('ochtend');
        }
      }
      try {
        final intake = await db.getMedicationIntake(todayStr);
        final hasMed = intake.any((row) {
          final raw = row['aantal_ingenomen'];
          final n = raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
          return n > 0;
        });
        if (hasMed) checkinTypesToday.add('medicatie');
      } catch (_) {}
      try {
        final dagboek = await db.getDagboek(todayStr);
        if (dagboek != null) checkinTypesToday.add('dagboek');
      } catch (_) {}
      final avondTypes = {'Eerste contact', 'Werk / Hobby', 'Avondeten', 'Naar bed'};
      final hasAvond = todayActs.any((a) {
        final type = a['activity_type']?.toString() ?? '';
        return avondTypes.contains(type);
      });
      if (hasAvond) checkinTypesToday.add('avond');

      // Dagstreak — tellen vanaf vandaag achterwaarts; een dag telt als er minimaal 1 check-in type is (ochtend/avond/medicatie)
      int streak = 0;
      for (int i = 0; i < 365; i++) {
        final d = now.subtract(Duration(days: i));
        final ds = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        final dayTypes = <String>{};
        
        // Ochtend: slaap gelogd?
        final dayLog = dailyLogs.where((l) => l['date'] == ds).firstOrNull;
        if (dayLog != null) {
          final s = dayLog['uren_slaap'];
          final sNum = s is num ? s.toDouble() : double.tryParse(s?.toString() ?? '');
          final a = dayLog['awake_minutes'];
          final aNum = a is num ? a.toInt() : int.tryParse(a?.toString() ?? '') ?? 0;
          final q = dayLog['q4_slaapbehoefte'];
          if ((sNum != null && sNum > 0) || (aNum > 0) || q != null) {
            dayTypes.add('ochtend');
          }
        }
        
        // Medicatie: ingenomen?
        try {
          final intake = await db.getMedicationIntake(ds);
          final hasMed = intake.any((row) {
            final raw = row['aantal_ingenomen'];
            final n = raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
            return n > 0;
          });
          if (hasMed) dayTypes.add('medicatie');
        } catch (_) {}
        
        // Avond: SRM activiteiten met avond-types?
        final dayActs = weeklyActivities.where((a) => a['date'] == ds).toList();
        final avondTypes = {'Eerste contact', 'Werk / Hobby', 'Avondeten', 'Naar bed'};
        if (dayActs.any((a) => avondTypes.contains(a['activity_type']?.toString() ?? ''))) {
          dayTypes.add('avond');
        }
        
        if (dayTypes.isNotEmpty) {
          streak++;
        } else {
          break;
        }
      }

      double totalSleep = 0;
      int sleepCount = 0;
      int loggedDaysCount = 0;
      final sleepPerDay = <String, double>{};

      for (final log in dailyLogs) {
        final dateStr = log['date']?.toString();
        if (dateStr == null) continue;

        final rawSleep = log['sleep_hours'];
        final rawUren = log['uren_slaap'];
        double? sleep;
        if (rawSleep != null) {
          sleep = rawSleep is num ? rawSleep.toDouble() : double.tryParse(rawSleep.toString());
        }
        if (sleep == null || sleep <= 0) {
          sleep = rawUren is num ? rawUren.toDouble() : double.tryParse(rawUren?.toString() ?? '');
        }
        if (sleep != null && sleep > 0 && !sleepPerDay.containsKey(dateStr)) {
          sleepPerDay[dateStr] = sleep;
          loggedDaysCount++;
          totalSleep += sleep;
          sleepCount++;
        }
      }
      final avgSleep = sleepCount > 0 ? totalSleep / sleepCount : 0.0;

      double totalPScore = 0;
      int totalActivities = 0;
      for (final activity in weeklyActivities) {
        final actualTime = activity['actual_time'];
        final rawPScore = activity['p_score'];
        if (actualTime != null && rawPScore != null) {
          final int pScore = rawPScore is int ? rawPScore : int.tryParse(rawPScore.toString()) ?? 0;
          if (pScore > 0) {
            totalPScore += pScore;
            totalActivities++;
          }
        }
      }
      final stability = totalActivities > 0 ? (totalPScore / totalActivities / 5 * 100) : 0.0;

      if (mounted) {
        setState(() {
          _settings = settings;
          _sleepQuality = avgSleep;
          _rhythmStability = stability;
          _weeklyActivities = weeklyActivities.length;
          _loggedDaysCount = loggedDaysCount;
          _dailyLogs = dailyLogs;
          _srmActivitiesList = weeklyActivities;
          _weeklyLogs = dailyLogs;
          _checkinTypes = checkinTypesToday;
          _dagStreak = streak;
          _lastUpdated = DateTime.now();
          _isLoading = false;
        });
      }

      BipolarAlertService.instance.runAllChecks().then((alerts) {
        if (mounted) setState(() => _alerts = alerts);
      });
    } catch (e) {
      AppLogger.error('Dashboard _loadData error', error: e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setupNotifications() async {
    if (!kIsWeb) {
      await NotificationHelper.instance.initialize();
    }
  }

  Future<void> _logout() async {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _getGreeting(String name) {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'Goedenacht, $name';
    if (hour < 12) return 'Goedemorgen, $name';
    if (hour < 18) return 'Goedemiddag, $name';
    return 'Goedenavond, $name';
  }

  String _formatLastUpdated(BuildContext context) {
    if (_lastUpdated == null) return '';
    final l10n = AppLocalizations.of(context);
    final diff = DateTime.now().difference(_lastUpdated!);
    if (diff.inSeconds < 60) return l10n.zojuistBijgewerkt;
    if (diff.inMinutes < 60) return l10n.minutenGeleden(diff.inMinutes);
    if (diff.inHours < 24) return l10n.urenGeleden(diff.inHours);
    return l10n.dagenGeleden(diff.inDays);
  }

  String _formatHours(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h > 0 && m > 0) return '${h}u ${m}m';
    if (h > 0) return '${h}u';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final today = DateTime.now();
    final dateStr = DateFormat('EEEE d MMMM', 'nl').format(today);
    final username = _settings?['username']?.toString() ?? 'gebruiker';
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        title: Text(
          'Ritme',
          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.health_and_safety, color: AppTheme.error),
            onPressed: () => Navigator.pushNamed(context, '/crisisplan'),
            tooltip: AppLocalizations.of(context).crisisplan,
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () async {
              await Navigator.pushNamed(context, '/settings');
              _loadData();
            },
            tooltip: AppLocalizations.of(context).instellingen,
          ),
          PopupMenuButton<int>(
            icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface),
            tooltip: AppLocalizations.of(context).meer,
            onSelected: (value) async {
              switch (value) {
                case 0: Navigator.pushNamed(context, '/statistics'); break;
                case 2: Navigator.pushNamed(context, '/weight'); break;
                case 3: Navigator.pushNamed(context, '/appointments'); break;
                case 4: Navigator.pushNamed(context, '/voortekenen'); break;
                case 5: Navigator.pushNamed(context, '/rapport'); break;
                case 6: Navigator.pushNamed(context, '/help'); break;
                case 7: _logout(); break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 0, child: ListTile(leading: Icon(Icons.bar_chart), title: Text(AppLocalizations.of(context).statistieken), contentPadding: EdgeInsets.zero, dense: true)),
              const PopupMenuDivider(),
              PopupMenuItem(value: 2, child: ListTile(leading: Icon(Icons.monitor_weight), title: Text(AppLocalizations.of(context).gewicht), contentPadding: EdgeInsets.zero, dense: true)),
              PopupMenuItem(value: 3, child: ListTile(leading: Icon(Icons.calendar_today), title: Text(AppLocalizations.of(context).afspraken), contentPadding: EdgeInsets.zero, dense: true)),
              PopupMenuItem(value: 4, child: ListTile(leading: Icon(Icons.warning_amber), title: Text(AppLocalizations.of(context).voortekenen), contentPadding: EdgeInsets.zero, dense: true)),
              PopupMenuItem(value: 5, child: ListTile(leading: Icon(Icons.description), title: Text(AppLocalizations.of(context).rapport), contentPadding: EdgeInsets.zero, dense: true)),
              PopupMenuItem(value: 6, child: ListTile(leading: Icon(Icons.help_outline), title: Text(AppLocalizations.of(context).gebruiksaanwijzing), contentPadding: EdgeInsets.zero, dense: true)),
              const PopupMenuDivider(),
              PopupMenuItem(value: 7, child: ListTile(leading: Icon(Icons.logout, color: AppTheme.error), title: Text(AppLocalizations.of(context).uitloggen, style: TextStyle(color: AppTheme.error)), contentPadding: EdgeInsets.zero, dense: true)),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting card - compacter
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? LinearGradient(
                          colors: [Color(0xFF2A3D42), Color(0xFF1A2B30)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(AppTheme.largeRadius),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? Colors.black : const Color(0xFFB4A8D4)).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _getGreeting(username),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _buildTimeChip(Icons.wb_sunny_outlined, AppLocalizations.of(context).opstaan, _settings?['target_opstaan'] ?? '08:00', isDark),
                        const SizedBox(width: 8),
                        _buildTimeChip(Icons.bedtime, AppLocalizations.of(context).slapen, _settings?['target_slapen'] ?? '23:00', isDark),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Alerts
              if (_alerts.isNotEmpty) ...[
                ..._alerts.map((alert) => _buildAlertCard(alert, theme)),
                const SizedBox(height: 16),
              ],

              // Datum-picker + dagstatus-metertje + streak-chip
              Row(children: [
                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: Row(children: [
                    Text(
                      _formatSelectedDate(context),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.calendar_today, size: 18, color: Theme.of(context).colorScheme.primary),
                  ]),
                ),
                const Spacer(),
                _DagStatusMeter(
                  gelogd: _checkinTypes.length,
                  totaal: 4,
                ),
              ]),
              if (_dagStreak > 0) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildStreakChip(),
                ),
              ],

              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.35,
                children: [
                  _buildCheckinCard(context, icon: Icons.wb_sunny, color: const Color(0xFFF2C879), title: AppLocalizations.of(context).ochtendCheckIn, route: '/morning-checkin', date: _selectedDate, isOchtend: true),
                  _buildCheckinCard(context, icon: Icons.nights_stay, color: const Color(0xFF8A7FBF), title: AppLocalizations.of(context).avondCheckIn, route: '/evening-checkin', date: _selectedDate, isOchtend: false),
                  _buildActionCard(context, icon: Icons.medication, color: const Color(0xFFB4A8D4), title: AppLocalizations.of(context).medicatie, route: '/medication', done: _checkinTypes.contains('medicatie')),
                  _buildActionCard(context, icon: Icons.menu_book, color: const Color(0xFF7FB89C), title: AppLocalizations.of(context).dagboek, route: '/dagboek', done: _checkinTypes.contains('dagboek')),
                  _buildActionCard(context, icon: Icons.description, color: const Color(0xFF8FB8C9), title: AppLocalizations.of(context).rapport, route: '/rapport', done: false, isAction: true),
                  _buildActionCard(context, icon: Icons.calendar_today, color: const Color(0xFFD4A8B4), title: AppLocalizations.of(context).afspraken, route: '/appointments', done: false, isAction: true),
                ],
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Text(AppLocalizations.of(context).overzicht, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_lastUpdated != null)
                    Text(_formatLastUpdated(context), style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
                ],
              ),
              const SizedBox(height: 12),

              _buildMetricCard(
                context,
                icon: Icons.bedtime,
                title: AppLocalizations.of(context).slaapduurLabel,
                value: _sleepQuality > 0 ? _formatHours(_sleepQuality) : null,
                emptyValue: AppLocalizations.of(context).nogNietGelogdVandaag,
                subtitle: null,
                emptyHint: AppLocalizations.of(context).slaapVerbeterStemming,
                color: const Color(0xFF88B0C7),
                route: '/sleep-detail',
                isEmpty: _sleepQuality <= 0,
              ),
              const SizedBox(height: 10),
              // SRT-score + Activiteiten naast elkaar
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      icon: Icons.schedule,
                      title: AppLocalizations.of(context).srtScore,
                      value: _rhythmStability > 0 ? '${_rhythmStability.round()}%' : null,
                      emptyValue: AppLocalizations.of(context).logVandaagOmTeZien,
                      subtitle: _rhythmStability > 0 ? _getSrtLabel(_rhythmStability, context) : null,
                      emptyHint: AppLocalizations.of(context).srtTooltip,
                      color: _getSrtColor(_rhythmStability),
                      route: '/rhythm-detail',
                      isEmpty: _rhythmStability <= 0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActivityMetricCard(
                      context,
                      icon: Icons.local_activity,
                      title: AppLocalizations.of(context).activiteitenDezeWeekLabel,
                      value: _weeklyActivities,
                      color: AppTheme.warning,
                      route: '/activities-detail',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Row(children: [
                Text(AppLocalizations.of(context).stemmingTrend, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),

              Container(
                height: 200,
                decoration: AppTheme.cardDecoration(context),
                clipBehavior: Clip.antiAlias,
                child: WeeklyMoodChart(logs: _weeklyLogs),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(
            _dagStreak == 1
                ? AppLocalizations.of(context).streakEenDag
                : AppLocalizations.of(context).streakMeerdereDagen(_dagStreak),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
      locale: Localizations.localeOf(context).languageCode == 'nl'
          ? const Locale('nl', 'NL')
          : null,
      helpText: 'Kies datum',
      cancelText: 'Annuleren',
      confirmText: 'Bekijken',
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _loadDataForDate(picked);
    }
  }

  Future<void> _loadDataForDate(DateTime date) async {
    try {
      final ds = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final startDateStr = '${weekAgo.year}-${weekAgo.month.toString().padLeft(2, '0')}-${weekAgo.day.toString().padLeft(2, '0')}';
      final endDateStr = ds;
      final results = await Future.wait([
        db.getSettings(),
        db.getDailyLogsRange(startDateStr, endDateStr),
        db.getSrmActivitiesRange(startDateStr, endDateStr),
      ]);
      if (!mounted) return;
      final settings = results[0] as Map<String, dynamic>?;
      final dailyLogs = results[1] as List<Map<String, dynamic>>;
      final weeklyActivities = results[2] as List<Map<String, dynamic>>;
      final selectedDs = ds;
      final todayLogForDate = dailyLogs.where((l) => l['date'] == selectedDs).firstOrNull;
      final todayActsForDate = weeklyActivities.where((a) => a['date'] == selectedDs).toList();
      final checkinTypesForDate = <String>{};
      if (todayLogForDate != null) {
        final s = todayLogForDate['uren_slaap'];
        final sNum = s is num ? s.toDouble() : double.tryParse(s?.toString() ?? '');
        final a = todayLogForDate['awake_minutes'];
        final aNum = a is num ? a.toInt() : int.tryParse(a?.toString() ?? '') ?? 0;
        final q = todayLogForDate['q4_slaapbehoefte'];
        if ((sNum != null && sNum > 0) || (aNum > 0) || q != null) {
          checkinTypesForDate.add('ochtend');
        }
      }
      try {
        final intake = await db.getMedicationIntake(selectedDs);
        final hasMed = intake.any((row) {
          final raw = row['aantal_ingenomen'];
          final n = raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
          return n > 0;
        });
        if (hasMed) checkinTypesForDate.add('medicatie');
      } catch (_) {}
      try {
        final dagboek = await db.getDagboek(selectedDs);
        if (dagboek != null) checkinTypesForDate.add('dagboek');
      } catch (_) {}
      final avondTypes = {'Eerste contact', 'Werk / Hobby', 'Avondeten', 'Naar bed'};
      final hasAvond = todayActsForDate.any((a) {
        final type = a['activity_type']?.toString() ?? '';
        return avondTypes.contains(type);
      });
      if (hasAvond) checkinTypesForDate.add('avond');
      setState(() {
        _settings = settings;
        _dailyLogs = dailyLogs;
        _srmActivitiesList = weeklyActivities;
        _weeklyActivities = weeklyActivities.length;
        _checkinTypes = checkinTypesForDate;
      });
    } catch (_) {}
  }

  String _formatSelectedDate(BuildContext context) {
    final now = DateTime.now();
    final diff = _selectedDate.difference(now).inDays;
    final locale = Localizations.localeOf(context).languageCode;
    if (diff == 0) return locale == 'nl' ? 'Vandaag' : 'Today';
    if (diff == -1) return locale == 'nl' ? 'Gisteren' : 'Yesterday';
    if (diff == -2) return locale == 'nl' ? 'Eergisteren' : 'Day before yesterday';
    if (diff > 0) return locale == 'nl' ? 'Overmorgen' : 'Tomorrow';
    final fmt = DateFormat('d MMMM', locale);
    return fmt.format(_selectedDate);
  }

  Widget _buildCheckinCard(BuildContext context,
      {required IconData icon, required Color color, required String title,
       required String route, DateTime? date, bool isOchtend = false}) {
    final ds = '${date!.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    bool hasLog;
    if (isOchtend) {
      hasLog = _dailyLogs.any((l) {
        if (l['date'] != ds) return false;
        final s = l['uren_slaap'];
        final sNum = s is num ? s.toDouble() : double.tryParse(s?.toString() ?? '');
        final a = l['awake_minutes'];
        final aNum = a is num ? a.toInt() : int.tryParse(a?.toString() ?? '') ?? 0;
        final q = l['q4_slaapbehoefte'];
        return (sNum != null && sNum > 0) || (aNum > 0) || q != null;
      });
    } else {
      final avondTypes = {'Eerste contact', 'Werk / Hobby', 'Avondeten', 'Naar bed'};
      hasLog = _srmActivitiesList.any((a) {
        if (a['date'] != ds) return false;
        final type = a['activity_type']?.toString() ?? '';
        return avondTypes.contains(type);
      });
    }
    return _buildActionCard(context,
        icon: icon, color: color, title: title, route: route, done: hasLog);
  }

  Widget _buildTimeChip(IconData icon, String label, String time, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 18),
          SizedBox(width: 8),
          Text(AppLocalizations.of(context).labelEnTijd(label, time), style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context,
      {required IconData icon, required Color color, required String title, required String route, bool done = false, bool isAction = false, DateTime? date}) {
    return OpenContainer<bool>(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: Duration(milliseconds: 400),
      closedElevation: 2,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
      closedColor: Theme.of(context).cardColor,
      openColor: Theme.of(context).scaffoldBackgroundColor,
      onClosed: (_) {
        _loadData();
        if (_selectedDate.difference(DateTime.now()).inDays != 0) {
          _loadDataForDate(_selectedDate);
        }
      },
      closedBuilder: (context, openContainer) {
        return InkWell(
          onTap: () => openContainer(),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  if (done)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                      ),
                    )
                  else if (isAction)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_forward, color: color, size: 18),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), textAlign: TextAlign.center),
            ],
          ),
        );
      },
      openBuilder: (context, closeContainer) {
        return _routeBuilder(route, closeContainer: closeContainer);
      },
    );
  }

  Widget _buildMetricCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String? value,
      String? emptyValue,
      String? subtitle,
      String? emptyHint,
      required Color color,
      required String route,
      bool isEmpty = false}) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 4),
                    if (isEmpty && emptyHint != null)
                      Text(emptyHint, style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)))
                    else if (subtitle != null)
                      Text(subtitle, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85))),
                    if (value != null)
                      Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: value.length > 12 ? 14 : 18))
                    else if (emptyValue != null)
                      Text(emptyValue, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityMetricCard(BuildContext context,
      {required IconData icon,
      required String title,
      required int value,
      required Color color,
      required String route}) {
    final theme = Theme.of(context);
    final isEmpty = value <= 0;
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 6),
                    if (isEmpty)
                      Text(AppLocalizations.of(context).nogGeenActiviteitenDezeWeek, style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)))
                    else
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (value / 5).clamp(0.0, 1.0),
                                backgroundColor: color.withValues(alpha: 0.2),
                                valueColor: AlwaysStoppedAnimation(color),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('$value/5', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? get _initialDateArg {
    final now = DateTime.now();
    final diff = _selectedDate.difference(now).inDays;
    if (diff == 0) return null;
    return '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
  }

  Widget _routeBuilder(String route, {void Function({bool? returnValue})? closeContainer}) {
    switch (route) {
      case '/mood': return MoodAssessmentScreen(onClose: closeContainer == null ? null : (saved) => closeContainer(returnValue: saved));
      case '/dagboek': return DagboekScreen(onClose: closeContainer == null ? null : (saved) => closeContainer(returnValue: saved));
      case '/morning-checkin': return MorningCheckInScreen(
        initialDate: _initialDateArg,
        onClose: closeContainer == null ? null : (saved) => closeContainer(returnValue: saved));
      case '/evening-checkin': return EveningCheckInScreen(
        initialDate: _initialDateArg,
        onClose: closeContainer == null ? null : (saved) => closeContainer(returnValue: saved));
      case '/activity': return ActivityScreen();
      case '/medication': return MedicationScreen();
      case '/weight': return WeightScreen();
      case '/appointments': return AppointmentsScreen();
      case '/voortekenen': return VoortekenenScreen();
      case '/crisisplan': return CrisisPlanScreen();
      case '/rapport': return RapportScreen();
      default: return SizedBox.shrink();
    }
  }

  Widget _buildAlertCard(Alert alert, ThemeData theme) {
    AlertSeverity severity = alert.severity == 'high' ? AlertSeverity.high : AlertSeverity.medium;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: severity == AlertSeverity.high ? AppTheme.error : AppTheme.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                severity == AlertSeverity.high ? Icons.warning_amber : Icons.warning,
                color: severity == AlertSeverity.high ? AppTheme.error : AppTheme.warning,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  alert.title,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(alert.message, style: TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            'Geregistreerd op: ${DateTime.now().toLocal().toString().split(' ')[0]}',
            style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color),
          ),
        ],
      ),
    );
  }

  Color _getSrtColor(double score) {
    if (score <= 20) return AppTheme.error;
    if (score <= 40) return AppTheme.warning;
    if (score <= 60) return AppTheme.success;
    return AppTheme.primaryTeal;
  }

  String _getSrtLabel(double score, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (score <= 20) return l10n.laag;
    if (score <= 40) return l10n.matigLabel;
    if (score <= 60) return l10n.goed;
    return l10n.uitstekendLabel;
  }
}

class _DagStatusMeter extends StatelessWidget {
  final int gelogd;
  final int totaal;

  const _DagStatusMeter({required this.gelogd, required this.totaal});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final allesKlaar = gelogd >= totaal;
    final color = allesKlaar ? AppTheme.success : (gelogd > 0 ? AppTheme.warning : Colors.grey.shade400);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            allesKlaar ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            l10n.dagStatusMeter(gelogd, totaal),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
