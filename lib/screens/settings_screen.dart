import 'package:flutter/material.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../service_locator.dart';
import '../utils/logger.dart';
import '../services/backup_service.dart';
import '../services/notification_helper.dart';
import '../services/boot_service.dart';
import 'package:file_picker/file_picker.dart';
import '../services/theme_service.dart';
import '../main.dart';
import '../generated/l10n/app_localizations.dart';

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
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyMedium?.color,
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
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    ':',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black),
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
                  child: Text(
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
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
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
        color: Colors.grey.shade100,
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
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;  // null = volg systeem-locale

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
      final appState = RitmeApp.of(context);
      setState(() {
        _settings = settings;
        _showMenstruatie = settings?['show_menstruatie'] == '1' || settings?['show_menstruatie'] == 1 || settings?['show_menstruatie'] == 'true' || settings?['show_menstruatie'] == null;
        _isLoading = false;
        // Sync huidige thema-modus en locale van de app
        if (appState != null) {
          _themeMode = appState.themeMode;
          _locale = appState.locale;
        }
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
          content: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.surface, fontWeight: FontWeight.w600)),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.surface, fontWeight: FontWeight.w600)),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Volgt thema (ook dark mode)
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).instellingen, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
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
          SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: Text(AppLocalizations.of(context).opnieuwProberen),
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
          SizedBox(height: 24),
          _buildSectionHeader('Dagelijkse Doelen'),
          _buildTimeField('Eerste contact', 'target_contact'),
          _buildTimeField('Werk / Hobby', 'target_werk'),
          _buildTimeField('Avondeten', 'target_eten'),
          SizedBox(height: 24),
          _buildSectionHeader('Weergave'),
          SwitchListTile(
            title: Text(AppLocalizations.of(context).toonMenstruatieTracking,
              style: TextStyle(fontSize: 14, color: Color(0xFF333333))),
            subtitle: Text(AppLocalizations.of(context).zetAlsJe,
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
          const SizedBox(height: 12),
          _buildThemeSelector(),
          const SizedBox(height: 12),
          _buildLanguageSelector(),
          const SizedBox(height: 24),
          _buildSectionHeader('Notificaties'),
          _buildActionButton(
            'Test notificatie (nu)',
            Icons.notifications_active,
            () async {
              try {
                await NotificationHelper.instance.showTestNotification();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context).testNotificatieVerstuurd), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context).fout(e)), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
          _buildActionButton(
            'Herplan alle medicatie herinneringen',
            Icons.alarm,
            () async {
              try {
                final rescheduled = await BootService.rescheduleNow();
                final count = await NotificationHelper.instance.getPendingNotificationCount();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context).herinneringenHerplantDbIngepland(rescheduled, count)), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context).fout(e)), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
          _buildSectionHeader('Medicatie'),
          _buildActionButton(
            'Medicatie beheren',
            Icons.medication_outlined,
            () => Navigator.pushNamed(context, '/medication'),
          ),
          SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(AppLocalizations.of(context).opslaan, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                    content: Text(AppLocalizations.of(context).backupOpgeslagen(backupPath)),
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
                    content: Text(AppLocalizations.of(context).backupError(e)),
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
                      content: Text(AppLocalizations.of(context).backupSuccesvolHersteld),
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
                    content: Text(AppLocalizations.of(context).herstelError(e)),
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

  Widget _buildThemeSelector() {
    final options = [
      (ThemeMode.system, Icons.brightness_auto, 'Systeem'),
      (ThemeMode.light, Icons.brightness_5, 'Licht'),
      (ThemeMode.dark, Icons.brightness_2, 'Donker'),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weergave modus',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            style: ButtonStyle(
              visualDensity: VisualDensity.comfortable,
            ),
            selected: {_themeMode},
            onSelectionChanged: (selected) {
              final mode = selected.first;
              setState(() => _themeMode = mode);
              RitmeApp.of(context)?.setThemeMode(mode);
            },
            segments: options
                .map(
                  (o) => ButtonSegment<ThemeMode>(
                    value: o.$1,
                    icon: Icon(o.$2, size: 18),
                    label: Text(o.$3),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    // Beschikbare talen (moet overeenkomen met AppLocalizations.supportedLocales).
    final options = <(Locale?, IconData, String)>[
      (null, Icons.phone_android, 'Systeem'),
      (const Locale('nl'), Icons.flag, 'Nederlands'),
      (const Locale('en'), Icons.flag_outlined, 'English'),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Taal',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal),
          ),
          const SizedBox(height: 12),
          SegmentedButton<Locale?>(
            style: ButtonStyle(
              visualDensity: VisualDensity.comfortable,
            ),
            selected: {_locale},
            onSelectionChanged: (selected) {
              final newLocale = selected.first;
              setState(() => _locale = newLocale);
              RitmeApp.of(context)?.setLocale(newLocale);
            },
            segments: options
                .map(
                  (o) => ButtonSegment<Locale?>(
                    value: o.$1,
                    icon: Icon(o.$2, size: 18),
                    label: Text(o.$3),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: TextStyle(color: Colors.black87, fontSize: 16),
      ),
    );
  }

  Widget _buildTimeField(String label, String key) {
    final timeValue = _settings?[key]?.toString() ?? '--:--';
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        title: Text(
          label,
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 14),
        ),
        subtitle: Text(
          timeValue,
          style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w600),
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
      margin: EdgeInsets.only(bottom: 8),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.surface, fontWeight: FontWeight.w600)),
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

  /// Direct een test notificatie tonen (binnen enkele seconden)
  Future<void> showTestNotification() async {
    try {
      await NotificationHelper.instance.showTestNotification();
    } catch (e) {
      AppLogger.error('Test notification now failed', error: e);
    }
  }

  /// Test notificatie plannen op een door de gebruiker gekozen tijdstip
  Future<void> showTestNotificationAtTime() async {
    try {
      // This is a placeholder or internal method, the actual logic should use showTestNotificationAt
    } catch (e) {
      AppLogger.error('Test notification at time failed', error: e);
    }
  }
}
