import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../service_locator.dart';
import '../utils/logger.dart';
import '../services/backup_service.dart';
import '../services/notification_helper.dart';
import '../services/sunup_service.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

class _CustomTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  final String label;

  const _CustomTimePickerDialog({
    required this.initialTime,
    required this.label,
  });

  @override
  State<_CustomTimePickerDialog> createState() => _CustomTimePickerDialogState();
}

class _CustomTimePickerDialogState extends State<_CustomTimePickerDialog> {
  late int selectedHour;
  late int selectedMinute;

  @override
  void initState() {
    super.initState();
    selectedHour = widget.initialTime.hour;
    selectedMinute = widget.initialTime.minute;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hour picker
                _buildNumberPicker(
                  value: selectedHour,
                  min: 0,
                  max: 23,
                  onChanged: (value) => setState(() => selectedHour = value),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    ':',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
                // Minute picker
                _buildNumberPicker(
                  value: selectedMinute,
                  min: 0,
                  max: 59,
                  step: 15,
                  onChanged: (value) => setState(() => selectedMinute = value),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Annuleer',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      TimeOfDay(hour: selectedHour, minute: selectedMinute),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'Klaar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPicker({
    required int value,
    required int min,
    required int max,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      width: 80,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListWheelScrollView.useDelegate(
        itemExtent: 50,
        diameterRatio: 1.2,
        magnification: 1.2,
        useMagnifier: true,
        onSelectedItemChanged: (index) {
          onChanged(min + (index * step));
        },
        controller: FixedExtentScrollController(
          initialItem: (value - min) ~/ step,
        ),
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            final itemValue = min + (index * step);
            if (itemValue > max) return null;
            final isSelected = itemValue == value;
            return Container(
              alignment: Alignment.center,
              child: Text(
                itemValue.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: isSelected ? 28 : 20,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryTeal : Colors.black54,
                ),
              ),
            );
          },
          childCount: ((max - min) ~/ step) + 1,
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _settings;
  bool _showMenstruatie = true;
  bool _isLoading = true;
  String? _errorMessage;

  // Controllers for text fields
  final _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final settings = await db.getSettings();
      setState(() {
        _settings = settings;
        _showMenstruatie = settings?['show_menstruatie'] == '1' || settings?['show_menstruatie'] == 1 || settings?['show_menstruatie'] == 'true' || settings?['show_menstruatie'] == null;
        _isLoading = false;
        // Update controllers with loaded values
        _usernameController.text = settings?['username']?.toString() ?? '';
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load settings', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Kon instellingen niet laden.';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      // Laad eerst bestaande settings om te voorkomen dat we velden overschrijven
      final existing = await db.getSettings();
      final merged = Map<String, dynamic>.from(existing ?? {});
      merged.addAll(_settings ?? {});
      merged['username'] = _usernameController.text;
      await db.updateSettingsMap(merged);
      _showSuccess('Instellingen opgeslagen!');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save settings', error: e, stackTrace: stackTrace);
      _showError('Kon instellingen niet opslaan.');
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _showTimePicker(String label, String key) async {
    // Parse current time or use default
    TimeOfDay currentTime;
    if (_settings?[key] != null) {
      final parts = _settings![key].toString().split(':');
      if (parts.length >= 2) {
        currentTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 8,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      } else {
        currentTime = const TimeOfDay(hour: 8, minute: 0);
      }
    } else {
      currentTime = const TimeOfDay(hour: 8, minute: 0);
    }

    final TimeOfDay? picked = await showDialog<TimeOfDay>(
      context: context,
      builder: (BuildContext context) {
        return _CustomTimePickerDialog(
          initialTime: currentTime,
          label: label,
        );
      },
    );

    if (picked != null) {
      final timeString = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        _settings ??= {};
        _settings![key] = timeString;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Very light grey background
      appBar: AppBar(
        title: const Text('Instellingen', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : _errorMessage != null
              ? _buildErrorWidget()
              : _buildSettingsForm(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: TextStyle(fontSize: 16, color: Colors.black),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Opnieuw proberen'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Profiel'),
          _buildTextField('Gebruikersnaam', _usernameController),
          const SizedBox(height: 24),
          _buildSectionHeader('Slaapschema'),
          _buildTimeField('Opstaan', 'target_opstaan'),
          _buildTimeField('Slapen', 'target_slapen'),
          const SizedBox(height: 24),
          _buildSectionHeader('Dagelijkse Doelen'),
          _buildTimeField('Eerste contact', 'target_contact'),
          _buildTimeField('Werk / Hobby', 'target_werk'),
          _buildTimeField('Avondeten', 'target_eten'),
          const SizedBox(height: 24),
          _buildSectionHeader('Weergave'),
          SwitchListTile(
            title: const Text('Toon menstruatie tracking',
              style: TextStyle(fontSize: 14, color: Color(0xFF333333))),
            subtitle: const Text('Zet uit als je dit niet wilt bijhouden',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
            value: _showMenstruatie,
            onChanged: (value) {
              setState(() {
                _showMenstruatie = value;
                _settings ??= {};
                _settings!['show_menstruatie'] = value ? '1' : '0';
              });
              // Sla direct op zodat het meteen effect heeft
              _saveSettings();
            },
            activeColor: AppTheme.primaryTeal,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Notificaties'),
          _buildSunUpToggle(),
          const SizedBox(height: 24),
          _buildSectionHeader('Medicatie'),
          _buildActionButton(
            'Medicatie beheren',
            Icons.medication_outlined,
            () => Navigator.pushNamed(context, '/medication'),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Opslaan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Backup & Herstel'),
          _buildBackupButtons(),
          const SizedBox(height: 32),
          _buildSectionHeader('Overige'),
          _buildActionButton(
            'Database Debug',
            Icons.storage,
            () => Navigator.pushNamed(context, '/database-debug'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildBackupButtons() {
    return Column(
      children: [
        _buildActionButton(
          'Backup maken',
          Icons.backup,
          () async {
            try {
              final backupPath = await BackupService.saveLocalBackup();
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Backup opgeslagen: $backupPath'),
                    backgroundColor: Colors.green[700],
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Backup error: $e'),
                    backgroundColor: Colors.red[700],
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            }
          },
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          'Backup herstellen',
          Icons.restore,
          () async {
            try {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['json'],
              );
              
              if (result != null && result.files.isNotEmpty) {
                final filePath = result.files.first.path!;
                await BackupService.restoreFromFile(filePath);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Backup succesvol hersteld!'),
                      backgroundColor: Colors.green[700],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
                _loadData(); // Reload settings
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Herstel error: $e'),
                    backgroundColor: Colors.red[700],
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryTeal,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: const TextStyle(color: Colors.black87, fontSize: 16),
      ),
    );
  }

  Widget _buildTimeField(String label, String key) {
    final timeValue = _settings?[key]?.toString() ?? '--:--';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        title: Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        subtitle: Text(
          timeValue,
          style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        trailing: Icon(Icons.access_time, color: AppTheme.primaryTeal),
        onTap: () => _showTimePicker(label, key),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.8),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildSunUpToggle() {
    final isSunUp = SunUpService.instance.mode == PushMode.sunup;
    final isLocal = SunUpService.instance.mode == PushMode.local;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSunUp ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSunUp ? Colors.green.shade300 : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSunUp ? Icons.cloud_done : Icons.cloud_off,
                color: isSunUp ? Colors.green : Colors.grey,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSunUp ? 'SunUP actief' : 'Lokale notificaties',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSunUp ? Colors.green.shade800 : Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      isSunUp
                          ? 'Push via je eigen server'
                          : isLocal
                              ? 'Push via app (batterij-afhankelijk)'
                              : 'Notificaties uitgeschakeld',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isSunUp,
                onChanged: (value) async {
                  if (value) {
                    await SunUpService.instance.enableSunUp();
                  } else {
                    await SunUpService.instance.disableSunUp();
                  }
                  setState(() {});
                },
                activeColor: Colors.green,
              ),
            ],
          ),
          if (isSunUp && SunUpService.instance.pushEndpoint != null) ...[
            const SizedBox(height: 8),
            Text(
              'Endpoint: ${SunUpService.instance.pushEndpoint!.substring(0, SunUpService.instance.pushEndpoint!.length > 40 ? 40 : SunUpService.instance.pushEndpoint!.length)}...',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }
}
