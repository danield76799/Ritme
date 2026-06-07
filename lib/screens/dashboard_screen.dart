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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final settings = await db.getSettings();
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final dailyLogs = await db.getDailyLogs();

      Map<String, double> sleepPerDay = {};
      int activityCount = 0;
      int loggedDaysCount = 0;

      for (var log in dailyLogs) {
        if (log['date'] == null) continue;
        try {
          final logDate = DateTime.parse(log['date'] as String);
          if (logDate.isAfter(weekAgo) || logDate.isAtSameMomentAs(weekAgo)) {
            final dateStr = log['date'] as String;
            final dynamic rawSleep = log['sleep_hours'];
            if (rawSleep != null) {
              double? sleep;
              if (rawSleep is num) { sleep = rawSleep.toDouble(); }
              else if (rawSleep is String) { sleep = double.tryParse(rawSleep); }
              if (sleep != null && sleep > 0 && !sleepPerDay.containsKey(dateStr)) {
                sleepPerDay[dateStr] = sleep;
                loggedDaysCount++;
              }
            }
            if (!sleepPerDay.containsKey(dateStr)) {
              final dynamic rawUrenSlaap = log['uren_slaap'];
              if (rawUrenSlaap != null) {
                double? urenSlaap;
                if (rawUrenSlaap is num) { urenSlaap = rawUrenSlaap.toDouble(); }
                else if (rawUrenSlaap is String) { urenSlaap = double.tryParse(rawUrenSlaap); }
                if (urenSlaap != null && urenSlaap > 0) {
                  sleepPerDay[dateStr] = urenSlaap;
                  loggedDaysCount++;
                }
              }
            }
            if (log['activity_type'] != null || log['sociale_contacten'] != null) {
              activityCount++;
            }
          }
        } catch (_) {}
      }

      double totalSleep = 0;
      int sleepCount = 0;
      for (int i = 0; i < 7; i++) {
        final checkDate = now.subtract(Duration(days: i));
        final checkDateStr = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
        final sleepLog = await db.getSleepLog(checkDateStr);
        if (sleepLog != null && sleepLog['sleep_hours'] != null) {
          final dynamic rawSleep = sleepLog['sleep_hours'];
          double sleepHours = 0;
          if (rawSleep is double) { sleepHours = rawSleep; }
          else if (rawSleep is int) { sleepHours = rawSleep.toDouble(); }
          else if (rawSleep is String) { sleepHours = double.tryParse(rawSleep) ?? 0; }
          if (sleepHours > 0) { totalSleep += sleepHours; sleepCount++; }
        }
      }
      final avgSleep = sleepCount > 0 ? totalSleep / sleepCount : 0;
      final sleepScore = avgSleep;

      double totalPScore = 0;
      int totalActivities = 0;
      for (int i = 0; i < 7; i++) {
        final checkDate = now.subtract(Duration(days: i));
        final checkDateStr = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
        final dayActivities = await db.getSrmActivities(checkDateStr);
        for (var activity in dayActivities) {
          if (activity['actual_time'] != null && activity['p_score'] != null) {
            final dynamic rawPScore = activity['p_score'];
            int pScore = 0;
            if (rawPScore is int) { pScore = rawPScore; }
            else if (rawPScore is String) { pScore = int.tryParse(rawPScore) ?? 0; }
            if (pScore > 0) { totalPScore += pScore; totalActivities++; }
          }
        }
      }
      final stability = totalActivities > 0 ? (totalPScore / totalActivities / 5 * 100) : 0;

      final weeklyLogs = dailyLogs.where((log) {
        if (log['date'] == null) return false;
        try {
          final logDate = DateTime.parse(log['date'] as String);
          return logDate.isAfter(weekAgo) || logDate.isAtSameMomentAs(weekAgo);
        } catch (_) { return false; }
      }).toList();

      int totalWeeklyActivities = 0;
      for (int i = 0; i < 7; i++) {
        final checkDate = now.subtract(Duration(days: i));
        final checkDateStr = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
        final dayActivities = await db.getSrmActivities(checkDateStr);
        totalWeeklyActivities += dayActivities.length;
      }

      if (mounted) {
        setState(() {
          _settings = settings;
          _sleepQuality = sleepScore.toDouble();
          _rhythmStability = stability.toDouble();
          _weeklyActivities = totalWeeklyActivities;
          _loggedDaysCount = loggedDaysCount;
          _weeklyLogs = weeklyLogs;
          _lastUpdated = DateTime.now();
          _isLoading = false;
        });
      }

      BipolarAlertService.instance.runAllChecks().then((alerts) {
        if (mounted) setState(() => _alerts = alerts);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  String _formatLastUpdated() {
    if (_lastUpdated == null) return '';
    final diff = DateTime.now().difference(_lastUpdated!);
    if (diff.inSeconds < 60) return 'Zojuist bijgewerkt';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min geleden';
    if (diff.inHours < 24) return '${diff.inHours}u geleden';
    return '${diff.inDays}d geleden';
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
        title: Text(
          'Ritme',
          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.pushNamed(context, '/help'),
            tooltip: 'Gebruiksaanwijzing',
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.pushNamed(context, '/statistics'),
            tooltip: 'Statistieken',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.pushNamed(context, '/settings');
              _loadData();
            },
            tooltip: 'Instellingen',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Uitloggen',
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
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? const LinearGradient(
                          colors: [Color(0xFF2A2936), Color(0xFF3D3B4E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : AppTheme.warmGradient,
                  borderRadius: BorderRadius.circular(AppTheme.largeRadius),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? Colors.black : const Color(0xFFB4A8D4)).withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
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
                          color: isDark ? Colors.white : Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.white.withOpacity(0.85),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _buildTimeChip(Icons.wb_sunny_outlined, 'Opstaan', _settings?['target_opstaan'] ?? '08:00', isDark),
                        const SizedBox(width: 8),
                        _buildTimeChip(Icons.bedtime, 'Slapen', _settings?['target_slapen'] ?? '23:00', isDark),
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
                  const Text('Vandaag', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('Tik om te loggen', style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
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
                  _buildActionCard(context, icon: Icons.sentiment_satisfied_alt, color: const Color(0xFFD4956A), title: 'Stemming', route: '/mood'),
                  _buildActionCard(context, icon: Icons.directions_walk, color: AppTheme.success, title: 'Activiteit', route: '/activity'),
                  _buildActionCard(context, icon: Icons.monitor_weight, color: const Color(0xFF88B0C7), title: 'Gewicht', route: '/weight'),
                  _buildActionCard(context, icon: Icons.calendar_today, color: const Color(0xFFB4A8D4), title: 'Afspraken', route: '/appointments'),
                  _buildActionCard(context, icon: Icons.schedule, color: const Color(0xFF9DC09D), title: 'Sociaal Ritme', route: '/sociaal-ritme'),
                  _buildActionCard(context, icon: Icons.warning_amber, color: AppTheme.warning, title: 'Voortekenen', route: '/voortekenen'),
                  _buildActionCard(context, icon: Icons.assignment, color: AppTheme.error, title: 'Crisisplan', route: '/crisisplan'),
                  _buildActionCard(context, icon: Icons.description, color: AppTheme.primaryLavender, title: 'Rapport', route: '/rapport'),
                ],
              ),

              const SizedBox(height: 28),

              Row(
                children: [
                  const Text('Overzicht', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_lastUpdated != null)
                    Text(_formatLastUpdated(), style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
                ],
              ),
              const SizedBox(height: 16),

              _buildMetricCard(
                context,
                icon: Icons.bedtime,
                title: 'Slaapduur',
                value: _sleepQuality > 0 ? _formatHours(_sleepQuality) : '-',
                subtitle: _loggedDaysCount > 0 ? '$_loggedDaysCount nachten' : null,
                color: const Color(0xFF88B0C7),
                route: '/sleep-detail',
              ),
              const SizedBox(height: 10),
              _buildMetricCard(
                context,
                icon: Icons.schedule,
                title: 'SRT Score',
                value: _rhythmStability > 0 ? '${_rhythmStability.round()}%' : '-',
                subtitle: _getSrtLabel(_rhythmStability),
                color: _getSrtColor(_rhythmStability),
                route: '/rhythm-detail',
              ),
              const SizedBox(height: 10),
              _buildMetricCard(
                context,
                icon: Icons.local_activity,
                title: 'Activiteiten deze week',
                value: _weeklyActivities > 0 ? '$_weeklyActivities' : '-',
                color: AppTheme.warning,
                route: '/activities-detail',
              ),

              const SizedBox(height: 28),

              Row(children: [
                const Text('Stemming Trend', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/insights'),
                  icon: const Icon(Icons.insights, size: 18),
                  label: const Text('Inzichten'),
                ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/quick-checkin');
          if (result == true) _loadData();
        },
        icon: const Icon(Icons.bolt, color: Colors.white),
        label: const Text('Snelle Check-in', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildTimeChip(IconData icon, String label, String time, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('$label $time', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context,
      {required IconData icon, required Color color, required String title, required String route}) {
    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 400),
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
                  color: color.withOpacity(0.1),
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
        return _routeBuilder(route);
      },
    );
  }

  Widget _routeBuilder(String route) {
    switch (route) {
      case '/mood': return const MoodScreen();
      case '/activity': return ActivityScreen();
      case '/weight': return WeightScreen();
      case '/appointments': return AppointmentsScreen();
      case '/sociaal-ritme': return SociaalRitmeMeterScreen();
      case '/voortekenen': return VoortekenenScreen();
      case '/crisisplan': return CrisisPlanScreen();
      case '/rapport': return RapportScreen();
      default: return const SizedBox.shrink();
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
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
                    const SizedBox(height: 3),
                    Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    if (subtitle != null)
                      Text(subtitle, style: TextStyle(fontSize: 11, color: theme.textTheme.bodyMedium?.color)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: theme.textTheme.bodyMedium?.color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(Alert alert, ThemeData theme) {
    Color color;
    IconData icon;
    switch (alert.severity) {
      case 'high': color = AppTheme.error; icon = Icons.warning_rounded; break;
      case 'medium': color = AppTheme.warning; icon = Icons.info_outline; break;
      default: color = const Color(0xFF88B0C7); icon = Icons.info_outline;
    }
    String? route;
    if (alert.type.startsWith('slaap')) { route = '/sleep-detail'; }
    else if (alert.type.startsWith('voortekenen')) { route = '/voortekenen'; }
    else if (alert.type.startsWith('srt')) { route = '/sociaal-ritme'; }

    return Material(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: route != null ? () => Navigator.pushNamed(context, route) : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
                const SizedBox(height: 2),
                Text(alert.message, style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
              ],
            )),
            if (route != null) Icon(Icons.arrow_forward_ios, size: 14, color: color.withOpacity(0.5)),
          ]),
        ),
      ),
    );
  }

  Color _getSrtColor(double score) {
    if (score >= 80) return AppTheme.success;
    if (score >= 60) return AppTheme.warning;
    if (score > 0) return AppTheme.error;
    return Colors.grey;
  }

  String _getSrtLabel(double score) {
    if (score >= 80) return 'Uitstekend';
    if (score >= 60) return 'Stabiel';
    if (score >= 40) return 'Matig';
    if (score > 0) return 'Instabiel';
    return 'Nog geen data';
  }
}
