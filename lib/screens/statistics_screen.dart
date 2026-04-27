import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../service_locator.dart';

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

  Future<void> _genereerEnDeelPdf() async {
    final pdf = pw.Document();
    
    // Haal logs van afgelopen 30 dagen op
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    
    final allLogs = await db.getDailyLogs();
    final recentLogs = allLogs.where((log) {
      if (log['date'] == null) return false;
      try {
        final logDate = DateTime.parse(log['date']);
        return logDate.isAfter(thirtyDaysAgo) || logDate.isAtSameMomentAs(thirtyDaysAgo);
      } catch (e) {
        return false;
      }
    }).toList();
    
    // Bereken KPIs voor afgelopen 30 dagen
    double gemStemming30 = 0.0;
    double gemSlaap30 = 0.0;
    int logCount30 = 0;
    int eventCount30 = 0;
    
    if (recentLogs.isNotEmpty) {
      double totaalStemming = 0;
      double totaalSlaap = 0;
      int stemCount = 0;
      
      for (var log in recentLogs) {
        if (log['stemming_ochtend'] != null) {
          totaalStemming += log['stemming_ochtend'];
          stemCount++;
        }
        if (log['uren_slaap'] != null) totaalSlaap += log['uren_slaap'];
        
        final events = await db.getLifeEvents(log['date']);
        eventCount30 += events.length;
      }
      
      gemStemming30 = stemCount > 0 ? totaalStemming / stemCount : 0.0;
      gemSlaap30 = recentLogs.length > 0 ? totaalSlaap / recentLogs.length : 0.0;
      logCount30 = recentLogs.length;
    }
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Text(
              'Ritme App - Digitaal Life Chart Rapport',
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#4FB2C1'),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Gegenereerd op: ${now.day}-${now.month}-${now.year}',
              style: pw.TextStyle(
                fontSize: 14,
                color: PdfColors.grey600,
              ),
            ),
            pw.Divider(thickness: 2, color: PdfColor.fromHex('#4FB2C1')),
            pw.SizedBox(height: 20),
            
            // Sectie 1: KPI Samenvatting
            pw.Text(
              'KPI Samenvatting (Laatste 30 dagen)',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  _buildKpiRow('Gemiddelde stemming', gemStemming30.toStringAsFixed(2)),
                  _buildKpiRow('Gemiddelde slaap (uren)', gemSlaap30.toStringAsFixed(2)),
                  _buildKpiRow('Aantal gelogde dagen', '$logCount30'),
                  _buildKpiRow('Aantal gebeurtenissen', '$eventCount30'),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
            
            // Sectie 2: Logboek
            pw.Text(
              'Logboek (Laatste 30 dagen)',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(height: 12),
            
            // Tabel met logs
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
              children: [
                // Header rij
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#4FB2C1')),
                  children: [
                    _buildTableHeader('Datum'),
                    _buildTableHeader('Stemming'),
                    _buildTableHeader('Slaap (uren)'),
                    _buildTableHeader('Activiteiten/Gebeurtenissen'),
                  ],
                ),
                // Data rijen
                ...recentLogs.reversed.map((log) {
                  final date = log['date'] ?? '-';
                  final stemming = log['stemming_ochtend']?.toString() ?? '-';
                  final slaap = log['uren_slaap']?.toString() ?? '-';
                  
                  // Haal activiteiten en gebeurtenissen op voor deze dag
                  String activiteiten = '-';
                  if (log['activiteiten'] != null && log['activiteiten'] is List) {
                    final acts = log['activiteiten'] as List;
                    if (acts.isNotEmpty) {
                      activiteiten = acts.take(2).join(', ');
                      if (acts.length > 2) activiteiten += '...';
                    }
                  }
                  
                  return pw.TableRow(
                    children: [
                      _buildTableCell(date),
                      _buildTableCell(stemming),
                      _buildTableCell(slaap),
                      _buildTableCell(activiteiten),
                    ],
                  );
                }).toList(),
              ],
            ),
            
            pw.SizedBox(height: 20),
            pw.Text(
              'Dit rapport is gegenereerd door de Ritme App.',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey500,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );

    // Deel de PDF
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'life_chart_rapport_${now.day}-${now.month}-${now.year}.pdf',
    );
  }
  
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
            onPressed: _genereerEnDeelPdf,
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
