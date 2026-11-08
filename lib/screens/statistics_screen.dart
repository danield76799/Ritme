import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../service_locator.dart';
import '../utils/logger.dart';
import '../generated/l10n/app_localizations.dart';

class StatistiekenScherm extends StatefulWidget {
  const StatistiekenScherm({super.key});

  @override
  State<StatistiekenScherm> createState() => _StatistiekenSchermState();
}

class _StatistiekenSchermState extends State<StatistiekenScherm> {

  /// Alle logs (oud -> nieuw). De PDF-rapportage gebruikt dit, zodat de
  /// export altijd over de hele historie gaat, ongeacht de gekozen periode.
  List<Map<String, dynamic>> _alleLogs = [];

  /// Logs binnen de gekozen periode (oud -> nieuw). Hierop zijn de grafieken
  /// en de KPI-kaarten gebaseerd.
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  /// Gekozen periode in dagen. 0 = alle beschikbare dagen.
  int _periodeDagen = 7;

  // KPIs
  double _gemStemming = 0.0;
  double _gemSlaap = 0.0;
  int _aantalActiviteiten = 0;

  /// KPI-snapshot over een verzameling logs.
  ///
  /// De klasse zelf staat top-level (zie onderaan dit bestand): Dart staat
  /// geen klassedeclaratie binnen een klasse toe.

