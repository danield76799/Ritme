import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../services/rapport_generator.dart';
import '../generated/l10n/app_localizations.dart';

class RapportScreen extends StatefulWidget {
  RapportScreen({super.key});

  @override
  State<RapportScreen> createState() => _RapportScreenState();
}

class _RapportScreenState extends State<RapportScreen> {
  bool _isGenerating = false;
  bool _isSharing = false;
  String? _reportText;
  int _selectedDays = 30;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        title: Text(AppLocalizations.of(context).rapport, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.description_outlined, color: AppTheme.primaryTeal, size: 32),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Genereer een Life Chart Methode (LCM) rapport voor je behandelaar. Bevat stemming, slaap, medicatie, episodes en voortekenen.',
                      style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Period selector
            Text(AppLocalizations.of(context).periode, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [7, 14, 30, 90, 365].map((days) {
                final isSelected = _selectedDays == days;
                final label = days == 365 ? '1 jaar' : days == 90 ? '3 maanden' : days == 30 ? '30 dagen' : days == 14 ? '2 weken' : '1 week';
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryTeal,
                  onSelected: (val) => setState(() => _selectedDays = days),
                );
              }).toList(),
            ),
            SizedBox(height: 24),

            // Generate button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateAndShare,
                icon: _isGenerating
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.surface, strokeWidth: 2))
                    : Icon(Icons.picture_as_pdf, size: 22),
                label: Text(
                  _isGenerating ? AppLocalizations.of(context).genereren : AppLocalizations.of(context).genereerDeelRapport,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Preview (if generated)
            if (_reportText != null) ...[
              const SizedBox(height: 24),
              // Deel-knop (altijd beschikbaar zodra er een rapport is)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isSharing ? null : _deelRapport,
                  icon: _isSharing
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.surface, strokeWidth: 2))
                      : const Icon(Icons.share, size: 22),
                  label: Text(
                    AppLocalizations.of(context).delen,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(width: 4, height: 24, decoration: BoxDecoration(color: AppTheme.primaryTeal, borderRadius: BorderRadius.circular(2))),
                  SizedBox(width: 12),
                  Text(AppLocalizations.of(context).voorbeeld, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                ],
              ),
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    _reportText!,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.4),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAndShare() async {
    setState(() => _isGenerating = true);

    try {
      final report = await RapportGenerator.instance.generateLCMReport(days: _selectedDays);
      if (!mounted) return;
      setState(() {
        _reportText = report;
        _isGenerating = false;
      });
      // Scroll naar beneden zodat de preview + Delen-knop zichtbaar zijn.
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).fout(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Deelt het gegenereerde rapport als tekst (werkt in WhatsApp, e-mail,
  /// etc.) met het .md-bestand als bijlage-variant.
  Future<void> _deelRapport() async {
    if (_reportText == null || _reportText!.isEmpty) return;
    setState(() => _isSharing = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ritme_rapport_${DateTime.now().millisecondsSinceEpoch}.md');
      await file.writeAsString(_reportText!);

      await SharePlus.instance.share(
        ShareParams(
          text: _reportText,
          files: [XFile(file.path)],
          subject: AppLocalizations.of(context).ritmeRapportOnderwerp,
          title: AppLocalizations.of(context).ritmeRapportOnderwerp,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).fout(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }
}
