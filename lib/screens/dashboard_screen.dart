import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../service_locator.dart';
import '../services/notification_helper.dart';
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
  
  // Dynamische data voor overview
  double _sleepQuality = 0.0;
  double _rhythmStability = 0.0;
  int _weeklyActivities = 0;
  DateTime? _lastUpdated;
  List<Map<String, dynamic>> _weeklyLogs = [];

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
      // Reload when app comes to foreground
      _loadData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload when returning from another screen (e.g. Settings)
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final settings = await db.getSettings();
      
      // Haal echte data op uit de database
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      // Haal alle dagelijkse logs op
      final dailyLogs = await db.getDailyLogs();
      
      // Bereken slaapkwaliteit (gemiddelde van laatste 7 dagen)
      double totalSleep = 0;
      int sleepCount = 0;
      int activityCount = 0;
      
      for (var log in dailyLogs) {
        final logDate = DateTime.parse(log['date'] as String);
        
        if (logDate.isAfter(weekAgo)) {
          // Tel activiteiten
          if (log['activity_type'] != null) {
            activityCount++;
          }
          
          // Slaapkwaliteit
          final sleep = log['uren_slaap'] as double?;
          if (sleep != null && sleep > 0) {
            totalSleep += sleep;
            sleepCount++;
          }
        }
      }
      
      // Bereken gemiddelden
      final avgSleep = sleepCount > 0 ? totalSleep / sleepCount : 0;
      // Slaapkwaliteit score: 0-10 (8 uur = 10, minder = lager)
      final sleepScore = avgSleep > 0 ? ((avgSleep / 8) * 10).clamp(0, 10) : 0;
      
      // Ritme stabiliteit: percentage geplande vs daadwerkelijke activiteiten
      final srmActivities = await db.getSrmActivities(todayStr);
      int onTimeCount = 0;
      for (var activity in srmActivities) {
        if (activity['actual_time'] != null && activity['p_score'] != null && activity['p_score'] as int >= 3) {
          onTimeCount++;
        }
      }
      final stability = srmActivities.isNotEmpty ? (onTimeCount / srmActivities.length * 100) : 0;

      // Get weekly logs for chart
      final weeklyLogs = dailyLogs.where((log) {
        if (log['date'] == null) return false;
        try {
          final logDate = DateTime.parse(log['date'] as String);
          return logDate.isAfter(weekAgo) || logDate.isAtSameMomentAs(weekAgo);
        } catch (e) {
          return false;
        }
      }).toList();

      setState(() {
        _settings = settings;
        _sleepQuality = sleepScore.toDouble();
        _rhythmStability = stability.toDouble();
        _weeklyActivities = activityCount;
        _weeklyLogs = weeklyLogs;
        _lastUpdated = DateTime.now();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
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
    if (hour < 12) {
      return 'Goedemorgen, $name!';
    } else if (hour < 17) {
      return 'Goedemiddag, $name!';
    } else if (hour < 21) {
      return 'Goedenavond, $name!';
    } else {
      return 'Goedenacht, $name!';
    }
  }

  String _formatLastUpdated() {
    if (_lastUpdated == null) return '';
    final now = DateTime.now();
    final diff = now.difference(_lastUpdated!);
    
    if (diff.inSeconds < 60) {
      return 'Zojuist bijgewerkt';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min geleden bijgewerkt';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} uur geleden bijgewerkt';
    } else {
      return '${diff.inDays} dagen geleden bijgewerkt';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryTeal),
        ),
      );
    }

    final today = DateTime.now();
    final dateStr = '${today.day}/${today.month}/${today.year}';
    final username = _settings?['username']?.toString() ?? 'gebruiker';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        title: const Text(
          'Ritme',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/statistics');
            },
            tooltip: 'Statistieken',
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () async {
              await Navigator.pushNamed(context, '/settings');
              // Reload settings when returning from settings screen
              _loadData();
            },
            tooltip: 'Instellingen',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Uitloggen',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primaryTeal,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- WELKOMST BANNER ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryTeal, AppTheme.primaryTeal.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _getGreeting(username),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildTimeChip(Icons.wb_sunny_outlined, 'Opstaan', _settings?['target_opstaan'] ?? '08:00'),
                          _buildTimeChip(Icons.nightlight_round, 'Slapen', _settings?['target_slapen'] ?? '23:00'),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 28),
                
                // --- VANDAAG SECTIE ---
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Vandaag',
                      style: TextStyle(
                        color: AppTheme.textCharcoal,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Grid met de 4 knoppen
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  shrinkWrap: true,
                  childAspectRatio: 1.15,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildActionCard(
                      context, 
                      icon: Icons.sentiment_satisfied_alt, 
                      iconColor: Colors.orange, 
                      title: 'Stemming', 
                      route: '/mood',
                    ),
                    _buildActionCard(
                      context, 
                      icon: Icons.directions_walk, 
                      iconColor: Colors.green, 
                      title: 'Activiteit + Slaap', 
                      route: '/activity',
                    ),
                    _buildMedicatieCard(context),
                    _buildActionCard(
                      context, 
                      icon: Icons.monitor_weight, 
                      iconColor: Colors.blueAccent, 
                      title: 'Gewicht', 
                      route: '/weight',
                    ),
                    _buildActionCard(
                      context, 
                      icon: Icons.calendar_today_outlined, 
                      iconColor: Colors.purpleAccent, 
                      title: 'Afspraken', 
                      route: '/appointments',
                    ),
                    _buildActionCard(
                      context, 
                      icon: Icons.schedule, 
                      iconColor: Colors.teal, 
                      title: 'Sociaal Ritme', 
                      route: '/sociaal-ritme',
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // --- OVERZICHT SECTIE ---
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Overzicht',
                            style: TextStyle(
                              color: AppTheme.textCharcoal,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_lastUpdated != null)
                            Text(
                              _formatLastUpdated(),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                _buildOverviewCard(
                  icon: Icons.show_chart,
                  title: 'Slaapkwaliteit',
                  value: _sleepQuality > 0 ? _sleepQuality.toStringAsFixed(1) : '-',
                  unit: '/10',
                  color: Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildOverviewCard(
                  icon: Icons.schedule,
                  title: 'Ritme stabiliteit',
                  value: _rhythmStability > 0 ? _rhythmStability.round().toString() : '-',
                  unit: '%',
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
                _buildOverviewCard(
                  icon: Icons.local_activity,
                  title: 'Activiteiten deze week',
                  value: _weeklyActivities > 0 ? _weeklyActivities.toString() : '-',
                  unit: '',
                  color: Colors.orange,
                ),
                const SizedBox(height: 24),
                
                // --- WEEKLY MOOD CHART ---
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Stemming Trend',
                      style: TextStyle(
                        color: AppTheme.textCharcoal,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                WeeklyMoodChart(
                  logs: _weeklyLogs,
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  icon: Icons.insights,
                  iconColor: Colors.teal,
                  title: 'Inzichten & Patronen',
                  route: '/insights',
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, '/event');
          _loadData();
        },
        backgroundColor: AppTheme.primaryTeal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Log Toevoegen',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTimeChip(IconData icon, String label, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            '$label: $time',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String route,
  }) {
    return GestureDetector(
      onTap: () async {
        await Navigator.pushNamed(context, route);
        _loadData();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.textCharcoal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicatieCard(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.pushNamed(context, '/medication');
        _loadData();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.medication_outlined, color: Colors.redAccent, size: 36),
              ),
              const SizedBox(height: 12),
              Text(
                'Medicatie',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.textCharcoal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard({
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    text: value,
                    style: TextStyle(
                      color: AppTheme.textCharcoal,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(
                        text: ' $unit',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 18),
        ],
      ),
    );
  }

  void _showNotImplemented(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Binnenkort beschikbaar'),
        content: Text('$feature wordt in een volgende update toegevoegd.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppTheme.primaryTeal)),
          ),
        ],
      ),
    );
  }
}