  /// Format hours as "9u 30m" instead of "9.5u"
  String _formatHours(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h > 0 && m > 0) return '${h}u ${m}m';
    if (h > 0) return '${h}u';
    return '${m}m';
  }

  /// Selecteert de logs binnen de gekozen periode.
  ///
  /// Datums zijn 'JJJJ-MM-DD'-strings, dus een stringvergelijking is
  /// chronologisch correct en hoeft geen DateTime-parse.
  List<Map<String, dynamic>> _selecteerPeriode(List<Map<String, dynamic>> alle) {
    if (_periodeDagen <= 0) return alle;
    final cutoff = DateTime.now().subtract(Duration(days: _periodeDagen));
    final cutoffStr =
        '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';
    return alle
        .where((l) => (l['date']?.toString() ?? '').compareTo(cutoffStr) >= 0)
        .toList();
  }

  /// Berekent de KPI's over de meegegeven logs.
  Future<_Kpis> _berekenKpis(List<Map<String, dynamic>> logs) async {
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
    double gemStemming;
    if (rawGemStemming > 10) {
      // 0-100 schaal, converteer naar -5 tot +5
      gemStemming = ((rawGemStemming / 100) * 10 - 5).clamp(-5.0, 5.0);
    } else {
      // Al op -5 tot +5 schaal
      gemStemming = rawGemStemming.clamp(-5.0, 5.0);
    }

    // Slaap: alleen delen door dagen MET slaapdata
    final gemSlaap = sleepCount > 0 ? totaalSlaap / sleepCount : 0.0;

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

    return _Kpis(gemStemming, gemSlaap, actCount);
  }

  @override
  void initState() {
    super.initState();
    _laadData();
  }

  /// Wisselt de periode en herberekent de grafieken + KPI's.
  Future<void> _setPeriode(int dagen) async {
    if (dagen == _periodeDagen) return;
    setState(() => _periodeDagen = dagen);
    final geselecteerd = _selecteerPeriode(_alleLogs);
    final kpis = await _berekenKpis(geselecteerd);
    if (!mounted) return;
    setState(() {
      _logs = geselecteerd;
      _gemStemming = kpis.gemStemming;
      _gemSlaap = kpis.gemSlaap;
      _aantalActiviteiten = kpis.aantalActiviteiten;
    });
  }

  Future<void> _laadData() async {
    try {
      final logs = await db.getDailyLogs();

      // Oud -> nieuw sorteren: de grafieken lopen links (oud) naar rechts (nieuw).
      final alle = logs.reversed.toList();
      final geselecteerd = _selecteerPeriode(alle);
      final kpis = await _berekenKpis(geselecteerd);

      if (mounted) {
        setState(() {
          _alleLogs = alle;
          _logs = geselecteerd;
          _gemStemming = kpis.gemStemming;
          _gemSlaap = kpis.gemSlaap;
          _aantalActiviteiten = kpis.aantalActiviteiten;
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

      // De PDF-export gaat altijd over de VOLLE historie, ongeacht de
      // periode die op het scherm gekozen is: een rapport moet compleet zijn.
      final rapportLogs = _alleLogs;

      // Determine date range. _alleLogs is oud -> nieuw, dus de eerste is de
      // oudste dag en de laatste de nieuwste.
      String dateStart = '';
      String dateEnd = '';
      if (rapportLogs.isNotEmpty) {
        dateStart = rapportLogs.first['date']?.toString() ?? '';
        dateEnd = rapportLogs.last['date']?.toString() ?? '';
      }

      // KPI's over de volle historie (niet de gekozen periode).
      final rapportKpis = await _berekenKpis(rapportLogs);
      
      // Build PDF
      final pdf = pw.Document();

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
                    pw.Text('${l10n.pdfPeriod}: $dateStart → $dateEnd (${rapportLogs.length} ${l10n.pdfDays})', style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildKpiColumn(l10n.pdfAverageMood, rapportKpis.gemStemming.toStringAsFixed(1), PdfColors.orange800),
                      _buildKpiColumn(l10n.pdfAverageSleep, _formatHours(rapportKpis.gemSlaap), PdfColors.blue800),
                      _buildKpiColumn(l10n.pdfTotalActivities, '${rapportKpis.aantalActiviteiten}', PdfColors.green800),
                    ],
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 24),
            
            // Mood chart data table
            if (rapportLogs.any((l) => l['stemming_hoog'] != null)) ...[
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
                  // De 14 meest recente dagen: rapportLogs is oud -> nieuw,
                  // dus neem het einde en zet het weer oud -> nieuw.
                  ...rapportLogs.where((l) => l['stemming_hoog'] != null).toList().reversed.take(14).toList().reversed.map((log) {
                    final raw = log['stemming_hoog'];
                    double val = 0;
                    if (raw is num) {
                      val = raw.toDouble();
                    } else if (raw is String) val = double.tryParse(raw) ?? 0;
                    if (val > 10) {
                      val = ((val / 100) * 10 - 5).clamp(-5.0, 5.0);
                    } else {
                      val = val.clamp(-5.0, 5.0);
                    }
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
            if (rapportLogs.any((l) => l['sleep_hours'] != null || l['uren_slaap'] != null)) ...[
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
                  ...rapportLogs.where((l) => (l['sleep_hours'] != null && (l['sleep_hours'] is num ? l['sleep_hours'] > 0 : double.tryParse(l['sleep_hours']?.toString() ?? '0')! > 0)) || 
                                        (l['uren_slaap'] != null && (l['uren_slaap'] is num ? l['uren_slaap'] > 0 : double.tryParse(l['uren_slaap']?.toString() ?? '0')! > 0))).toList().reversed.take(14).toList().reversed.map((log) {
                    double? sleepVal;
                    if (log['sleep_hours'] != null) {
                      final raw = log['sleep_hours'];
                      if (raw is num) {
                        sleepVal = raw.toDouble();
                      } else if (raw is String) sleepVal = double.tryParse(raw);
                    }
                    if (sleepVal == null && log['uren_slaap'] != null) {
                      final raw = log['uren_slaap'];
                      if (raw is num) {
                        sleepVal = raw.toDouble();
                      } else if (raw is String) sleepVal = double.tryParse(raw);
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
            content: Text(AppLocalizations.of(context).pdfFout('$e')),
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
        elevation: 0,
        title: Text(AppLocalizations.of(context).statistiekenLifeChart, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _genereerEnDeelPdf,
            tooltip: AppLocalizations.of(context).exporteerAlsPdf,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bouwPeriodeKiezer(),
                    SizedBox(height: 16),
                    _bouwStemmingGrafiek(),
                    SizedBox(height: 16),
                    _bouwSlaapGrafiek(),
                    SizedBox(height: 32),
                    Text(AppLocalizations.of(context).samenvatting, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      children: [
                        // Modus-bewuste tinten (zelfde hues): effen orange/blue/green
                        // zakken in dark mode onder AA op de kaart.
                        _bouwKpiKaart(_gemStemming.toStringAsFixed(1), AppLocalizations.of(context).gemStemming, AppTheme.streakText(Theme.of(context).brightness)),
                        _bouwKpiKaart(_formatHours(_gemSlaap), AppLocalizations.of(context).gemSlaap, AppTheme.infoOn(Theme.of(context).brightness)),
                        _bouwKpiKaart('$_aantalActiviteiten', AppLocalizations.of(context).activiteitenGelogd, AppTheme.successOn(Theme.of(context).brightness)),
                      ],
                    ),
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  /// Periodekiezer (7 / 14 / 30 dagen / alle) voor de grafieken en de KPI's.
  ///
  /// Zelfde patroon als de stemming-trend op het dashboard: segmented
  /// buttons in de kaartkop. De PDF-export blijft over de volle historie
  /// gaan, ongeacht de hier gekozen periode.
  Widget _bouwPeriodeKiezer() {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        border: AppTheme.cardBorder(context),
      ),
      child: Row(
        children: [
          Icon(Icons.date_range_outlined, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text(l10n.statistiekenPeriode, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
          const Spacer(),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 7, label: Text(l10n.zevenDagen)),
              ButtonSegment(value: 14, label: Text(l10n.veertienDagen)),
              ButtonSegment(value: 30, label: Text(l10n.dertigDagen)),
              ButtonSegment(value: 0, label: Text(l10n.statistiekenAllePeriodes)),
            ],
            selected: {_periodeDagen},
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
            onSelectionChanged: (keuze) => _setPeriode(keuze.first),
          ),
        ],
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
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            // Rasterlijnen volgen het thema: de standaardkleur van fl_chart is
            // een grijs dat in dark mode óf te fel óf wegvalt.
            getDrawingHorizontalLine: (value) => FlLine(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.4),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
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
    // Datumlabels per balk. De balken worden compact geteld (dataCount), terwijl
    // de dagen zonder slaapdata ontbreken. Zonder deze aparte lijst zouden de
    // datums onder de balkjes naar voren opschuiven en de verkeerde dag tonen.
    final List<String> barDatums = [];
    for (int i = 0; i < _logs.length; i++) {
      double? slaapUren;
      
      if (_logs[i]['sleep_hours'] != null) {
        dynamic rawSleep = _logs[i]['sleep_hours'];
        if (rawSleep is num) {
          slaapUren = rawSleep.toDouble();
        } else if (rawSleep is String) slaapUren = double.tryParse(rawSleep);
      } else if (_logs[i]['uren_slaap'] != null) {
        dynamic rawSlaap = _logs[i]['uren_slaap'];
        if (rawSlaap is num) {
          slaapUren = rawSlaap.toDouble();
        } else if (rawSlaap is String) slaapUren = double.tryParse(rawSlaap);
      }
      
      if (slaapUren != null && slaapUren > 0) {
        barGroups.add(
          BarChartGroupData(
            x: barDatums.length,
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
        barDatums.add(_logs[i]['date']?.toString() ?? '');
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
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
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
                // Labels komen uit barDatums (niet uit _logs): de balken zijn
                // compact geteld, dus index -> _logs zou verschoven datums geven.
                if (index >= 0 && index < barDatums.length) {
                  final dateStr = barDatums[index];
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
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        border: AppTheme.cardBorder(context),
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
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        border: AppTheme.cardBorder(context),
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
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        border: AppTheme.cardBorder(context),
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

/// KPI-snapshot over een verzameling logs.
///
/// Top-level: Dart staat geen klassedeclaratie binnen een klasse toe.
class _Kpis {
  final double gemStemming;
  final double gemSlaap;
  final int aantalActiviteiten;
  const _Kpis(this.gemStemming, this.gemSlaap, this.aantalActiviteiten);
}

