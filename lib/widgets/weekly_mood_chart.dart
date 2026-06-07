import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';

class WeeklyMoodChart extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  
  const WeeklyMoodChart({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Container(
        height: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.show_chart,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'Nog geen stemming data',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Voeg minimaal 2 logs toe om een trend te zien',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Need at least 2 data points for a meaningful trend line
    if (logs.length < 2) {
      return Container(
        height: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.trending_up,
                size: 48,
                color: AppTheme.primaryTeal.withOpacity(0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Eén log opgeslagen!',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Voeg nog één log toe voor een trendlijn',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Prepare chart data - Life Chart 0-100 scale
    // Deduplicate by date - only show latest entry per unique date
    final Map<String, Map<String, dynamic>> uniqueLogsByDate = {};
    for (var log in logs) {
      final date = log['date'] as String? ?? '';
      if (date.isNotEmpty) {
        // Always keep the latest entry for each date (first in DESC ordered list)
        if (!uniqueLogsByDate.containsKey(date)) {
          uniqueLogsByDate[date] = log;
        }
      }
    }
    final deduplicatedLogs = uniqueLogsByDate.values.toList();
    
    // Sort by date to ensure chronological order
    deduplicatedLogs.sort((a, b) {
      final dateA = a['date'] as String? ?? '';
      final dateB = b['date'] as String? ?? '';
      return dateA.compareTo(dateB);
    });
    
    // Take only last 7 unique dates
    final recentLogs = deduplicatedLogs.length > 7 
        ? deduplicatedLogs.sublist(deduplicatedLogs.length - 7) 
        : deduplicatedLogs;
    
    final spots = <FlSpot>[];
    final titles = <String>[];
    
    for (int i = 0; i < recentLogs.length && i < 7; i++) {
      final log = recentLogs[i];
      // SRM Methode: stemming -5 tot +5
      // Converteer oude 0-100 waarden naar nieuwe schaal
      final dynamic rawStemming = log['stemming_hoog'];
      double value;
      if (rawStemming is num) {
        value = rawStemming.toDouble();
      } else if (rawStemming is String) {
        value = double.tryParse(rawStemming) ?? 0.0;
      } else {
        value = 0.0;
      }
      // Converteer oude 0-100 waarden naar -5..+5
      if (value > 5 || value < -5) {
        value = (value - 50) / 10;
      }
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
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recentLogs.length == 1 
                ? 'Stemming Trend (1 dag)'
                : 'Stemming Trend (${recentLogs.length} dagen)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
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
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        // Only show title for exact data point indices, and only if we have that title
                        if (index >= 0 && index < titles.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              titles[index],
                              style: const TextStyle(fontSize: 10, color: Colors.black87),
                            ),
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
                        // SRM -5 tot +5 labels
                        if (value == 0) return const Text('0', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold));
                        if (value == -5 || value == 5) return Text('${value.toInt()}', style: const TextStyle(fontSize: 10));
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
                minY: -5,
                maxY: 5,
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
    if (waarde <= -4) return Colors.grey.shade800!;     // Uiterst depressief
    if (waarde <= -3) return Colors.black!;      // Ernstig depressief
    if (waarde <= -2) return Colors.blue[400]!;      // Matig depressief
    if (waarde <= -1) return Colors.blue[200]!;      // Licht depressief
    if (waarde == 0) return Colors.green[400]!;       // Neutraal
    if (waarde <= 1) return Colors.yellow[600]!;     // Licht manisch
    if (waarde <= 2) return Colors.orange[500]!;     // Matig manisch
    if (waarde <= 3) return Colors.orange[700]!;     // Druk / Actief
    if (waarde <= 4) return Colors.red[400]!;        // Ernstig manisch
    return Colors.red[600]!;                          // Uiterst manisch
  }
}