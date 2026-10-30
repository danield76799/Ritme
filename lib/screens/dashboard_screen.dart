import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/sparkline.dart';
import '../service_locator.dart';
import '../services/notification_helper.dart';
import '../services/bipolar_alert_service.dart';
import '../utils/logger.dart';
import '../widgets/weekly_mood_chart.dart';
import '../widgets/metric_card_shell.dart';
import '../widgets/tile_accent.dart';
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
import 'sleep_detail_screen.dart';
import 'rhythm_detail_screen.dart';
import '../generated/l10n/app_localizations.dart';

enum AlertSeverity { high, medium }

const _lucideIcons = <String, IconData>{
  'heartPulse': Icons.monitor_heart,
  'settings': Icons.settings,
  'moreVertical': Icons.more_vert,
  'barChart': Icons.bar_chart,
  'scale': Icons.scale,
  'calendarDays': Icons.calendar_month,
  'alertTriangle': Icons.warning_amber,
  'fileText': Icons.description,
  'helpCircle': Icons.help_outline,
  'logOut': Icons.logout,
  'sun': Icons.wb_sunny,
  'moonStar': Icons.nightlight_round,
  'pill': Icons.medication,
  'bookOpen': Icons.menu_book,
  'bedDouble': Icons.bed,
  'activity': Icons.directions_run,
};

IconData lucideIcon(String name) => _lucideIcons[name] ?? Icons.help_outline;

const avondSrmTypes = {'Avondeten', 'Naar bed'};

bool ochtendGedaan(Map<String, dynamic> log) {
  final s = log['uren_slaap'];
  final sNum = s is num ? s.toDouble() : double.tryParse(s?.toString() ?? '');
  final a = log['awake_minutes'];
  final aNum = a is num ? a.toInt() : int.tryParse(a?.toString() ?? '') ?? 0;
  final q = log['q4_slaapbehoefte'];
  return (sNum != null && sNum > 0) || aNum > 0 || q != null;
}

bool avondGedaan(Iterable<Map<String, dynamic>> activiteiten, String datum) {
  return activiteiten.any((a) {
    if (a['date']?.toString() != datum) return false;
    if (!avondSrmTypes.contains(a['activity_type']?.toString() ?? '')) {
      return false;
    }
    return (a['actual_time']?.toString() ?? '').isNotEmpty;
  });
}

String _datumStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

