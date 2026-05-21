import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';
import '../service_locator.dart';
import '../utils/logger.dart';
import '../services/backup_service.dart';
import '../services/notification_helper.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _settings;
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
      if (_settings != null) {
        // Update username from controller
        _settings!['username'] = _usernameController.text;
        await db.updateSettingsMap(_settings!);
        _showSuccess('Instellingen opgeslagen!');
      }
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

    final Duration initialDuration = Duration(hours: currentTime.hour, minutes: currentTime.minute);
    Duration selectedDuration = initialDuration;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[300], // Light background for visibility
      builder: (BuildContext context) {
        return Container(
          height: 300,
          color: Colors.grey[300],
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey[300],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuleer', style: TextStyle(color: Colors.black87, fontSize: 16)),
                    ),
                    Text(
                      label,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    TextButton(
                      onPressed: () {
                        // Save the selected time
                        final hours = selectedDuration.inHours;
                        final minutes = selectedDuration.inMinutes % 60;
                        final timeString = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
                        setState(() {
                          _settings ??= {};
                          _settings![key] = timeString;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Klaar', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.grey), // Will be grey[300]
              Expanded(
                child: Container(
                  color: Colors.grey[200],
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm,
                    minuteInterval: 15,
                    initialTimerDuration: initialDuration,
                    backgroundColor: Colors.grey[200],
                    onTimerDurationChanged: (Duration newDuration) {
                      selectedDuration = newDuration;
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
        ],
      ),
    );
  }

  Widget _buildBackupButtons() {
    return Column(
      children: [
        // Test notification button
        _buildActionButton(
          'Test notificatie',
          Icons.notifications_active,
          () async {
            try {
              await NotificationHelper.instance.showTestNotification();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Test notificatie verzonden! Check je notificatie paneel.'),
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
                    content: Text('Notificatie error: $e'),
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
        const SizedBox(height: 8),
        _buildActionButton(
          'Backup maken',
          Icons.backup,
          () async {
            try {
              final path = await BackupService.saveLocalBackup();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Backup opgeslagen: $path', style: const TextStyle(color: Colors.white)),
                    backgroundColor: Colors.green[700],
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            } catch (e, stack) {
              debugPrint('Backup error: $e');
              debugPrint('Stack: $stack');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Fout bij backup: $e', style: const TextStyle(color: Colors.white)),
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
        const SizedBox(height: 8),
        _buildActionButton(
          'Backup delen (email)',
          Icons.share,
          () async {
            try {
              await BackupService.shareBackup();
            } catch (e, stack) {
              debugPrint('Share error: $e');
              debugPrint('Stack: $stack');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Fout bij delen: $e', style: const TextStyle(color: Colors.white)),
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
        const SizedBox(height: 8),
        _buildActionButton(
          'Herstellen van backup',
          Icons.restore,
          () async {
            try {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['json'],
              );
              if (result != null && result.files.single.path != null) {
                await BackupService.restoreFromFile(result.files.single.path!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Data hersteld!', style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.green[700],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            } catch (e, stack) {
              debugPrint('Restore error: $e');
              debugPrint('Stack: $stack');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Fout bij herstellen: $e', style: const TextStyle(color: Colors.white)),
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

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: AppTheme.primaryTeal),
        label: Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 16)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: AppTheme.primaryTeal, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF008080), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildTimeField(String label, String key) {
    final displayValue = _settings?[key]?.toString() ?? '--:--';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showTimePicker(label, key),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFF008080), width: 2), // Medical Teal
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16, 
                  color: Color(0xFF333333), // Charcoal
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Text(
                    displayValue,
                    style: const TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF333333), // Charcoal
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.access_time, color: Color(0xFF008080)), // Medical Teal
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
