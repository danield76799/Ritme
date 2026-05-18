import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';

class WeeklyMoodChart extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  
  const WeeklyMoodChart({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(
        child: Text(
          'Geen data beschikbaar',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Prepare chart data
    final spots = <FlSpot>[];
    final titles = <String>[];
    
    for (int i = 0; i < logs.length && i < 7; i++) {
      final log = logs[i];
      final stemming = log['stemming_ochtend'] as int? ?? 0;
      // Convert -5..5 to 0..10 for display
      final value = stemming + 5;
      spots.add(FlSpot(i.toDouble(), value.toDouble()));
      
      final date = log['date'] as String? ?? '';
      if (date.isNotEmpty) {
        final parts = date.split('-');
        if (parts.length >= 3) {
          titles.add('${parts[2]}/${parts[1]}');
        }
      }
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? AppTheme.darkCard 
            : Colors.white,
        elevation: 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stemming Trend (7 dagen)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < titles.length) {
                          return Text(
                            titles[index],
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 2,
                      getTitlesWidget: (value, meta) {
                        // Convert 0..10 back to -5..5
                        final moodValue = value.toInt() - 5;
                        String label;
                        if (moodValue <= -3) label = '😢';
                        else if (moodValue <= -1) label = '😕';
                        else if (moodValue <= 1) label = '😐';
                        else if (moodValue <= 3) label = '🙂';
                        else label = '😄';
                        return Text(label, style: const TextStyle(fontSize: 12));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: spots.length - 1.0,
                minY: 0,
                maxY: 10,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primaryTeal,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppTheme.primaryTeal,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primaryTeal.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
