import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/database_helper.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _db = DatabaseHelper.instance;
  final Color primaryTeal = const Color(0xFF4FB2C1);
  final Color textCharcoal = const Color(0xFF333333);
  final Color backgroundColor = const Color(0xFFFAFAFA);

  bool _isLoading = true;
  List<Map<String, dynamic>> _dailyLogs = [];
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final logs = await _db.getDailyLogs(limit: 30);
    final activities = await _db.getActivities(
      DateTime.now().toIso8601String().split('T')[0],
    );
    final events = await _db.getLifeEvents(limit: 50);

    setState(() {
      _dailyLogs = logs;
      _activities = activities;
      _events = events;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryTeal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Statistieken',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- GRAFIEKEN SECTIE ---
              _buildChartCard('Stemming', _buildMoodChart()),
              const SizedBox(height: 16),
              _buildChartCard('Slaapkwaliteit', _buildSleepChart()),
              const SizedBox(height: 16),
              _buildChartCard('Activiteiten', _buildActivityChart()),
              
              const SizedBox(height: 32),

              // --- SAMENVATTING SECTIE ---
              Text(
                'Samenvatting',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textCharcoal),
              ),
              const SizedBox(height: 16),
              
              // Grid voor de 4 KPI blokken
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                childAspectRatio: 1.8,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildKpiCard(_getAvgMood(), 'Gem. stemming', Colors.orange),
                  _buildKpiCard(_getAvgSleep(), 'Gem. slaap', Colors.blue),
                  _buildKpiCard(_activities.length.toString(), 'Activiteiten', Colors.green),
                  _buildKpiCard(_events.length.toString(), 'Gebeurtenissen', Colors.purple),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _getAvgMood() {
    final moodLogs = _dailyLogs.where((log) => log['mood_score'] != null).toList();
    if (moodLogs.isEmpty) return '0.0';
    final avg = moodLogs.map((log) => log['mood_score'] as int).reduce((a, b) => a + b) / moodLogs.length;
    return avg.toStringAsFixed(1);
  }

  String _getAvgSleep() {
    final sleepLogs = _dailyLogs.where((log) => log['sleep_quality'] != null).toList();
    if (sleepLogs.isEmpty) return '0.0';
    final avg = sleepLogs.map((log) => log['sleep_quality'] as int).reduce((a, b) => a + b) / sleepLogs.length;
    return avg.toStringAsFixed(1);
  }

  Widget _buildChartCard(String title, Widget chart) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textCharcoal),
          ),
          const SizedBox(height: 16),
          chart,
        ],
      ),
    );
  }

  Widget _buildMoodChart() {
    final moodData = _dailyLogs
        .where((log) => log['mood_score'] != null)
        .take(14)
        .toList()
        .reversed
        .toList();

    if (moodData.isEmpty) {
      return _buildEmptyChart();
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < moodData.length) {
                    final date = DateTime.parse(moodData[value.toInt()]['date']);
                    return Text(
                      '${date.day}/${date.month}',
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          minY: 1,
          maxY: 10,
          lineBarsData: [
            LineChartBarData(
              spots: moodData.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(),
                  (entry.value['mood_score'] as int).toDouble(),
                );
              }).toList(),
              isCurved: true,
              color: Colors.orange,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.orange.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepChart() {
    final sleepData = _dailyLogs
        .where((log) => log['sleep_quality'] != null)
        .take(14)
        .toList()
        .reversed
        .toList();

    if (sleepData.isEmpty) {
      return _buildEmptyChart();
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < sleepData.length) {
                    final date = DateTime.parse(sleepData[value.toInt()]['date']);
                    return Text(
                      '${date.day}/${date.month}',
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          minY: 0,
          maxY: 10,
          barGroups: sleepData.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: (entry.value['sleep_quality'] as int).toDouble(),
                  color: Colors.blue,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActivityChart() {
    final activityTypes = <String, int>{};
    for (final activity in _activities) {
      final type = activity['activity_type'] as String;
      activityTypes[type] = (activityTypes[type] ?? 0) + 1;
    }

    if (activityTypes.isEmpty) {
      return _buildEmptyChart();
    }

    final colors = [
      Colors.orange,
      Colors.green,
      Colors.red,
      Colors.purple,
      Colors.blue,
    ];

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: activityTypes.entries.toList().asMap().entries.map((entry) {
            final index = entry.key;
            final count = entry.value.value;
            final total = activityTypes.values.reduce((a, b) => a + b);
            final percentage = (count / total * 100).toStringAsFixed(1);

            return PieChartSectionData(
              color: colors[index % colors.length],
              value: count.toDouble(),
              title: '$percentage%',
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyChart() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'Nog geen data beschikbaar',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String value, String label, Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.bold, 
              color: accentColor
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12, 
              color: Colors.grey[600]
            ),
          ),
        ],
      ),
    );
  }
}