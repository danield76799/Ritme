import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../service_locator.dart';
import '../utils/logger.dart';
import '../generated/l10n/app_localizations.dart';

class StatistiekenScherm extends StatefulWidget {
  @override
  _StatistiekenSchermState createState() => _StatistiekenSchermState();
}

class _StatistiekenSchermState extends State<StatistiekenScherm> {




  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  // KPIs
  double _gemStemming = 0.0;
  double _gemSlaap = 0.0;
  int _aantalActiviteiten = 0;

  // Format hours as "9u 30m" instead of "9.5u"
  String _formatHours(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h > 0 && m > 0) return '${h}u ${m}m';
    if (h > 0) return '${h}u';
    return '${m}m';
  }

  @override
  void initState() {
    super.initState();
    _laadData();
  }

  Future<void> _laadData() async {
    try {
      final logs = await db.getDailyLogs();

      // Bereken KPIs
      if (logs.isNotEmpty) {
        double totaalStemming = 0;
        double totaalSlaap = 0;
        int stemCount = 0;
        int sleepCount = 0;

        for (var log in logs) {
          if (log['stemming_hoog'] != null) {
            final dynamic rawStemming = log['stemming_hoog'];
            double stemming = 0;
            if (rawStemming is num) {
              stemming = rawStemming.toDouble();
            } else if (rawStemming is String) {
              stemming = double.tryParse(rawStemming) ?? 0.0;
            }
            totaalStemming += stemming;
            stemCount++;
          }
          
          // Check sleep_hours first (calculated from sleep tracking)
          if (log['sleep_hours'] != null) {
            final sleepVal = log['sleep_hours'] is num ? log['sleep_hours'].toDouble() : double.tryParse(log['sleep_hours'].toString()) ?? 0.0;
            if (sleepVal > 0) {
              totaalSlaap += sleepVal;
              sleepCount++;
            }
          } else if (log['uren_slaap'] != null) {
            final dynamic rawSlaap = log['uren_slaap'];
            double slaap = 0;
            if (rawSlaap is num) {
              slaap = rawSlaap.toDouble();
            } else if (rawSlaap is String) {
              slaap = double.tryParse(rawSlaap) ?? 0.0;
            }
            if (slaap > 0) {
              totaalSlaap += slaap;
              sleepCount++;
            }
          }
        }

        // Converteer stemming naar -5 tot +5 schaal
        double rawGemStemming = stemCount > 0 ? totaalStemming / stemCount : 0.0;
        if (rawGemStemming > 10) {
          // 0-100 schaal, converteer naar -5 tot +5
          _gemStemming = ((rawGemStemming / 100) * 10 - 5).clamp(-5.0, 5.0);
        } else {
          // Al op -5 tot +5 schaal
          _gemStemming = rawGemStemming.clamp(-5.0, 5.0);
        }
        
        // Slaap: alleen delen door dagen MET slaapdata
        _gemSlaap = sleepCount > 0 ? totaalSlaap / sleepCount : 0.0;
      }

      // Ophalen van totaal aantal opgeslagen SRM activiteiten
      int actCount = 0;
      for (var log in logs) {
        try {
          final acts = await db.getSrmActivities(log['date']);
          actCount += acts.length;
        } catch (e) {
          // Skip logs with database errors
        }
      }

      if (mounted) {
        setState(() {
          _logs = logs.reversed.toList();
          _aantalActiviteiten = actCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('ERROR loading statistics', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _logs = [];
        });
      }
    }
  }

  Future<void> _genereerEnDeelPdf() async {
    // PDF functionaliteit tijdelijk uitgeschakeld wegens dependency conflict
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).pdfExportTijdelijkBeschikbaar),
        backgroundColor: Colors.orange,
      ),
    );
  }
  
  // PDF helper functies tijdelijk uitgeschakeld
  /*
  pw.Widget _buildKpiRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
        ],
      ),
    );
  }
  
  pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          fontSize: 11,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
  
  pw.Widget _buildTableCell(String text) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        title: Text(AppLocalizations.of(context).statistiekenLifeChart, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _genereerEnDeelPdf,
            tooltip: AppLocalizations.of(context).exporteerAlsPdf,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bouwStemmingGrafiek(),
                    SizedBox(height: 16),
                    _bouwSlaapGrafiek(),
                    SizedBox(height: 32),
                    Text(AppLocalizations.of(context).samenvatting, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textCharcoal)),
                    SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      children: [
                        _bouwKpiKaart(_gemStemming.toStringAsFixed(1), AppLocalizations.of(context).gemStemming, Colors.orange),
                        _bouwKpiKaart(_formatHours(_gemSlaap), AppLocalizations.of(context).gemSlaap, Colors.blue),
                        _bouwKpiKaart('$_aantalActiviteiten', AppLocalizations.of(context).activiteitenGelogd, Colors.green),
                      ],
                    ),
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // --- LIFE CHART: STEMMING (Lijngrafiek) ---
  Widget _bouwStemmingGrafiek() {
    if (_logs.isEmpty) return _bouwLegePlaceholder('Stemming');

    List<FlSpot> spots = [];
    for (int i = 0; i < _logs.length; i++) {
      if (_logs[i]['stemming_hoog'] != null) {
        dynamic rawStemming = _logs[i]['stemming_hoog'];
        double stemming;
        if (rawStemming is num) {
          stemming = rawStemming.toDouble();
        } else if (rawStemming is String) {
          stemming = double.tryParse(rawStemming) ?? 0.0;
        } else {
          stemming = 0.0;
        }
        // Converteer naar -5 tot +5 schaal
        if (stemming > 10) {
          stemming = ((stemming / 100) * 10 - 5).clamp(-5.0, 5.0);
        } else {
          stemming = stemming.clamp(-5.0, 5.0);
        }
        spots.add(FlSpot(i.toDouble(), stemming));
      }
    }

    if (spots.isEmpty) return _bouwLegePlaceholder('Stemming');

    return _bouwGrafiekKaart(
      titel: 'Stemming (-5 tot +5)',
      child: LineChart(
        LineChartData(
          minY: -5,
          maxY: 5,
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.orange,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.orange,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.orange.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SLAAP (Staafgrafiek) ---
  Widget _bouwSlaapGrafiek() {
    if (_logs.isEmpty) return _bouwLegePlaceholder('Slaap (uren)');

    List<BarChartGroupData> barGroups = [];
    int dataCount = 0;
    for (int i = 0; i < _logs.length; i++) {
      double? slaapUren;
      
      // Check sleep_hours first
      if (_logs[i]['sleep_hours'] != null) {
        dynamic rawSleep = _logs[i]['sleep_hours'];
        if (rawSleep is num) slaapUren = rawSleep.toDouble();
        else if (rawSleep is String) slaapUren = double.tryParse(rawSleep);
      } else if (_logs[i]['uren_slaap'] != null) {
        dynamic rawSlaap = _logs[i]['uren_slaap'];
        if (rawSlaap is num) slaapUren = rawSlaap.toDouble();
        else if (rawSlaap is String) slaapUren = double.tryParse(rawSlaap);
      }
      
      if (slaapUren != null && slaapUren > 0) {
        barGroups.add(
          BarChartGroupData(
            x: dataCount++,
            barRods: [
              BarChartRodData(
                toY: slaapUren.clamp(0.0, 12.0),
                color: Colors.blue,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              )
            ],
          ),
        );
      }
    }

    if (barGroups.isEmpty) return _bouwLegePlaceholder('Slaap (uren)');

    return _bouwGrafiekKaart(
      titel: 'Slaap (uren)',
      child: BarChart(
        BarChartData(
          maxY: 12,
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
        ),
      ),
    );
  }

  // --- HULP WIDGETS ---

  Widget _bouwGrafiekKaart({required String titel, required Widget child}) {
    return Container(
      width: double.infinity,
      height: 250,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textCharcoal)),
          SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _bouwLegePlaceholder(String titel) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textCharcoal)),
          SizedBox(height: 24),
          Center(child: Text(AppLocalizations.of(context).nogGeenDataBeschikbaar, style: TextStyle(color: Colors.black))),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _bouwKpiKaart(String waarde, String label, Color accentKleur) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(waarde, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: accentKleur)),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}


