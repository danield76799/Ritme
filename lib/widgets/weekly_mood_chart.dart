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

    // Prepare chart data - Life Chart 0-100 scale
    final spots = <FlSpot>[];
    final titles = <String>[];
    
    for (int i = 0; i < logs.length && i < 7; i++) {
      final log = logs[i];
      // Life Chart: stemming_hoog (0-100)
      final stemming = log['stemming_hoog'] as double? ?? log['stemming_hoog'] as int? ?? 50;
      final value = stemming.toDouble();
      spots.add(FlSpot(i.toDouble(), value));
      
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
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.15),
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
                      interval: 20,
                      getTitlesWidget: (value, meta) {
                        // Life Chart 0-100 labels
                        if (value == 50) return const Text('50', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold));
                        if (value == 0 || value == 100) return Text('${value.toInt()}', style: const TextStyle(fontSize: 10));
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: -0.5,
                maxX: spots.length - 0.5,
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primaryTeal,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: _getStemmingKleur(spot.y),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.primaryTeal.withAlpha(100),
                          AppTheme.primaryTeal.withAlpha(10),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) {
                      return Colors.black87;
                    },
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toInt()}/100',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStemmingKleur(double waarde) {
    if (waarde <= 10) return Colors.grey[800]!;     // Uiterst depressief
    if (waarde <= 25) return Colors.grey[600]!;      // Ernstig depressief
    if (waarde <= 40) return Colors.blue[400]!;      // Matig depressief
    if (waarde <= 45) return Colors.blue[200]!;      // Licht depressief
    if (waarde <= 55) return Colors.green[400]!;      // Neutraal
    if (waarde <= 65) return Colors.yellow[600]!;     // Licht manisch
    if (waarde <= 75) return Colors.orange[500]!;     // Matig manisch
    if (waarde <= 90) return Colors.orange[700]!;     // Ernstig manisch
    return Colors.red[500]!;                          // Uiterst manisch
  }
}