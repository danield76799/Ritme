import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../service_locator.dart';
import '../utils/app_theme.dart';

class InstellingenScherm extends StatefulWidget {
  @override
  _InstellingenSchermState createState() => _InstellingenSchermState();
}

class _InstellingenSchermState extends State<InstellingenScherm> {

  bool _isExporting = false;
  bool _isImporting = false;
  bool _isSavingName = false;
  final _naamController = TextEditingController();
  String _huidigeNaam = '';

  @override
  void initState() {
    super.initState();
    _laadNaam();
  }

  Future<void> _laadNaam() async {
    final settings = await db.getSettings();
    if (settings != null) {
      _huidigeNaam = settings['username']?.toString() ?? '';
      _naamController.text = _huidigeNaam;
      setState(() {});
    }
  }

  Future<void> _opslaanNaam() async {
    if (_naamController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vul een naam in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSavingName = true);

    try {
      final settings = await db.getSettings();
      if (settings != null) {
        settings['username'] = _naamController.text.trim();
        await db.updateSettingsMap(settings);
      }
      setState(() => _huidigeNaam = _naamController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Naam opgeslagen: $_huidigeNaam'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij opslaan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSavingName = false);
    }
  }

  Future<void> _exportBackup() async {
    setState(() => _isExporting = true);

    try {
      // Genereer JSON
      final jsonString = await db.exportDatabaseToJson();

      // Sla op in temp directory
      final tempDir = await getTemporaryDirectory();
      final fileName = 'ritme_backup_${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}.json';
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(jsonString);

      // Deel het bestand
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Ritme Backup',
        text: 'Hier is mijn Ritme app backup van ${DateFormat('d MMMM yyyy').format(DateTime.now())}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup succesvol gemaakt: $fileName'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij exporteren: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _importBackup() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Importeren is niet beschikbaar op web'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Kies bestand
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Kies een Ritme backup bestand',
      );

      if (result == null || result.files.single.path == null) return;

      final filePath = result.files.single.path!;
      final file = File(filePath);
      final jsonString = await file.readAsString();

      // Toon waarschuwing
      final bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
              const SizedBox(width: 8),
              const Text('Waarschuwing'),
            ],
          ),
          content: const Text(
            'Dit overschrijft je huidige data.\n\n'
            'Alle bestaande logs, medicatie, activiteiten en instellingen worden vervangen door de backup.\n\n'
            'Weet je het zeker?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuleren'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Ja, overschrijven', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      setState(() => _isImporting = true);

      // Importeer
      await db.importDatabaseFromJson(jsonString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Backup succesvol geïmporteerd!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij importeren: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        title: const Text(
          'Instellingen',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Info
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    size: 40,
                    color: AppTheme.primaryTeal,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ritme',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textCharcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Versie 1.2.0',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Profiel Sectie
          Text(
            'Profiel',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Je naam',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.textCharcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Deze naam wordt gebruikt voor de persoonlijke begroeting',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _naamController,
                        decoration: InputDecoration(
                          hintText: 'Voer je naam in',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSavingName ? null : _opslaanNaam,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSavingName
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Opslaan',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Gegevensbeheer Sectie
          Text(
            'Gegevensbeheer',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),

          // Backup maken
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.backup_outlined,
                  color: Colors.green[700],
                ),
              ),
              title: Text(
                'Maak een Backup',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textCharcoal,
                ),
              ),
              subtitle: Text(
                'Exporteer al je data naar een bestand',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              trailing: _isExporting
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryTeal,
                      ),
                    )
                  : Icon(Icons.chevron_right, color: Colors.grey[400]),
              onTap: _isExporting ? null : _exportBackup,
            ),
          ),
          const SizedBox(height: 12),

          // Backup terugzetten
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.restore_outlined,
                  color: Colors.orange[700],
                ),
              ),
              title: Text(
                'Zet een Backup terug',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textCharcoal,
                ),
              ),
              subtitle: Text(
                'Importeer data uit een backup bestand',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              trailing: _isImporting
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryTeal,
                      ),
                    )
                  : Icon(Icons.chevron_right, color: Colors.grey[400]),
              onTap: _isImporting ? null : _importBackup,
            ),
          ),
          const SizedBox(height: 24),

          // Overige instellingen
          Text(
            'Overige',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                  title: Text(
                    'Over Ritme',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textCharcoal,
                    ),
                  ),
                  subtitle: Text(
                    'SRT Tracker voor dagelijkse monitoring',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Ritme',
                      applicationVersion: '1.2.0',
                      applicationIcon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.favorite, color: AppTheme.primaryTeal),
                      ),
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'Ritme is een SRT (Social Rhythm Therapy) tracker ontworpen om dagelijkse activiteiten, stemming en medicatie bij te houden.',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
