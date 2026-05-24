import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../service_locator.dart';

class SleepDetailScreen extends StatefulWidget {
  const SleepDetailScreen({super.key});

  @override
  State<SleepDetailScreen> createState() => _SleepDetailScreenState();
}

class _SleepDetailScreenState extends State<SleepDetailScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _sleepData = [];
  double _avgSleep = 0;
  double _bestSleep = 0;
  double _worstSleep = 0;
  int _daysTracked = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final dailyLogs = await db.getDailyLogs();
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      
      List<Map<String, dynamic>> sleepEntries = [];
      double totalSleep = 0;
      double best = 0;
      double worst = double.infinity;
      int count = 0;

      for (var log in dailyLogs) {
        if (log['date'] == null) continue;
        
        // DEBUG: Log alle rijen voor debugging
        print('DEBUG sleep_detail: date=${log['date']}, id=${log['id']}, sleep_hours=${log['sleep_hours']}, uren_slaap=${log['uren_slaap']}, awake_minutes=${log['awake_minutes']}, bed_time=${log['bed_time']}, wake_time=${log['wake_time']}');
        
        try {
          final logDate = DateTime.parse(log['date'] as String);
          if (logDate.isBefore(weekAgo)) continue;

          // Skip if we already have an entry for this date (take the first/latest one)
          if (sleepEntries.any((e) => e['date'] == log['date'])) continue;

          double? sleep;
          final rawSleep = log['sleep_hours'];
          final rawUren = log['uren_slaap'];
          final rawAwake = log['awake_minutes'];
          int awakeMinutes = 0;
          if (rawAwake != null) {
            if (rawAwake is num) awakeMinutes = rawAwake.toInt();
            else if (rawAwake is String) awakeMinutes = int.tryParse(rawAwake) ?? 0;
          }
          
          // EERST kijken naar sleep_hours (van slaap tracking - al correct berekend)
          if (rawSleep != null) {
            if (rawSleep is num) sleep = rawSleep.toDouble();
            else if (rawSleep is String) sleep = double.tryParse(rawSleep);
          }
          // Dan kijken naar uren_slaap (van mood tracking - moeten awake_minutes aftrekken)
          if (sleep == null && rawUren != null) {
            if (rawUren is num) sleep = rawUren.toDouble();
            else if (rawUren is String) sleep = double.tryParse(rawUren);
            
            // Trek awake_minutes af voor uren_slaap (niet voor sleep_hours)
            if (sleep != null && sleep > 0 && awakeMinutes > 0) {
              final awakeHours = awakeMinutes / 60.0;
              sleep = sleep - awakeHours;
              if (sleep < 0) sleep = 0;
            }
          }
          
          // Alleen toevoegen als we geldige sleep data hebben
          if (sleep != null && sleep > 0) {
            sleepEntries.add({
              'date': log['date'],
              'sleep': sleep,
              'day': _dayName(logDate.weekday),
              'dateShort': '${logDate.day}/${logDate.month}',
              'awakeMinutes': awakeMinutes,  // Toon ook wakker tijd
            });
            totalSleep += sleep;
            if (sleep > best) best = sleep;
            if (sleep < worst) worst = sleep;
            count++;
          }
        } catch (e) {
          continue;
        }
      }

      setState(() {
        _sleepData = sleepEntries;
        _avgSleep = count > 0 ? totalSleep / count : 0;
        _bestSleep = best;
        _worstSleep = worst == double.infinity ? 0 : worst;
        _daysTracked = count;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _dayName(int weekday) {
    const days = ['', 'Ma', 'Di', 'Wo', 'Do', 'Vr', 'Za', 'Zo'];
    return days[weekday];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        title: const Text(
          'Slaap Details (Netto)',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppTheme.primaryTeal,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats cards
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Gemiddeld', '${_avgSleep.toStringAsFixed(1)}u', Icons.trending_flat)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Beste', '${_bestSleep.toStringAsFixed(1)}u', Icons.trending_up)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Minste', '${_worstSleep.toStringAsFixed(1)}u', Icons.trending_down)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Sleep chart
                    if (_sleepData.isNotEmpty) ...[
                      const Text(
                        'Slaap per dag (laatste 7 dagen)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textCharcoal,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 220,
                        padding: const EdgeInsets.all(16),
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
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: 12,
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final data = _sleepData[groupIndex];
                                  return BarTooltipItem(
                                    '${data['sleep'].toStringAsFixed(1)}u\n${data['dateShort']}',
                                    const TextStyle(color: Colors.white, fontSize: 12),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() >= 0 && value.toInt() < _sleepData.length) {
                                      return Text(
                                        _sleepData[value.toInt()]['day'],
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      );
                                    }
                                    return const Text('');
                                  },
                                  reservedSize: 30,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval: 4,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      '${value.toInt()}u',
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    );
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 4,
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: _sleepData.asMap().entries.map((entry) {
                              return BarChartGroupData(
                                x: entry.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: entry.value['sleep'].toDouble(),
                                    color: entry.value['sleep'] >= 7 
                                        ? AppTheme.primaryTeal 
                                        : entry.value['sleep'] >= 5 
                                            ? Colors.orange 
                                            : Colors.redAccent,
                                    width: 20,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Sleep log list
                    const Text(
                      'Slaap logboek',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textCharcoal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (_sleepData.isEmpty)
                      _buildEmptyState('Geen slaapdata gevonden', 'Voeg slaapuren toe bij je dagelijkse log.')
                    else
                      ..._sleepData.reversed.map((entry) => _buildSleepLogItem(entry)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryTeal, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textCharcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepLogItem(Map<String, dynamic> entry) {
    final sleep = entry['sleep'] as double;
    final awakeMinutes = entry['awakeMinutes'] as int? ?? 0;
    final quality = sleep >= 8 ? 'Uitstekend' : sleep >= 6 ? 'Goed' : sleep >= 5 ? 'Matig' : 'Slecht';
    final qualityColor = sleep >= 8 ? AppTheme.primaryTeal : sleep >= 6 ? Colors.green : sleep >= 5 ? Colors.orange : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
              color: qualityColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              sleep >= 6 ? Icons.bedtime : Icons.bedtime_off,
              color: qualityColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry['day']} ${entry['dateShort']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.textCharcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$quality (${awakeMinutes}m wakker)',
                  style: TextStyle(
                    fontSize: 14,
                    color: qualityColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${sleep.toStringAsFixed(1)}u',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textCharcoal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.nightlight_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
