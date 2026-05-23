import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../service_locator.dart';
import '../theme/app_theme.dart';

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
  int _aantalGebeurtenissen = 0;

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

      // Ophalen van totaal aantal opgeslagen SRM activiteiten en Life Events
      int actCount = 0;
      int eventCount = 0;
      for (var log in logs) {
        try {
          final acts = await db.getSrmActivities(log['date']);
          final events = await db.getLifeEvents(log['date']);
          actCount += acts.length;
          eventCount += events.length;
        } catch (e) {
          // Skip logs with database errors
        }
      }

      if (mounted) {
        setState(() {
          _logs = logs.reversed.toList();
          _aantalActiviteiten = actCount;
          _aantalGebeurtenissen = eventCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('ERROR loading statistics: $e');
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
      const SnackBar(
        content: Text('PDF export tijdelijk niet beschikbaar'),
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
      padding: const pw.EdgeInsets.all(8),
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
      padding: const pw.EdgeInsets.all(8),
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        title: Text('Statistieken (Life Chart)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _genereerEnDeelPdf,
            tooltip: 'Exporteer als PDF',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bouwStemmingGrafiek(),
                    SizedBox(height: 16),
                    _bouwSlaapGrafiek(),
                    SizedBox(height: 32),
                    Text('Samenvatting', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textCharcoal)),
                    SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      children: [
                        _bouwKpiKaart(_gemStemming.toStringAsFixed(1), 'Gem. stemming', Colors.orange),
                        _bouwKpiKaart(_gemSlaap.toStringAsFixed(1), 'Gem. slaap (uren)', Colors.blue),
                        _bouwKpiKaart('$_aantalActiviteiten', 'Activiteiten gelogd', Colors.green),
                        _bouwKpiKaart('$_aantalGebeurtenissen', 'Gebeurtenissen', Colors.purple),
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
        spots.add(FlSpot(i.toDouble(), stemming));
      }
    }

    return _bouwGrafiekKaart(
      titel: 'Stemming (-5 tot +5)',
      child: LineChart(
        LineChartData(
          minY: -5,
          maxY: 5,
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
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
              barWidth: 4,
              dotData: FlDotData(show: true),
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
    if (_logs.isEmpty) return _bouwLegePlaceholder('Slaapkwaliteit');

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < _logs.length; i++) {
      if (_logs[i]['uren_slaap'] != null) {
        barGroups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: (() {
                  dynamic rawSlaap = _logs[i]['uren_slaap'];
                  if (rawSlaap is num) return rawSlaap.toDouble();
                  if (rawSlaap is String) return double.tryParse(rawSlaap) ?? 0.0;
                  return 0.0;
                })(),
                color: Colors.blue,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              )
            ],
          ),
        );
      }
    }

    return _bouwGrafiekKaart(
      titel: 'Slaap (uren)',
      child: BarChart(
        BarChartData(
          maxY: 12,
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
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
        color: Colors.white,
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textCharcoal)),
          SizedBox(height: 24),
          Center(child: Text('Nog geen data beschikbaar', style: TextStyle(color: Colors.grey[600]))),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _bouwKpiKaart(String waarde, String label, Color accentKleur) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(waarde, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: accentKleur)),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}