List<String> weekVenster(DateTime datum) {
  final end = DateTime(datum.year, datum.month, datum.day);
  final start = end.subtract(const Duration(days: 6));
  return [_datumStr(start), _datumStr(end)];
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  Map<String, dynamic>? _settings;
  bool _isLoading = true;
  double _sleepQuality = 0.0;
  double _rhythmStability = 0.0;
  DateTime? _lastUpdated;
  List<Map<String, dynamic>> _weeklyLogs = [];
  List<Map<String, dynamic>> _dailyLogs = [];
  Set<String> _checkinTypes = {};
  List<Map<String, dynamic>> _srmActivitiesList = [];
  List<Alert> _alerts = [];
  DateTime _selectedDate = DateTime.now();
  _SleepPeriod _sleepPeriod = _SleepPeriod.fourteenDays;
  Map<String, double> _sleepPerDay = const {};
  int _dagStreak = 0;

  late AnimationController _staggerController;
  late List<Animation<double>> _cardAnimations;
  late Animation<double> _greetingAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAnimations();
    _loadData();
    _setupNotifications();
    _openPendingCheckin();
  }

  void _initAnimations() {
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _greetingAnimation = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
    );
    _cardAnimations = List.generate(12, (index) {
      final start = 0.2 + (index * 0.06).clamp(0.0, 0.5);
      final end = (start + 0.35).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
      _openPendingCheckin();
    }
  }

  void _openPendingCheckin() {
    final route = NotificationHelper.instance.consumePendingCheckinRoute();
    if (route == null || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushNamed(context, route).then((_) {
        if (mounted) _loadData();
      });
    });
  }

  Future<void> _loadData() async {
    try {
      final now = DateTime.now();
      final twoWeeksAgo = now.subtract(const Duration(days: 14));
      final startDateStr =
          '${twoWeeksAgo.year}-${twoWeeksAgo.month.toString().padLeft(2, '0')}-${twoWeeksAgo.day.toString().padLeft(2, '0')}';
      final endDateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

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
      if (todayLog != null && ochtendGedaan(todayLog)) {
        checkinTypesToday.add('ochtend');
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
      if (avondGedaan(todayActs, todayStr)) checkinTypesToday.add('avond');

      final streakLookback = now.subtract(const Duration(days: 14));
      final streakLookbackStr =
          '${streakLookback.year}-${streakLookback.month.toString().padLeft(2, '0')}-${streakLookback.day.toString().padLeft(2, '0')}';
      final allMedicationIntake = await db.getMedicationIntakeRange(
        streakLookbackStr,
        endDateStr,
      );
      final medDates = <String>{};
      for (final row in allMedicationIntake) {
        final raw = row['aantal_ingenomen'];
        final n = raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
        if (n > 0) medDates.add(row['date']?.toString() ?? '');
      }

      int streak = 0;
      for (int i = 0; i < 14; i++) {
        final d = now.subtract(Duration(days: i));
        final ds =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        final dayTypes = <String>{};
        final dayLog = dailyLogs.where((l) => l['date'] == ds).firstOrNull;
        if (dayLog != null && ochtendGedaan(dayLog)) {
          dayTypes.add('ochtend');
        }
        if (medDates.contains(ds)) dayTypes.add('medicatie');
        final dayActs = weeklyActivities.where((a) => a['date'] == ds).toList();
        if (avondGedaan(dayActs, ds)) {
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
          totalSleep += sleep;
          sleepCount++;
        }
      }
      final avgSleep = sleepCount > 0 ? totalSleep / sleepCount : 0.0;
      _sleepPerDay = Map.of(sleepPerDay);

      final weekAgo = now.subtract(const Duration(days: 7));
      final weekAgoStr =
          '${weekAgo.year}-${weekAgo.month.toString().padLeft(2, '0')}-${weekAgo.day.toString().padLeft(2, '0')}';

      double periodSleep() {
        switch (_sleepPeriod) {
          case _SleepPeriod.yesterday:
            final yStr =
                '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
            final vandaag = sleepPerDay[yStr];
            if (vandaag != null) return vandaag;
            final y = now.subtract(const Duration(days: 1));
            final gisterenStr =
                '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
            return sleepPerDay[gisterenStr] ?? 0.0;
          case _SleepPeriod.week:
            var total = 0.0;
            var n = 0;
            sleepPerDay.forEach((dateStr, hours) {
              if (dateStr.compareTo(weekAgoStr) >= 0) {
                total += hours;
                n++;
              }
            });
            return n > 0 ? total / n : 0.0;
          case _SleepPeriod.fourteenDays:
            return avgSleep;
        }
      }

      final periodAvg = periodSleep();

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
          _sleepQuality = periodAvg;
          _rhythmStability = stability;
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

  void _recomputeSleepValue() {
    final now = DateTime.now();
    String dateStr(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    double value;
    switch (_sleepPeriod) {
      case _SleepPeriod.yesterday:
        final vandaag = _sleepPerDay[dateStr(now)];
        value = vandaag ??
            _sleepPerDay[dateStr(now.subtract(const Duration(days: 1)))] ??
            0.0;
      case _SleepPeriod.week:
        final weekAgoStr = dateStr(now.subtract(const Duration(days: 7)));
        var total = 0.0;
        var n = 0;
        _sleepPerDay.forEach((date, hours) {
          if (date.compareTo(weekAgoStr) >= 0) {
            total += hours;
            n++;
          }
        });
        value = n > 0 ? total / n : 0.0;
      case _SleepPeriod.fourteenDays:
        var total = 0.0;
        _sleepPerDay.forEach((_, hours) => total += hours);
        value = _sleepPerDay.isNotEmpty ? total / _sleepPerDay.length : 0.0;
    }
    if (mounted) setState(() => _sleepQuality = value);
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
    final l10n = AppLocalizations.of(context);
    final hour = DateTime.now().hour;
    if (hour < 6) return l10n.greetingNightMetNaam(name);
    if (hour < 12) return l10n.greetingMorningMetNaam(name);
    if (hour < 18) return l10n.greetingAfternoonMetNaam(name);
    return l10n.greetingEveningMetNaam(name);
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
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).laden,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.secondaryText(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final today = DateTime.now();
    final dateStr = DateFormat(
      'EEEE d MMMM',
      Localizations.localeOf(context).toString().split('_').first,
    ).format(today);
    final username =
        _settings?['username']?.toString() ??
        AppLocalizations.of(context).gebruikerFallback;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: AppTheme.screenPadding,
        title: Text(
          'Ritme',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(lucideIcon('settings'), color: theme.colorScheme.onSurface),
            onPressed: () async {
              await Navigator.pushNamed(context, '/settings');
              _loadData();
            },
            tooltip: AppLocalizations.of(context).instellingen,
          ),
          PopupMenuButton<int>(
            icon: Icon(lucideIcon('moreVertical'), color: theme.colorScheme.onSurface),
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
              PopupMenuItem(value: 0, child: ListTile(leading: Icon(lucideIcon('barChart')), title: Text(AppLocalizations.of(context).statistieken), contentPadding: EdgeInsets.zero, dense: true)),
              const PopupMenuDivider(),
              PopupMenuItem(value: 2, child: ListTile(leading: Icon(lucideIcon('scale')), title: Text(AppLocalizations.of(context).gewicht), contentPadding: EdgeInsets.zero, dense: true)),
              PopupMenuItem(value: 3, child: ListTile(leading: Icon(lucideIcon('calendarDays')), title: Text(AppLocalizations.of(context).afspraken), contentPadding: EdgeInsets.zero, dense: true)),
              PopupMenuItem(value: 4, child: ListTile(leading: Icon(lucideIcon('alertTriangle')), title: Text(AppLocalizations.of(context).voortekenen), contentPadding: EdgeInsets.zero, dense: true)),
              PopupMenuItem(value: 5, child: ListTile(leading: Icon(lucideIcon('fileText')), title: Text(AppLocalizations.of(context).rapport), contentPadding: EdgeInsets.zero, dense: true)),
              PopupMenuItem(value: 6, child: ListTile(leading: Icon(lucideIcon('helpCircle')), title: Text(AppLocalizations.of(context).gebruiksaanwijzing), contentPadding: EdgeInsets.zero, dense: true)),
              const PopupMenuDivider(),
              PopupMenuItem(value: 7, child: ListTile(leading: Icon(lucideIcon('logOut'), color: AppTheme.error), title: Text(AppLocalizations.of(context).uitloggen, style: TextStyle(color: AppTheme.error)), contentPadding: EdgeInsets.zero, dense: true)),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreetingCard(username, dateStr, isDark),
                const SizedBox(height: 24),
                if (_alerts.isNotEmpty) ...[
                  ..._alerts.map((alert) => _buildAlertCard(alert, theme)),
                  const SizedBox(height: 16),
                ],
                _buildTodayHeader(),
                const SizedBox(height: 12),
                _buildTaskGrid(),
                const SizedBox(height: 16),
                _buildSecondaryActions(),
                const SizedBox(height: 24),
                _buildOverviewHeader(),
                const SizedBox(height: 12),
                _StaggeredCard(
                  animation: _cardAnimations[6],
                  child: _buildMetricCard(
                    context,
                    icon: lucideIcon('bedDouble'),
                    title: AppLocalizations.of(context).slaapduurLabel,
                    value: _sleepQuality > 0 ? _formatHours(_sleepQuality) : null,
                    emptyValue: AppLocalizations.of(context).nogNietGelogdVandaag,
                    emptyHint: AppLocalizations.of(context).slaapVerbeterStemming,
                    color: const Color(0xFF88B0C7),
                    route: '/sleep-detail',
                    isEmpty: _sleepQuality <= 0,
                    sparkline: _slaapSparkline(),
                    footer: _SleepPeriodSwitch(
                      selected: _sleepPeriod,
                      onChanged: (p) => setState(() {
                        _sleepPeriod = p;
                        _recomputeSleepValue();
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _StaggeredCard(
                  animation: _cardAnimations[7],
                  child: _buildMetricCard(
                    context,
                    icon: lucideIcon('activity'),
                    title: AppLocalizations.of(context).srtScore,
                    value: _rhythmStability > 0 ? '${_rhythmStability.round()}%' : null,
                    emptyValue: AppLocalizations.of(context).logVandaagOmTeZien,
                    subtitle: _rhythmStability > 0 ? _getSrtLabel(_rhythmStability, context) : null,
                    emptyHint: AppLocalizations.of(context).srtTooltip,
                    color: _getSrtColor(_rhythmStability),
                    route: '/rhythm-detail',
                    isEmpty: _rhythmStability <= 0,
                    sparkline: _srtSparkline(),
                  ),
                ),
                const SizedBox(height: 24),
                _StaggeredCard(
                  animation: _cardAnimations[8],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            AppLocalizations.of(context).stemmingTrend,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingCard(String username, String dateStr, bool isDark) {
    return AnimatedBuilder(
      animation: _greetingAnimation,
      builder: (context, child) => FadeTransition(
        opacity: _greetingAnimation,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(_greetingAnimation),
          child: child,
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(colors: [const Color(0xFF2A3D42), const Color(0xFF1A2B30)], begin: Alignment.topLeft, end: Alignment.bottomRight)
              : AppTheme.brandGradient,
          borderRadius: BorderRadius.circular(AppTheme.largeRadius),
          boxShadow: [BoxShadow(color: (isDark ? Colors.black : const Color(0xFFB4A8D4)).withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _getGreeting(username),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(dateStr, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85), fontSize: 16)),
                ),
                if (_dagStreak > 0) _buildStreakChip(),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTimeChip(Icons.wb_sunny_outlined, AppLocalizations.of(context).opstaan, _settings?['target_opstaan'] ?? '08:00'),
                _buildTimeChip(Icons.bedtime, AppLocalizations.of(context).slapen, _settings?['target_slapen'] ?? '23:00'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip(IconData icon, String label, String time) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/settings'),
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppTheme.smallRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 16),
              const SizedBox(width: 6),
              // De chip mag niet krimpen: dan wordt de tijd afgeknipt.
              // Hij staat in een Wrap, dus hij springt op de volgende regel
              // in plaats van te krimpen.
              Text(
                AppLocalizations.of(context)
                    .dashboardTijdchip(label, time),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit_outlined, size: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Tikbaar: hiermee kies je de dag waarvan het dashboard de
        // check-ins toont (de herbouw had de datumkiezer verloren).
        Flexible(
          child: InkWell(
            onTap: () => _selectDate(context),
            borderRadius: BorderRadius.circular(AppTheme.smallRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _formatSelectedDate(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            AppLocalizations.of(context)
                .dagStatusMeter(_checkinTypes.length, 4),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3,
      children: [
        _StaggeredCard(
          animation: _cardAnimations[0],
          child: _buildCheckinCard(context, icon: lucideIcon('sun'), accent: TileAccent.morning, title: AppLocalizations.of(context).ochtendCheckIn, route: '/morning-checkin', date: _selectedDate, isOchtend: true),
        ),
        _StaggeredCard(
          animation: _cardAnimations[1],
          child: _buildCheckinCard(context, icon: lucideIcon('moonStar'), accent: TileAccent.evening, title: AppLocalizations.of(context).avondCheckIn, route: '/evening-checkin', date: _selectedDate, isOchtend: false),
        ),
        _StaggeredCard(
          animation: _cardAnimations[2],
          child: _buildActionCard(context, icon: lucideIcon('pill'), accent: TileAccent.medication, title: AppLocalizations.of(context).medicatie, route: '/medication', isCompleted: _checkinTypes.contains('medicatie')),
        ),
        _StaggeredCard(
          animation: _cardAnimations[3],
          child: _buildActionCard(context, icon: lucideIcon('bookOpen'), accent: TileAccent.journal, title: AppLocalizations.of(context).dagboek, route: '/dagboek', isCompleted: _checkinTypes.contains('dagboek')),
        ),
      ],
    );
  }

  Widget _buildSecondaryActions() {
    return Row(
      children: [
        Expanded(
          child: _SecondaryActionButton(
            icon: lucideIcon('fileText'),
            label: AppLocalizations.of(context).rapport,
            onTap: () => Navigator.pushNamed(context, '/rapport'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SecondaryActionButton(
            icon: lucideIcon('calendarDays'),
            label: AppLocalizations.of(context).afspraken,
            onTap: () => Navigator.pushNamed(context, '/appointments'),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckinCard(BuildContext context, {required IconData icon, required TileAccent accent, required String title, required String route, DateTime? date, bool isOchtend = false}) {
    final ds = '${date!.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    bool hasLog = isOchtend ? _dailyLogs.where((l) => l['date'] == ds).any(ochtendGedaan) : avondGedaan(_srmActivitiesList, ds);
    return _buildActionCard(context, icon: icon, accent: accent, title: title, route: route, isCompleted: hasLog);
  }

  Widget _buildActionCard(BuildContext context, {required IconData icon, required TileAccent accent, required String title, required String route, bool isCompleted = false}) {
    return OpenContainer<bool>(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 400),
      closedElevation: 0,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isCompleted ? AppTheme.accentMint.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08), width: isCompleted ? 1.5 : 1),
      ),
      closedColor: Theme.of(context).cardColor,
      openColor: Theme.of(context).scaffoldBackgroundColor,
      onClosed: (_) {
        _loadData();
        if (_selectedDate.difference(DateTime.now()).inDays != 0) _loadDataForDate(_selectedDate);
      },
      closedBuilder: (context, openContainer) => InkWell(
        onTap: openContainer,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                TileIconBadge(icon: icon, accent: accent, size: 56, iconSize: 24, isCompleted: isCompleted),
                if (isCompleted)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(Icons.check_circle, color: AppTheme.accentMint, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      openBuilder: (context, closeContainer) => _routeBuilder(route, closeContainer: closeContainer),
    );
  }

  Widget _buildOverviewHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            AppLocalizations.of(context).overzicht,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        if (_lastUpdated != null)
          Flexible(
            child: Text(
              _formatLastUpdated(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 12, color: AppTheme.secondaryText(context)),
            ),
          ),
      ],
    );
  }

  // --- Helper methods from original file ---
  List<double> _slaapSparkline() {
    final gesorteerd = _sleepPerDay.keys.toList()..sort();
    return [for (final d in gesorteerd.skip(gesorteerd.length > 14 ? gesorteerd.length - 14 : 0)) _sleepPerDay[d]!];
  }

  List<double> _srtSparkline() {
    final perDag = <String, List<int>>{};
    for (final a in _srmActivitiesList) {
      final actualTime = a['actual_time'];
      final rawPScore = a['p_score'];
      if (actualTime == null || rawPScore == null) continue;
      final int pScore = rawPScore is int ? rawPScore : int.tryParse(rawPScore.toString()) ?? 0;
      if (pScore <= 0) continue;
      final date = a['date']?.toString();
      if (date == null || date.isEmpty) continue;
      perDag.putIfAbsent(date, () => []).add(pScore);
    }
    final gesorteerd = perDag.keys.toList()..sort();
    return [for (final d in gesorteerd.skip(gesorteerd.length > 14 ? gesorteerd.length - 14 : 0)) perDag[d]!.reduce((x, y) => x + y) / perDag[d]!.length];
  }

  Widget _buildMetricCard(BuildContext context, {required IconData icon, required String title, required String? value, String? emptyValue, String? subtitle, String? secondSubtitle, String? emptyHint, required Color color, required String route, bool isEmpty = false, Widget? footer, List<double>? sparkline, Color? sparklineKleur}) {
    final theme = Theme.of(context);
    return OpenContainer<bool>(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 400),
      closedElevation: 0,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      closedColor: theme.cardColor,
      openColor: theme.scaffoldBackgroundColor,
      onClosed: (_) { _loadData(); if (_selectedDate.difference(DateTime.now()).inDays != 0) _loadDataForDate(_selectedDate); },
      openBuilder: (context, _) => _routeBuilder(route),
      closedBuilder: (context, openContainer) => MetricCardShell(
        icon: icon, color: color, onTap: openContainer,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 4),
            if (isEmpty && emptyHint != null)
              Text(emptyHint, style: TextStyle(fontSize: 14, color: AppTheme.secondaryText(context)))
            else if (subtitle != null)
              Text(subtitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: theme.textTheme.bodyMedium?.color)),
            if (value != null)
              Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: value.length > 12 ? 14 : 18))
            else if (emptyValue != null)
              Text(emptyValue, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.secondaryText(context))),
            if (secondSubtitle != null) Text(secondSubtitle, style: TextStyle(fontSize: 13, color: AppTheme.secondaryText(context))),
            if (footer != null) ...[const SizedBox(height: 8), footer],
            if (!isEmpty && sparkline != null && sparkline.length >= 2) ...[const SizedBox(height: 8), Sparkline(waarden: sparkline, kleur: sparklineKleur ?? color)],
          ],
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
      case '/morning-checkin': return MorningCheckInScreen(initialDate: _initialDateArg, onClose: closeContainer == null ? null : (saved) => closeContainer(returnValue: saved));
      case '/evening-checkin': return EveningCheckInScreen(initialDate: _initialDateArg, onClose: closeContainer == null ? null : (saved) => closeContainer(returnValue: saved));
      case '/activity': return ActivityScreen();
      case '/medication': return MedicationScreen();
      case '/weight': return WeightScreen();
      case '/appointments': return AppointmentsScreen();
      case '/voortekenen': return VoortekenenScreen();
      case '/crisisplan': return CrisisPlanScreen();
      case '/rapport': return RapportScreen();
      case '/sleep-detail': return SleepDetailScreen();
      case '/rhythm-detail': return RhythmDetailScreen();
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
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        border: Border.all(color: severity == AlertSeverity.high ? AppTheme.error : AppTheme.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(severity == AlertSeverity.high ? Icons.warning_amber : Icons.warning, color: severity == AlertSeverity.high ? AppTheme.error : AppTheme.warning, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
            ],
          ),
          const SizedBox(height: 8),
          Text(alert.message, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          Text(AppLocalizations.of(context).geregistreerdOp(DateTime.now().toLocal().toString().split(' ')[0]), style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
        ],
      ),
    );
  }

  Color _getSrtColor(double score) {
    if (score <= 20) return AppTheme.error;
    if (score <= 40) return AppTheme.warning;
    if (score <= 60) return AppTheme.success;
    return Theme.of(context).colorScheme.primary;
  }

  String _getSrtLabel(double score, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (score <= 20) return l10n.laag;
    if (score <= 40) return l10n.matigLabel;
    if (score <= 60) return l10n.goed;
    return l10n.uitstekendLabel;
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
      locale: Localizations.localeOf(context).languageCode == 'nl' ? const Locale('nl', 'NL') : null,
      helpText: AppLocalizations.of(context).kiesDatum,
      cancelText: AppLocalizations.of(context).annuleren,
      confirmText: AppLocalizations.of(context).bekijken,
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _loadDataForDate(picked);
    }
  }

  Future<void> _loadDataForDate(DateTime date) async {
    try {
      final ds = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final venster = weekVenster(date);
      final results = await Future.wait([
        db.getSettings(),
        db.getDailyLogsRange(venster[0], venster[1]),
        db.getSrmActivitiesRange(venster[0], venster[1]),
      ]);
      if (!mounted) return;
      final settings = results[0] as Map<String, dynamic>?;
      final dailyLogs = results[1] as List<Map<String, dynamic>>;
      final weeklyActivities = results[2] as List<Map<String, dynamic>>;
      final selectedDs = ds;
      final todayLogForDate = dailyLogs.where((l) => l['date'] == selectedDs).firstOrNull;
      final todayActsForDate = weeklyActivities.where((a) => a['date'] == selectedDs).toList();
      final checkinTypesForDate = <String>{};
      if (todayLogForDate != null && ochtendGedaan(todayLogForDate)) checkinTypesForDate.add('ochtend');
      try {
        final intake = await db.getMedicationIntake(selectedDs);
        if (intake.any((row) => (row['aantal_ingenomen'] is int ? row['aantal_ingenomen'] : int.tryParse(row['aantal_ingenomen']?.toString() ?? '') ?? 0) > 0)) checkinTypesForDate.add('medicatie');
      } catch (_) {}
      try {
        final dagboek = await db.getDagboek(selectedDs);
        if (dagboek != null) checkinTypesForDate.add('dagboek');
      } catch (_) {}
      if (avondGedaan(todayActsForDate, selectedDs)) checkinTypesForDate.add('avond');
      setState(() {
        _settings = settings;
        _dailyLogs = dailyLogs;
        _srmActivitiesList = weeklyActivities;
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
    return DateFormat('d MMMM', locale).format(_selectedDate);
  }

  Widget _buildStreakChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 13, color: AppTheme.streakText(Theme.of(context).brightness), semanticLabel: AppLocalizations.of(context).streakMeerdereDagen(_dagStreak)),
          const SizedBox(width: 5),
          Text(
            _dagStreak == 1 ? AppLocalizations.of(context).streakEenDag : AppLocalizations.of(context).streakMeerdereDagen(_dagStreak),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.streakText(Theme.of(context).brightness)),
          ),
        ],
      ),
    );
  }
}

class _SleepPeriodSwitch extends StatelessWidget {
  final _SleepPeriod selected;
  final ValueChanged<_SleepPeriod> onChanged;
  const _SleepPeriodSwitch({required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        for (final period in _SleepPeriod.values) ...[
          if (period != _SleepPeriod.values.first) const SizedBox(width: 6),
          Expanded(
            child: _periodPill(
              context,
              label: switch (period) {
                _SleepPeriod.yesterday => l10n.periodYesterday,
                _SleepPeriod.week => l10n.periodWeek,
                _SleepPeriod.fourteenDays => l10n.periodFourteenDays,
              },
              isSelected: period == selected,
              onTap: () => onChanged(period),
              theme: theme,
            ),
          ),
        ],
      ],
    );
  }
  Widget _periodPill(BuildContext context, {required String label, required bool isSelected, required VoidCallback onTap, required ThemeData theme}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? theme.colorScheme.onPrimaryContainer : AppTheme.secondaryText(context))),
      ),
    );
  }
}

class _StaggeredCard extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _StaggeredCard({required this.animation, required this.child});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _SecondaryActionButton({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppTheme.accentMint.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
            ],
          ),
        ),
      ),
    );
  }
}

enum _SleepPeriod { yesterday, week, fourteenDays }