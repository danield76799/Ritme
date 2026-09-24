import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../service_locator.dart';
import '../generated/l10n/app_localizations.dart';
import '../utils/logger.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../theme/app_theme.dart';

/// Dagboek-scherm: dagelijkse check-in met 5-sterren score en notities.
/// Ondersteunt backfill (eerdere dagen aanpassen) via initialDate.
class DagboekScreen extends StatefulWidget {
  const DagboekScreen({super.key, this.onClose, this.initialDate});

  final void Function(bool saved)? onClose;
  final String? initialDate;

  @override
  State<DagboekScreen> createState() => _DagboekScreenState();
}

class _DagboekScreenState extends State<DagboekScreen> {
  final TextEditingController _tekstController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _bekijkModus = false;
  int _score = 0; // 1..5 (0 = niet gekozen)
  String? _opgeslagenTekst;
  int _woorden = 0;

  static const _maxWoorden = 250;

  /// De bekeken dag. Start op initialDate (backfill) of vandaag; nooit in de
  /// toekomst. Via de bladerbalk kan de gebruiker door de dagen heen.
  late DateTime _bekekenDatum;

  static String _sleutel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _vandaag() {
    final nu = DateTime.now();
    return DateTime(nu.year, nu.month, nu.day);
  }

  String get _formattedToday => _sleutel(_bekekenDatum);

  bool get _isVandaag => _sleutel(_bekekenDatum) == _sleutel(_vandaag());

  @override
  void initState() {
    super.initState();
    final start = widget.initialDate != null
        ? DateTime.tryParse(widget.initialDate!) ?? _vandaag()
        : _vandaag();
    _bekekenDatum = start.isAfter(_vandaag()) ? _vandaag() : start;
    _laadBestaandeData();
  }

  @override
  void dispose() {
    _tekstController.dispose();
    super.dispose();
  }

