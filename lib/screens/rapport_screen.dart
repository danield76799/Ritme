import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/rapport_generator.dart';
import '../service_locator.dart';

class RapportScreen extends StatefulWidget {
  const RapportScreen({super.key});

  @override
  State<RapportScreen> createState() => _RapportScreenState();
}

class _RapportScreenState extends State<RapportScreen> {
  bool _isGenerating = false;
  String? _reportText;
  int _selectedDays = 30;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryLavender,
        elevation: 0,
        title: const Text('Rapport', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryLavender.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.description_outlined, color: AppTheme.primaryLavender, size: 32),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Genereer een Life Chart Methode (LCM) rapport voor je behandelaar. Bevat stemming, slaap, medicatie, episodes en voortekenen.',
                      style: TextStyle(color: AppTheme.textCharcoal, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Period selector
            const Text('Periode:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [7, 14, 30, 90, 365].map((days) {
                final isSelected = _selectedDays == days;
                final label = days == 365 ? '1 jaar' : days == 90 ? '3 maanden' : days == 30 ? '30 dagen' : days == 14 ? '2 weken' : '1 week';
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryLavender,
                  onSelected: (val) => setState(() => _selectedDays = days),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Generate button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateAndShare,
                icon: _isGenerating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf, size: 22),
                label: Text(
                  _isGenerating ? 'Genereren...' : 'Genereer & Deel Rapport',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLavender,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Preview (if generated)
            if (_reportText != null) ...[
              Row(
                children: [
                  Container(width: 4, height: 24, decoration: BoxDecoration(color: AppTheme.primaryLavender, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 12),
                  const Text('Voorbeeld', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
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

      // Save to temp file
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ritme_rapport_${DateTime.now().millisecondsSinceEpoch}.md');
      await file.writeAsString(report);

      if (mounted) {
        setState(() {
          _reportText = report;
          _isGenerating = false;
        });

        // Share
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: 'Ritme Life Chart Rapport',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
