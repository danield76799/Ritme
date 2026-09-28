import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Mini-grafiek (sparkline) voor in een dashboardtegel.
///
/// Tekent een simpele lijn zonder assen of labels — puur de trend als
/// visuele hint onder de tegelwaarde. Kleur volgt de accentkleur van de
/// tegel; bij [toonNulLijn] wordt een subtiele horizontale nul-lijn
/// getekend (handig voor de SRM-schaal -5..+5).
class Sparkline extends StatelessWidget {
  /// Waarden in chronologische volgorde (oud → nieuw).
  final List<double> waarden;

  final Color kleur;

  /// Teken een gestippelde nul-lijn (alleen zinvol bij data rond nul).
  final bool toonNulLijn;

  /// Vaste y-range; bij null wordt de range uit de data genomen (met
  /// minimale padding zodat één vlakke lijn zichtbaar blijft).
  final double? minY;
  final double? maxY;

  const Sparkline({
    super.key,
    required this.waarden,
    required this.kleur,
    this.toonNulLijn = false,
    this.minY,
    this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    if (waarden.length < 2) {
      // Met minder dan 2 punten is er geen trend zichtbaar; leeg houden
      // zodat de tegelhoogte stabiel blijft.
      return const SizedBox(height: 28);
    }

    double effMinY = minY ?? waarden.reduce((a, b) => a < b ? a : b);
    double effMaxY = maxY ?? waarden.reduce((a, b) => a > b ? a : b);
    if (toonNulLijn) {
      effMinY = effMinY < 0 ? effMinY : -1.0;
      effMaxY = effMaxY > 0 ? effMaxY : 1.0;
    }
    if (effMaxY - effMinY < 0.5) {
      // Vlakke lijn: iets ruimte geven zodat hij niet tegen de rand plakt.
      effMinY -= 0.5;
      effMaxY += 0.5;
    }

    return SizedBox(
      height: 28,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (waarden.length - 1).toDouble(),
          minY: effMinY,
          maxY: effMaxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: toonNulLijn,
            drawVerticalLine: false,
            checkToShowHorizontalLine: (value) => value == 0,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18),
              strokeWidth: 1,
              dashArray: [3, 3],
            ),
          ),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (int i = 0; i < waarden.length; i++)
                  FlSpot(i.toDouble(), waarden[i]),
              ],
              isCurved: true,
              // Korte series (7 punten) mogen zacht buigen; geen echte
              // extrapolatie — preventOverzoom/keep van fl_chart doet dat
              // standaard niet, maar isCurved met lage tension wel beperken.
              curveSmoothness: 0.2,
              preventCurveOverShooting: true,
              color: kleur,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: kleur.withValues(alpha: 0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}