import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../service_locator.dart';
import '../theme/app_theme.dart';
import '../generated/l10n/app_localizations.dart';
import '../utils/logger.dart';
import 'package:share_plus/share_plus.dart';

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

  String get _formattedToday {
    if (widget.initialDate != null) return widget.initialDate!;
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
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
      final startDate = now.subtract(const Duration(days: 30));
      final startStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      final endStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final dagboeken = await db.getDagboekRange(startStr, endStr);
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
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: Icon(Icons.ios_share, color: theme.colorScheme.onPrimary),
            onPressed: _exporteren,
            tooltip: AppLocalizations.of(context).exporterenDelen,
          ),
        ],
      ),
      body: SafeArea(
        child: _bekijkModus
            ? _buildOverzicht(context)
            : _buildInvoer(context),
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
          const Icon(Icons.menu_book, size: 64, color: AppTheme.primaryTeal),
          const SizedBox(height: 16),
          Text(
            _formattedToday,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
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
                borderRadius: BorderRadius.circular(12),
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
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryTeal),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _tekstController,
            onChanged: _updateTekst,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: l10n.dagboekTekstPlaceholder,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              counterText: l10n.dagboekWoordenTellen(_woorden),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _score > 0 && !_isSaving ? _opslaan : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
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
