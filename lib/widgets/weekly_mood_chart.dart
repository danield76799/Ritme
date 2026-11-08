import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../generated/l10n/app_localizations.dart';

/// Stemming-trend met periodekiezer (7 of 14 dagen).
///
/// De kiezer staat in de kaartkop zodat één tik de grafiek omzet zonder
/// dat het dashboard opnieuw hoeft te laden: alle data komt al binnen als
/// 14-dagen-venster uit [_loadData] van het dashboard.
class WeeklyMoodChart extends StatefulWidget {
  final List<Map<String, dynamic>> logs;

  const WeeklyMoodChart({super.key, required this.logs});

  @override
  State<WeeklyMoodChart> createState() => _WeeklyMoodChartState();
}

class _WeeklyMoodChartState extends State<WeeklyMoodChart> {
  /// Gekozen periode in unieke dagen. Standaard 7, want dat is wat het
  /// dashboard tot nu toe toonde — 14 dagen is een bewuste tik extra.
  int _selectedDays = 7;

  @override
  Widget build(BuildContext context) {
    if (widget.logs.isEmpty) {
      return _LegeStemmingKaart(
        height: 160,
        icon: Icons.show_chart,
        iconColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        title: AppLocalizations.of(context).nogGeenStemmingData,
        hint: AppLocalizations.of(context).voegMinimaal2LogsToe,
      );
    }

    // Need at least 2 data points for a meaningful trend line
    if (widget.logs.length < 2) {
      return _LegeStemmingKaart(
        height: 160,
        icon: Icons.trending_up,
        iconColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        title: AppLocalizations.of(context).eenLogOpgeslagen,
        hint: AppLocalizations.of(context).voegNogEenLogToe,
      );
    }

    // Prepare chart data - Life Chart 0-100 scale
    // Deduplicate by date - only show latest entry per unique date
    final Map<String, Map<String, dynamic>> uniqueLogsByDate = {};
    for (var log in widget.logs) {
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

    // Neem alleen de laatste [aantal] unieke dagen
    final recentLogs = deduplicatedLogs.length > _selectedDays
        ? deduplicatedLogs.sublist(deduplicatedLogs.length - _selectedDays)
        : deduplicatedLogs;

    final spots = <FlSpot>[];
    final titles = <String>[];

    for (int i = 0; i < recentLogs.length; i++) {
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

    // Bij 14 punten wordt elk label te krap: toon er dan de helft, maar
    // houd de laatste altijd zichtbaar zodat de meest recente dag klopt.
    final labelStap = recentLogs.length > 8 ? 2 : 1;

    final l10n = AppLocalizations.of(context);

    return Container(
      height: 200,
      padding: EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  recentLogs.length == 1
                      ? l10n.stemmingTrendDag
                      : l10n.stemmingTrendDagen(recentLogs.length),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Periodekiezer: compacte M3-segmented knoppen, zodat de kaart
              // blijft wat hij was en de grafiek de rest van de hoogte pakt.
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 7, label: Text(l10n.zevenDagen)),
                  ButtonSegment(value: 14, label: Text(l10n.veertienDagen)),
                ],
                selected: {_selectedDays},
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: WidgetStatePropertyAll(
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
                onSelectionChanged: (keuze) {
                  if (keuze.first != _selectedDays) {
                    setState(() => _selectedDays = keuze.first);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 2.5,
                  getDrawingHorizontalLine: (value) {
                    // De nul-lijn (neutraal) is de visueel belangrijkste
                    // rasterlijn: donkerder dan de rest.
                    final isNul = value == 0;
                    return FlLine(
                      color: isNul
                          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25)
                          : Colors.grey.withValues(alpha: 0.15),
                      strokeWidth: isNul ? 1.5 : 1,
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
                        // Alleen bij integer posities tonen (half-integers
                        // als 0.5, 1.5 etc. moeten geen label tonen — anders
                        // wordt dezelfde datum meerdere keren weergegeven).
                        if (value % 1 != 0) return const Text('');
                        final index = value.toInt();
                        if (index < 0 || index >= titles.length) {
                          return const Text('');
                        }
                        final toonLabel =
                            index % labelStap == 0 || index == titles.length - 1;
                        if (!toonLabel) return const Text('');
                        return Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            titles[index],
                            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                          ),
                        );
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
                        if (value == -5 || value == 5) return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
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
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: _getStemmingKleur(spot.y, context),
                          strokeWidth: 2,
                          strokeColor: Theme.of(context).colorScheme.onPrimary,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).colorScheme.primary.withAlpha(100),
                          Theme.of(context).colorScheme.primary.withAlpha(10),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) {
                      return Theme.of(context).colorScheme.surface;
                    },
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        // Schaal is -5..+5; toon datum + waarde met teken.
                        // De oude "/100"-tooltip stamde uit de 0-100-tijd en
                        // klopte niet meer met de SRM-schaal.
                        final idx = spot.x.toInt();
                        final datum = (idx >= 0 && idx < titles.length) ? '${titles[idx]}  ' : '';
                        final y = spot.y;
                        final teken = y > 0 ? '+' : (y < 0 ? '−' : '');
                        final afgerond = y.abs() == y.roundToDouble()
                            ? y.abs().toInt().toString()
                            : y.abs().toStringAsFixed(1);
                        return LineTooltipItem(
                          '$datum$teken$afgerond',
                          TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
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

  Color _getStemmingKleur(double waarde, BuildContext context) {
    // Use theme-aware colors with safe fallbacks (no null assertions)
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (waarde <= -4) return isDark ? Colors.grey.shade400 : Colors.grey.shade800;
    if (waarde <= -3) return isDark ? Colors.grey.shade500 : Colors.grey.shade700;
    if (waarde <= -2) return isDark ? Colors.blue.shade400 : Colors.blue.shade300;
    if (waarde <= -1) return isDark ? Colors.blue.shade200 : Colors.blue.shade100;
    if (waarde == 0) return isDark ? Colors.green.shade400 : Colors.green.shade600;
    if (waarde <= 1) return isDark ? Colors.yellow.shade700 : Colors.yellow.shade600;
    if (waarde <= 2) return isDark ? Colors.orange.shade400 : Colors.orange.shade600;
    if (waarde <= 3) return isDark ? Colors.orange.shade700 : Colors.orange.shade800;
    if (waarde <= 4) return isDark ? Colors.red.shade300 : Colors.red.shade500;
    return isDark ? Colors.red.shade400 : Colors.red.shade600;
  }
}

/// Lege/een-log staat van de stemmingtrend: zelfde kaartstijl, zonder grafiek
/// en zonder periodekiezer (die heeft zonder data geen zin).
class _LegeStemmingKaart extends StatelessWidget {
  final double height;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String hint;

  const _LegeStemmingKaart({
    required this.height,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: iconColor),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                hint,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
