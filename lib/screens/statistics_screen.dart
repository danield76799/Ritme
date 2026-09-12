import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
    try {
      final l10n = AppLocalizations.of(context);
      
      // Determine date range
      String dateStart = '';
      String dateEnd = '';
      if (_logs.isNotEmpty) {
        dateEnd = _logs.first['date']?.toString() ?? '';
        dateStart = _logs.last['date']?.toString() ?? '';
      }
      
      // Build PDF
      final pdf = pw.Document();
      final theme = Theme.of(context);
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context ctx) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Text(
                l10n.pdfReportTitle,
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800),
              ),
            );
          },
          footer: (pw.Context ctx) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            );
          },
          build: (pw.Context ctx) => [
            // Summary box
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.teal200),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('${l10n.pdfGenerated}: ${DateTime.now().toString().substring(0, 16)}', style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 4),
                  if (dateStart.isNotEmpty)
                    pw.Text('${l10n.pdfPeriod}: $dateStart → $dateEnd (${_logs.length} ${l10n.pdfDays})', style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildKpiColumn(l10n.pdfAverageMood, _gemStemming.toStringAsFixed(1), PdfColors.orange800),
                      _buildKpiColumn(l10n.pdfAverageSleep, _formatHours(_gemSlaap), PdfColors.blue800),
                      _buildKpiColumn(l10n.pdfTotalActivities, '$_aantalActiviteiten', PdfColors.green800),
                    ],
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 24),
            
            // Mood chart data table
            if (_logs.any((l) => l['stemming_hoog'] != null)) ...[
              pw.Text(l10n.pdfMoodChart, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                    children: [
                      _buildTableHeader('Date'),
                      _buildTableHeader('Mood'),
                    ],
                  ),
                  ..._logs.where((l) => l['stemming_hoog'] != null).take(14).map((log) {
                    final raw = log['stemming_hoog'];
                    double val = 0;
                    if (raw is num) val = raw.toDouble();
                    else if (raw is String) val = double.tryParse(raw) ?? 0;
                    if (val > 10) val = ((val / 100) * 10 - 5).clamp(-5.0, 5.0);
                    else val = val.clamp(-5.0, 5.0);
                    return pw.TableRow(
                      children: [
                        _buildTableCell(log['date']?.toString() ?? '-'),
                        _buildTableCell(val.toStringAsFixed(1)),
                      ],
                    );
                  }),
                ],
              ),
            ],
            
            pw.SizedBox(height: 24),
            
            // Sleep chart data table
            if (_logs.any((l) => l['sleep_hours'] != null || l['uren_slaap'] != null)) ...[
              pw.Text(l10n.pdfSleepChart, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                    children: [
                      _buildTableHeader('Date'),
                      _buildTableHeader('Hours'),
                    ],
                  ),
                  ..._logs.where((l) => (l['sleep_hours'] != null && (l['sleep_hours'] is num ? l['sleep_hours'] > 0 : double.tryParse(l['sleep_hours']?.toString() ?? '0')! > 0)) || 
                                        (l['uren_slaap'] != null && (l['uren_slaap'] is num ? l['uren_slaap'] > 0 : double.tryParse(l['uren_slaap']?.toString() ?? '0')! > 0))).take(14).map((log) {
                    double? sleepVal;
                    if (log['sleep_hours'] != null) {
                      final raw = log['sleep_hours'];
                      if (raw is num) sleepVal = raw.toDouble();
                      else if (raw is String) sleepVal = double.tryParse(raw);
                    }
                    if (sleepVal == null && log['uren_slaap'] != null) {
                      final raw = log['uren_slaap'];
                      if (raw is num) sleepVal = raw.toDouble();
                      else if (raw is String) sleepVal = double.tryParse(raw);
                    }
                    return pw.TableRow(
                      children: [
                        _buildTableCell(log['date']?.toString() ?? '-'),
                        _buildTableCell(sleepVal != null ? sleepVal.toStringAsFixed(1) : '-'),
                      ],
                    );
                  }),
                ],
              ),
            ],
            
            pw.SizedBox(height: 24),
            pw.Text(
              'This report is generated by Ritme — a bipolar disorder management app.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ],
        ),
      );

      // Print / share PDF
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
      
    } catch (e, stack) {
      AppLogger.error('PDF generation failed', error: e, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _buildKpiColumn(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: color)),
        pw.SizedBox(height: 2),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      ],
    );
  }

  pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.teal800),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildTableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800), textAlign: pw.TextAlign.center),
    );
  }

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
    if (_logs.isEmpty) return _bouwLegePlaceholder(AppLocalizations.of(context).stemmingGrafiekTitel);

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
        if (stemming > 10) {
          stemming = ((stemming / 100) * 10 - 5).clamp(-5.0, 5.0);
        } else {
          stemming = stemming.clamp(-5.0, 5.0);
        }
        spots.add(FlSpot(i.toDouble(), stemming));
      }
    }

    if (spots.isEmpty) return _bouwLegePlaceholder(AppLocalizations.of(context).stemmingGrafiekTitel);

    return _bouwGrafiekKaart(
      titel: AppLocalizations.of(context).stemmingGrafiekTitel,
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
                    style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < _logs.length) {
                  final dateStr = _logs[index]['date'] as String? ?? '';
                  if (dateStr.length >= 10) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text('${dateStr.substring(8)}/${dateStr.substring(5, 7)}', style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                    );
                  }
                }
                return const Text('');
              },
            )),
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
    if (_logs.isEmpty) return _bouwLegePlaceholder(AppLocalizations.of(context).slaapGrafiekTitel);

    List<BarChartGroupData> barGroups = [];
    int dataCount = 0;
    for (int i = 0; i < _logs.length; i++) {
      double? slaapUren;
      
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

    if (barGroups.isEmpty) return _bouwLegePlaceholder(AppLocalizations.of(context).slaapGrafiekTitel);

    return _bouwGrafiekKaart(
      titel: AppLocalizations.of(context).slaapGrafiekTitel,
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
                    style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < _logs.length) {
                  final dateStr = _logs[index]['date'] as String? ?? '';
                  if (dateStr.length >= 10) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text('${dateStr.substring(8)}/${dateStr.substring(5, 7)}', style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                    );
                  }
                }
                return const Text('');
              },
            )),
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
          Text(titel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyMedium?.color)),
          SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _bouwLegePlaceholder(String titel) {
    return Container(
      width: double.infinity,
      height: 160,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyMedium?.color)),
          SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 32, color: Theme.of(context).colorScheme.outline),
                  SizedBox(height: 8),
                  Text(AppLocalizations.of(context).geenDataBeschikbaar, style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bouwKpiKaart(String value, String label, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
