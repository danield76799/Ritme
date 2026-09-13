import 'package:flutter/material.dart';
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
                    AppLocalizations.of(context).annuleer,
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
                    AppLocalizations.of(context).klaar,
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black54,
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
  bool _isLoading = true;
  String? _errorMessage;
  ThemeMode _themeMode = ThemeMode.system;

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
        _isLoading = false;
        // Sync huidige thema-modus van de app
        if (appState != null) _themeMode = appState.themeMode;
        // Update controllers with loaded values
        _usernameController.text = settings?['username']?.toString() ?? '';
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load settings', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = AppLocalizations.of(context).konInstellingenNietLaden;
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
      _showSuccess(AppLocalizations.of(context).instellingenOpgeslagen);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save settings', error: e, stackTrace: stackTrace);
      _showError(AppLocalizations.of(context).konInstellingenNietOpslaan);
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

  Future<void> _showTimePicker(String label, String key,
      {Future<void> Function(String tijd)? onSaved}) async {
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
      // Check-in tijden worden direct weggeschreven én gepland; de
      // slaapschema-tijden gaan pas bij "Opslaan" naar de DB en hebben geen
      // callback. De waarde gaat mee zodat de aanroeper hem kan persisteren —
      // anders leest de planner de oude tijd terug uit de DB.
      if (onSaved != null) await onSaved(timeString);
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
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
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
          Icon(Icons.error_outline, size: 48, color: AppTheme.danger(context)),
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
          _buildSectionHeader(AppLocalizations.of(context).profiel),
          _buildTextField(AppLocalizations.of(context).gebruikersnaam, _usernameController),
          const SizedBox(height: 24),
          _buildSectionHeader(AppLocalizations.of(context).slaapschema),
          _buildTimeField(AppLocalizations.of(context).opstaan, 'target_opstaan'),
          _buildTimeField(AppLocalizations.of(context).slapen, 'target_slapen'),
          SizedBox(height: 24),
          _buildSectionHeader(AppLocalizations.of(context).dagelijkseDoelen),
          _buildTimeField(AppLocalizations.of(context).eersteContact, 'target_contact'),
          _buildTimeField(AppLocalizations.of(context).werkHobby, 'target_werk'),
          _buildTimeField(AppLocalizations.of(context).avondeten, 'target_eten'),
          SizedBox(height: 24),
          _buildSectionHeader(AppLocalizations.of(context).weergave),
          _buildThemeSelector(),
          const SizedBox(height: 24),
          _buildSectionHeader(AppLocalizations.of(context).notificaties),
          _buildCheckinReminders(),
          const SizedBox(height: 12),
          _buildActionButton(
                        AppLocalizations.of(context).testNotificatieNu,
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
            AppLocalizations.of(context).testCheckinNotificatie,
            () async {
              try {
                // Toont eenmalig hoe de check-in melding eruitziet, inclusief
                // de 'gisteren nog niet ingevuld'-regel als die van toepassing
                // is — zo kan de gebruiker het effect meteen beoordelen.
                await NotificationHelper.instance.showCheckinPreview();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(AppLocalizations.of(context).testNotificatieVerstuurd),
                        backgroundColor: AppTheme.success),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context).fout(e)), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
          ),
          _buildActionButton(
                        AppLocalizations.of(context).herplanMedicatieHerinneringen,
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
          _buildSectionHeader(AppLocalizations.of(context).medicatie),
          _buildActionButton(
                        AppLocalizations.of(context).medicatieBeheren,
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
          _buildSectionHeader(AppLocalizations.of(context).backupHerstel),
          _buildBackupButtons(),
          const SizedBox(height: 32),
          _buildSectionHeader(AppLocalizations.of(context).overige),
          _buildActionButton(
                        AppLocalizations.of(context).databaseDebug,
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
                    AppLocalizations.of(context).backupMaken,
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
                    AppLocalizations.of(context).backupHerstellen,
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

  /// Leest een instelling als bool met fallback.
  bool _settingBool(String key, {bool fallback = true}) {
    final v = _settings?[key];
    if (v == null) return fallback;
    final s = v.toString().toLowerCase();
    if (s == '1' || s == 'true') return true;
    if (s == '0' || s == 'false') return false;
    return fallback;
  }

  /// Schrijft een instelling direct weg (zonder op "Opslaan" te wachten) en
  /// plant de herinneringen opnieuw. Zo hoort de gebruiker meteen resultaat,
  /// en blijft de planning in sync met wat er in beeld staat.
  Future<void> _setCheckinSetting(String key, Object value) async {
    try {
      final existing = await db.getSettings();
      final merged = Map<String, dynamic>.from(existing ?? {});
      merged[key] = value;
      await db.updateSettingsMap(merged);
      if (mounted) setState(() => _settings = merged);
      await NotificationHelper.instance.rescheduleCheckinReminders();
      if (mounted) {
        // Meld ook meteen wanneer de eerste melding komt. Zonder dit lijkt een
        // tijd die vandaag al voorbij is op een storing.
        final l10n = AppLocalizations.of(context);
        final volgende = NotificationHelper.volgendeMoment(value.toString());
        _showSuccess(volgende.morgen
            ? l10n.volgendeHerinneringMorgen(value.toString())
            : l10n.volgendeHerinneringVandaag(value.toString()));
      }
    } catch (e, stackTrace) {
      AppLogger.error('Check-in instelling opslaan mislukt', error: e, stackTrace: stackTrace);
      if (mounted) _showError(AppLocalizations.of(context).konInstellingenNietOpslaan);
    }
  }

  /// Twee rijen: aan/uit + tijd per check-in.
  Widget _buildCheckinReminders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).checkinHerinneringenUitleg,
          style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color),
        ),
        const SizedBox(height: 12),
        _buildCheckinRow(
          label: AppLocalizations.of(context).ochtendHerinnering,
          icon: Icons.wb_sunny_outlined,
          aanKey: 'notif_ochtend_aan',
          tijdKey: 'notif_ochtend_tijd',
          defaultTijd: NotificationHelper.defaultOchtendTijd,
        ),
        const SizedBox(height: 8),
        _buildCheckinRow(
          label: AppLocalizations.of(context).avondHerinnering,
          icon: Icons.nights_stay_outlined,
          aanKey: 'notif_avond_aan',
          tijdKey: 'notif_avond_tijd',
          defaultTijd: NotificationHelper.defaultAvondTijd,
        ),
      ],
    );
  }

  Widget _buildCheckinRow({
    required String label,
    required IconData icon,
    required String aanKey,
    required String tijdKey,
    required String defaultTijd,
  }) {
    final aan = _settingBool(aanKey);
    final tijd = _settings?[tijdKey]?.toString() ?? defaultTijd;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: aan
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: aan,
            onChanged: (v) => _setCheckinSetting(aanKey, v ? '1' : '0'),
            secondary: Icon(icon,
                color: aan
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline),
            title: Text(label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          ),
          if (aan) ...[
            Divider(height: 1, color: Theme.of(context).dividerColor),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(AppLocalizations.of(context).herinneringTijd,
                  style: const TextStyle(fontSize: 14)),
              trailing: Text(
                tijd,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onTap: () => _showTimePicker(label, tijdKey,
                  onSaved: (tijd) => _setCheckinSetting(tijdKey, tijd)),
            ),
            // Terugkoppeling WANNEER de melding echt afgaat. Zonder deze regel
            // lijkt het instellen van een tijd die vandaag al voorbij is op een
            // storing: er gebeurt niets, want de melding gaat naar morgen.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.schedule,
                      size: 14,
                      color: NotificationHelper.volgendeMoment(tijd).morgen
                          ? AppTheme.warning
                          : Theme.of(context).textTheme.bodySmall?.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      NotificationHelper.volgendeMoment(tijd).morgen
                          ? AppLocalizations.of(context).volgendeHerinneringMorgen(tijd)
                          : AppLocalizations.of(context).volgendeHerinneringVandaag(tijd),
                      style: TextStyle(
                        fontSize: 12,
                        color: NotificationHelper.volgendeMoment(tijd).morgen
                            ? AppTheme.warning
                            : Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildThemeSelector() {
    final options = [
      (ThemeMode.system, Icons.brightness_auto, AppLocalizations.of(context).systeem),
      (ThemeMode.light, Icons.brightness_5, AppLocalizations.of(context).licht),
      (ThemeMode.dark, Icons.brightness_2, AppLocalizations.of(context).donker),
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
            AppLocalizations.of(context).weergaveModus,
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
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87, fontSize: 16),
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
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Icon(Icons.access_time, color: Theme.of(context).colorScheme.primary),
        onTap: () => _showTimePicker(label, key),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 8),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_forward_ios, size: 14),
        label: Text(label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            )),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          alignment: Alignment.centerLeft,
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
