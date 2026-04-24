import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../main.dart';

class StatistiekenScherm extends StatefulWidget {
  @override
  _StatistiekenSchermState createState() => _StatistiekenSchermState();
}

class _StatistiekenSchermState extends State<StatistiekenScherm> {
  final Color primaryTeal = const Color(0xFF4FB2C1);
  final Color textCharcoal = const Color(0xFF333333);
  final Color backgroundColor = const Color(0xFFFAFAFA);

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
    final logs = await db.getDailyLogs();

    // Bereken KPIs
    if (logs.isNotEmpty) {
      double totaalStemming = 0;
      double totaalSlaap = 0;
      int logCount = 0;

      for (var log in logs) {
        if (log['stemming_ochtend'] != null) {
          totaalStemming += log['stemming_ochtend'];
          logCount++;
        }
        if (log['uren_slaap'] != null) totaalSlaap += log['uren_slaap'];
      }

      _gemStemming = logCount > 0 ? totaalStemming / logCount : 0.0;
      _gemSlaap = logs.length > 0 ? totaalSlaap / logs.length : 0.0;
    }

    // Ophalen van totaal aantal opgeslagen SRM activiteiten en Life Events
    int actCount = 0;
    int eventCount = 0;
    for (var log in logs) {
      final acts = await db.getSrmActivities(log['date']);
      final events = await db.getLifeEvents(log['date']);
      actCount += acts.length;
      eventCount += events.length;
    }

    setState(() {
      _logs = logs.reversed.toList();
      _aantalActiviteiten = actCount;
      _aantalGebeurtenissen = eventCount;
      _isLoading = false;
    });
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Header(
              level: 0,
              child: pw.Text('Ritme - Life Chart Export',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Samenvatting',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              data: [
                ['Metric', 'Waarde'],
                ['Gemiddelde stemming', _gemStemming.toStringAsFixed(2)],
                ['Gemiddelde slaap (uren)', _gemSlaap.toStringAsFixed(2)],
                ['Activiteiten gelogd', '$_aantalActiviteiten'],
                ['Gebeurtenissen', '$_aantalGebeurtenissen'],
                ['Totale dagen tracking', '${_logs.length}'],
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('Laatste 7 dagen stemming:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Datum', 'Stemming', 'Slaap (uren)'],
              data: _logs.take(7).map((log) => [
                log['date'] ?? '-',
                '${log['stemming_ochtend'] ?? log['stemming_avond'] ?? '-' }',
                '${log['uren_slaap'] ?? '-' }',
              ]).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Geexporteerd op: ${DateTime.now().toString().split('.')[0]}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ],
        ),
      ),
    );

    // Share the PDF
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'ritme_lifechart_${DateTime.now().toIso8601String().split('T')[0]}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryTeal,
        elevation: 0,
        title: Text('Statistieken (Life Chart)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportPdf,
            tooltip: 'Exporteer als PDF',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryTeal))
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
                    Text('Samenvatting', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textCharcoal)),
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
      if (_logs[i]['stemming_ochtend'] != null) {
        spots.add(FlSpot(i.toDouble(), _logs[i]['stemming_ochtend'].toDouble()));
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
                color: Colors.orange.withOpacity(0.1),
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
                toY: _logs[i]['uren_slaap'].toDouble(),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textCharcoal)),
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
          Text(titel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textCharcoal)),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: Offset(0, 4))],
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
