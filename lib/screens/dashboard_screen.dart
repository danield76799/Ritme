import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart';
import '../theme/app_theme.dart';
import '../service_locator.dart';
import '../services/notification_helper.dart';
import '../services/bipolar_alert_service.dart';
import '../utils/logger.dart';
import '../widgets/weekly_mood_chart.dart';
import 'login_screen.dart';
import 'mood_assessment_screen.dart';
import 'activity_screen.dart';
import 'medication_screen.dart';
import 'weight_screen.dart';
import 'appointments_screen.dart';
import 'sociaal_ritme_meter_screen.dart';
import 'voortekenen_screen.dart';
import 'crisisplan_screen.dart';
import 'rapport_screen.dart';
import '../generated/l10n/app_localizations.dart';

// Add enum for AlertSeverity
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
  List<Alert> _alerts = [];

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

  /// Geoptimaliseerde data laad: batch queries, parallel, geen dubbele calls
  Future<void> _loadData() async {
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final startDateStr = '${weekAgo.year}-${weekAgo.month.toString().padLeft(2, '0')}-${weekAgo.day.toString().padLeft(2, '0')}';
      final endDateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Alle data parallel ophalen in 3 batch queries (was: 14+ queries)
      final results = await Future.wait([
        db.getSettings(),
        db.getDailyLogsRange(startDateStr, endDateStr),
        db.getSrmActivitiesRange(startDateStr, endDateStr),
      ]);

      final settings = results[0] as Map<String, dynamic>?;
      final dailyLogs = results[1] as List<Map<String, dynamic>>;
      final weeklyActivities = results[2] as List<Map<String, dynamic>>;

      // Sleep score berekenen uit batch logs (geen 7 losse queries)
      double totalSleep = 0;
      int sleepCount = 0;
      int loggedDaysCount = 0;
      final sleepPerDay = <String, double>{};

      for (final log in dailyLogs) {
        final dateStr = log['date']?.toString();
        if (dateStr == null) continue;

        // Slaap uitlezen: eerst sleep_hours, fallback uren_slaap
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

      // SRT stabiliteit uit batch activiteiten (geen 7 losse queries)
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
          _weeklyLogs = dailyLogs;
          _lastUpdated = DateTime.now();
          _isLoading = false;
        });
      }

      // Alerts async in de achtergrond
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
    final dateStr = '${today.day}/${today.month}/${today.year}';
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
                case 1: Navigator.pushNamed(context, '/episodes'); break;
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
              PopupMenuItem(value: 1, child: ListTile(leading: Icon(Icons.timeline), title: Text(AppLocalizations.of(context).episodes), contentPadding: EdgeInsets.zero, dense: true)),
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
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
                    const SizedBox(height: 18),
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

              const SizedBox(height: 28),

              // Alerts
              if (_alerts.isNotEmpty) ...[
                ..._alerts.map((alert) => _buildAlertCard(alert, theme)),
                const SizedBox(height: 16),
              ],

              // Today section
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(children: [
                  Text(AppLocalizations.of(context).vandaag, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ]),
              ),

              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.2,
                children: [
                  _buildActionCard(context, icon: Icons.sentiment_satisfied_alt, color: const Color(0xFFD4956A), title: AppLocalizations.of(context).stemming, route: '/mood'),
                  _buildActionCard(context, icon: Icons.directions_walk, color: AppTheme.success, title: AppLocalizations.of(context).activiteitEnSlaap, route: '/activity'),
                  _buildActionCard(context, icon: Icons.medication, color: const Color(0xFFB4A8D4), title: AppLocalizations.of(context).medicatie, route: '/medication'),
                  _buildActionCard(context, icon: Icons.schedule, color: const Color(0xFF9DC09D), title: AppLocalizations.of(context).sociaalRitme, route: '/sociaal-ritme'),
                ],
              ),

              const SizedBox(height: 28),

              Row(
                children: [
                  Text(AppLocalizations.of(context).overzicht, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_lastUpdated != null)
                    Text(_formatLastUpdated(context), style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
                ],
              ),
              const SizedBox(height: 16),

              _buildMetricCard(
                context,
                icon: Icons.bedtime,
                title: AppLocalizations.of(context).slaapduurLabel,
                value: _sleepQuality > 0 ? _formatHours(_sleepQuality) : '-',
                subtitle: _loggedDaysCount > 0 ? AppLocalizations.of(context).nachten(_loggedDaysCount) : null,
                color: const Color(0xFF88B0C7),
                route: '/sleep-detail',
              ),
              const SizedBox(height: 10),
              _buildMetricCard(
                context,
                icon: Icons.schedule,
                title: AppLocalizations.of(context).srtScore,
                value: _rhythmStability > 0 ? '${_rhythmStability.round()}%' : '-',
                subtitle: _getSrtLabel(_rhythmStability, context),
                color: _getSrtColor(_rhythmStability),
                route: '/rhythm-detail',
              ),
              const SizedBox(height: 10),
              _buildMetricCard(
                context,
                icon: Icons.local_activity,
                title: AppLocalizations.of(context).activiteitenDezeWeekLabel,
                value: _weeklyActivities > 0 ? '$_weeklyActivities' : '-',
                color: AppTheme.warning,
                route: '/activities-detail',
              ),

              const SizedBox(height: 28),

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
      {required IconData icon, required Color color, required String title, required String route}) {
    return OpenContainer<bool>(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: Duration(milliseconds: 400),
      closedElevation: 2,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
      closedColor: Theme.of(context).cardColor,
      openColor: Theme.of(context).scaffoldBackgroundColor,
      onClosed: (_) => _loadData(),
      closedBuilder: (context, openContainer) {
        return InkWell(
          onTap: openContainer,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
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

  Widget _routeBuilder(String route, {void Function({bool? returnValue})? closeContainer}) {
    switch (route) {
      case '/mood': return MoodAssessmentScreen(onClose: closeContainer == null ? null : (saved) => closeContainer(returnValue: saved));
      case '/activity': return ActivityScreen();
      case '/medication': return MedicationScreen();
      case '/weight': return WeightScreen();
      case '/appointments': return AppointmentsScreen();
      case '/sociaal-ritme': return SociaalRitmeMeterScreen();
      case '/voortekenen': return VoortekenenScreen();
      case '/crisisplan': return CrisisPlanScreen();
      case '/rapport': return RapportScreen();
      default: return SizedBox.shrink();
    }
  }

  Widget _buildMetricCard(BuildContext context,
      {required IconData icon, required String title, required String value, String? subtitle, required Color color, required String route}) {
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
                    Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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