  Future<void> _laadBestaandeData() async {
    try {
      await ensureInitialized();
      final dagboek = await db.getDagboek(_formattedToday);
      if (!mounted) return;

      if (dagboek != null) {
        setState(() {
          _score = (dagboek['score'] as num?)?.toInt() ?? 0;
          _opgeslagenTekst = dagboek['tekst'] as String?;
          _tekstController.text = _opgeslagenTekst ?? '';
          _woorden = _telWoorden(_tekstController.text);
          _bekijkModus = true;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppLogger.error('Dagboek: laden mislukt', error: e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _telWoorden(String tekst) {
    if (tekst.trim().isEmpty) return 0;
    return tekst.trim().split(RegExp(r'\s+')).length;
  }

  void _updateTekst(String value) {
    final woorden = _telWoorden(value);
    if (woorden <= _maxWoorden) {
      setState(() {
        _woorden = woorden;
        _tekstController.text = value;
      });
    }
  }

  void _startAanpassen() {
    setState(() => _bekijkModus = false);
  }

  /// Naar een andere dag bladeren: formulier leegmaken en die dag laden.
  /// Niet verder dan vandaag (geen toekomst).
  Future<void> _gaNaarDatum(DateTime datum) async {
    final gekozen =
        datum.isAfter(_vandaag()) ? _vandaag() : DateTime(datum.year, datum.month, datum.day);
    if (_sleutel(gekozen) == _sleutel(_bekekenDatum)) return;
    setState(() {
      _bekekenDatum = gekozen;
      _isLoading = true;
      _bekijkModus = false;
      _score = 0;
      _opgeslagenTekst = null;
      _tekstController.clear();
      _woorden = 0;
    });
    await _laadBestaandeData();
  }

  Future<void> _kiesDatum() async {
    final gekozen = await showDatePicker(
      context: context,
      initialDate: _bekekenDatum,
      firstDate: DateTime(2020, 1, 1),
      lastDate: _vandaag(),
      locale: Localizations.localeOf(context).languageCode == 'nl'
          ? const Locale('nl', 'NL')
          : null,
      helpText: AppLocalizations.of(context).kiesDatum,
      cancelText: AppLocalizations.of(context).annuleren,
      confirmText: AppLocalizations.of(context).bekijken,
    );
    if (gekozen != null && mounted) await _gaNaarDatum(gekozen);
  }

  /// Mooie datumregel: Vandaag / Gisteren / 12 september 2026.
  String _datumLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final taal = Localizations.localeOf(context).languageCode;
    final datumDeel =
        DateFormat('d MMMM yyyy', taal).format(_bekekenDatum);
    if (_isVandaag) return '${l10n.vandaag} • $datumDeel';
    final gisteren = _vandaag().subtract(const Duration(days: 1));
    if (_sleutel(_bekekenDatum) == _sleutel(gisteren)) {
      return '${l10n.gisteren} • $datumDeel';
    }
    return datumDeel;
  }

  /// Bladerbalk boven de inhoud: ‹ datum ›.
  Widget _datumNavigator(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: AppLocalizations.of(context).stemmingsCheckVorige,
            onPressed: () =>
                _gaNaarDatum(_bekekenDatum.subtract(const Duration(days: 1))),
          ),
          Expanded(
            child: TextButton(
              onPressed: _kiesDatum,
              child: Text(
                _datumLabel(context),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: AppLocalizations.of(context).stemmingsCheckVolgende,
            onPressed: _isVandaag
                ? null
                : () => _gaNaarDatum(
                    _bekekenDatum.add(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }

  Future<void> _opslaan() async {
    if (_score == 0) return;
    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      await ensureInitialized();
      await db.upsertDagboek({
        'date': _formattedToday,
        'score': _score,
        'tekst': _tekstController.text.trim(),
      });

      if (!mounted) return;
      setState(() {
        _opgeslagenTekst = _tekstController.text.trim();
        _bekijkModus = true;
        _isSaving = false;
      });
      widget.onClose?.call(true);
    } catch (e) {
      AppLogger.error('Dagboek: opslaan mislukt', error: e);
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _exporteren() async {
    try {
      final now = DateTime.now();
      final dagboeken = await _dagboekenLaatste30Dagen();
      if (dagboeken.isEmpty) return;

      final buffer = StringBuffer();
      buffer.writeln('# ${AppLocalizations.of(context).dagboekExportTitel}');
      buffer.writeln(' ${AppLocalizations.of(context).gegenereerdOp} ${DateFormat('d MMMM yyyy', Localizations.localeOf(context).toString()).format(now)}\n');

      for (final dagboek in dagboeken.reversed) {
        final date = dagboek['date'] as String? ?? '';
        final score = (dagboek['score'] as num?)?.toInt() ?? 0;
        final tekst = (dagboek['tekst'] as String?)?.trim() ?? '';

        buffer.writeln('## $date');
        buffer.writeln('**Score:** ${_scoreLabel(score)}\n');
        if (tekst.isNotEmpty) {
          buffer.writeln('$tekst\n');
        }
        buffer.writeln('---\n');
      }

      if (!mounted) return;
      // Delen als TEKST (niet als .md-bestand) zodat WhatsApp/Gemini het
      // direct als leesbare tekst tonen in plaats van een bestandsbijlage.
      await Share.share(
        buffer.toString(),
        subject: AppLocalizations.of(context).dagboekExport,
      );
    } catch (e) {
      AppLogger.error('Dagboek: exporteren mislukt', error: e);
    }
  }


  /// Exporteert dezelfde 30 dagen als echte PDF (systeem-deeldialoog),
  /// zoals Statistieken dat doet. Tekst-export (WhatsApp/Gemini) blijft
  /// via het menu beschikbaar.
  Future<void> _exporteerAlsPdf() async {
    try {
      final l10n = AppLocalizations.of(context);
      final taal = Localizations.localeOf(context).toString();
      final now = DateTime.now();
      final dagboeken = await _dagboekenLaatste30Dagen();
      if (dagboeken.isEmpty) return;

      String scoreWoord(int score) {
        switch (score) {
          case 1:
            return l10n.zeerSlecht;
          case 2:
            return l10n.slecht;
          case 3:
            return l10n.neutraal;
          case 4:
            return l10n.goed;
          case 5:
            return l10n.zeerGoed;
          default:
            return '';
        }
      }

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Text(
              l10n.dagboekExportTitel,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800),
            ),
          ),
          footer: (pw.Context ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ),
          build: (pw.Context ctx) => [
            pw.Text(
              '${l10n.gegenereerdOp} ${DateFormat('d MMMM yyyy', taal).format(now)}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 16),
            for (final dagboek in dagboeken.reversed)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.teal200),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _pdfDatum(dagboek['date'] as String? ?? '', taal),
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Score: ${(dagboek['score'] as num?)?.toInt() ?? 0}/5 - ${scoreWoord((dagboek['score'] as num?)?.toInt() ?? 0)}',
                      style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
                    ),
                    if (((dagboek['tekst'] as String?)?.trim() ?? '').isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Text(
                        (dagboek['tekst'] as String).trim(),
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      );

      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'ritme_dagboek.pdf',
      );
    } catch (e) {
      AppLogger.error('Dagboek: PDF-export mislukt', error: e);
    }
  }

  /// '2026-09-10' -> '10 september 2026' (valt terug op de ruwe tekst).
  String _pdfDatum(String iso, String taal) {
    try {
      return DateFormat('d MMMM yyyy', taal).format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  /// Haalt de dagboeken van de laatste 30 dagen op (gedeeld door
  /// tekst- en PDF-export).
  Future<List<Map<String, dynamic>>> _dagboekenLaatste30Dagen() async {
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 30));
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return db.getDagboekRange(fmt(startDate), fmt(now));
  }

  String _scoreLabel(int score) {
    switch (score) {
      case 1: return '★☆☆☆☆ ' + AppLocalizations.of(context).zeerSlecht;
      case 2: return '★★☆☆☆ ' + AppLocalizations.of(context).slecht;
      case 3: return '★★★☆☆ ' + AppLocalizations.of(context).neutraal;
      case 4: return '★★★★☆ ' + AppLocalizations.of(context).goed;
      case 5: return '★★★★★ ' + AppLocalizations.of(context).zeerGoed;
      default: return '';
    }
  }



  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.dagboek)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dagboek),
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.ios_share, color: theme.colorScheme.onSurface),
            tooltip: AppLocalizations.of(context).exporterenDelen,
            onSelected: (keuze) {
              if (keuze == 'pdf') {
                _exporteerAlsPdf();
              } else {
                _exporteren();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'tekst',
                child: Text(AppLocalizations.of(context).alsTekstDelen),
              ),
              PopupMenuItem(
                value: 'pdf',
                child: Text(AppLocalizations.of(context).alsPdfDelen),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _datumNavigator(context),
            Expanded(
              child: _bekijkModus
                  ? _buildOverzicht(context)
                  : _buildInvoer(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverzicht(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          if (_score > 0) ...[
            Text(_scoreLabel(_score), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
          ],
          if (_opgeslagenTekst != null && _opgeslagenTekst!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.smallRadius),
              ),
              child: Text(_opgeslagenTekst!),
            ),
            const SizedBox(height: 24),
          ],
          ElevatedButton.icon(
            onPressed: _startAanpassen,
            icon: const Icon(Icons.edit),
            label: Text(l10n.dagboekAanpassen),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoer(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            l10n.dagboekVraag,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final value = i + 1;
              final filled = value <= _score;
              return IconButton(
                iconSize: 40,
                icon: Icon(
                  filled ? Icons.star : Icons.star_border,
                  color: filled ? Colors.amber : Colors.grey,
                ),
                onPressed: () => setState(() => _score = value),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            _score > 0 ? _sterTekst(_score, l10n) : '',
            style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _tekstController,
            onChanged: _updateTekst,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: l10n.dagboekTekstPlaceholder,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.smallRadius)),
              counterText: l10n.dagboekWoordenTellen(_woorden),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _score > 0 && !_isSaving ? _opslaan : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(_isSaving ? 'Bezig...' : l10n.dagboekOpslaan),
            ),
          ),
        ],
      ),
    );
  }

  String _sterTekst(int score, AppLocalizations l10n) {
    switch (score) {
      case 1: return l10n.dagboekZeerSlecht;
      case 2: return l10n.dagboekSlecht;
      case 3: return l10n.dagboekNeutraal;
      case 4: return l10n.dagboekGoed;
      case 5: return l10n.dagboekZeerGoed;
      default: return '';
    }
  }
}
