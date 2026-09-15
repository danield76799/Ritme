import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../service_locator.dart';
import '../utils/logger.dart';
import '../services/backup_service.dart';
import '../services/backup_map_service.dart';
import '../services/notification_helper.dart';
import 'package:file_picker/file_picker.dart';
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
                // Minute picker — vrije keuze per minuut (was per kwartier,
                // waardoor tijden als 19:35 niet in te stellen waren).
                _buildNumberPicker(
                  value: selectedMinute,
                  min: 0,
                  max: 59,
                  step: 1,
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
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
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

  // Debounce voor het direct wegschrijven van de gebruikersnaam tijdens typen.
  Timer? _usernameSaveTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _usernameSaveTimer?.cancel();
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

  /// Schrijft één instelling direct weg, zonder op een Opslaan-knop te wachten.
  ///
  /// Naam, slaapschema en dagelijkse doelen gebruiken dit; check-in
  /// herinneringen doen hetzelfde via _setCheckinSetting. Eén model voor het
  /// hele scherm: alles is meteen bewaard, er valt niets te vergeten.
  Future<void> _directOpslaan(String key, Object value) async {
    try {
      final existing = await db.getSettings();
      final merged = Map<String, dynamic>.from(existing ?? {});
      merged[key] = value;
      await db.updateSettingsMap(merged);
      if (mounted) setState(() => _settings = merged);
    } catch (e, stackTrace) {
      AppLogger.error('Instelling direct opslaan mislukt', error: e, stackTrace: stackTrace);
      if (mounted) _showError(AppLocalizations.of(context).konInstellingenNietOpslaan);
    }
  }

  /// Gebruikersnaam tijdens typen bewaren (met debounce); bij Enter of
  /// wegklikken meteen. Stil bij succes — de tekst blijft immers staan.
  void _usernameGewijzigd(String value) {
    _usernameSaveTimer?.cancel();
    _usernameSaveTimer = Timer(const Duration(milliseconds: 800), () {
      _directOpslaan('username', value);
    });
  }

  void _usernameNuOpslaan() {
    _usernameSaveTimer?.cancel();
    _directOpslaan('username', _usernameController.text);
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.surface, fontWeight: FontWeight.w600)),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
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
          // Eén opslagmodel voor het hele scherm: alles wordt direct
          // bewaard, er is geen Opslaan-knop meer.
          Text(
            AppLocalizations.of(context).wijzigingenDirectOpgeslagen,
            style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color),
          ),
          const SizedBox(height: 12),
          _buildSectionHeader(AppLocalizations.of(context).profiel),
          _buildTextField(
            AppLocalizations.of(context).gebruikersnaam,
            _usernameController,
            onChanged: _usernameGewijzigd,
            onEditingAfgerond: _usernameNuOpslaan,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(AppLocalizations.of(context).slaapschema),
          _buildTimeField(AppLocalizations.of(context).opstaan, 'target_opstaan',
              onSaved: (t) => _directOpslaan('target_opstaan', t)),
          _buildTimeField(AppLocalizations.of(context).slapen, 'target_slapen',
              onSaved: (t) => _directOpslaan('target_slapen', t)),
          SizedBox(height: 24),
          _buildSectionHeader(AppLocalizations.of(context).dagelijkseDoelen),
          _buildTimeField(AppLocalizations.of(context).eersteContact, 'target_contact',
              onSaved: (t) => _directOpslaan('target_contact', t)),
          _buildTimeField(AppLocalizations.of(context).werkHobby, 'target_werk',
              onSaved: (t) => _directOpslaan('target_werk', t)),
          _buildTimeField(AppLocalizations.of(context).avondeten, 'target_eten',
              onSaved: (t) => _directOpslaan('target_eten', t)),
          SizedBox(height: 24),
          _buildSectionHeader(AppLocalizations.of(context).weergave),
          _buildThemeSelector(),
          const SizedBox(height: 24),
          _buildSectionHeader(AppLocalizations.of(context).notificaties),
          _buildCheckinReminders(),
          const SizedBox(height: 12),
          // Eén testknop: laat zien hoe de check-in melding er echt uitziet,
          // inclusief de 'gisteren nog niet ingevuld'-regel als die geldt.
          _buildActionButton(
            AppLocalizations.of(context).testMeldingVersturen,
            () async {
              try {
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
          _buildSectionHeader(AppLocalizations.of(context).medicatie),
          _buildActionButton(
                        AppLocalizations.of(context).medicatieBeheren,
            () => Navigator.pushNamed(context, '/medication'),
          ),
          const SizedBox(height: 8),
          _buildSectionHeader(AppLocalizations.of(context).backupHerstel),
          _buildBackupButtons(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildBackupButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAutoBackupKeuze(),
        const SizedBox(height: 12),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  /// Keuze voor de automatische backup: Uit / Elke dag / Elke 3 dagen /
  /// Elke week. Wordt direct weggeschreven; de backup zelf draait bij de
  /// volgende opstart als het interval verstreken is. Daaronder staat
  /// wanneer de laatste automatische backup gemaakt is.
  ///
  /// Bovenaan: de backupmap (SAF). Zonder gekozen map belandt de backup in
  /// de app-map en is hij weg bij verwijderen — vandaar de waarschuwing.
  Widget _buildAutoBackupKeuze() {
    final l10n = AppLocalizations.of(context);
    final mapNaam = _settings?[BackupMapService.mapNaamKey]?.toString();
    final freq = _settings?[BackupService.autoBackupFreqKey]?.toString() ?? BackupService.freqStandaard;
    final laatste = _settings?[BackupService.lastAutoBackupKey]?.toString();
    String label(String v) {
      if (v == BackupService.freqDagelijks) return l10n.freqDagelijks;
      if (v == BackupService.freq3Dagen) return l10n.freq3Dagen;
      if (v == BackupService.freqWeek) return l10n.freqWeek;
      return l10n.freqUit;
    }

    String laatsteTekst() {
      if (laatste == null || laatste.isEmpty) return l10n.autoBackupNooit;
      final dt = DateTime.tryParse(laatste);
      if (dt == null) return l10n.autoBackupNooit;
      final datum = '${dt.day}-${dt.month}-${dt.year}';
      return l10n.laatsteAutoBackup(datum);
    }

    const opties = [
      BackupService.freqUit,
      BackupService.freqDagelijks,
      BackupService.freq3Dagen,
      BackupService.freqWeek,
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.backupMapTitel,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (mapNaam == null || mapNaam.isEmpty) ? l10n.geenMap : mapNaam,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: (mapNaam == null || mapNaam.isEmpty)
                            ? AppTheme.warning
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (mapNaam == null || mapNaam.isEmpty)
                      Text(
                        l10n.geenMapUitleg,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _kiesBackupMap,
                child: Text(l10n.kiesMap),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            l10n.backupFrequentie,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: opties
                .map((v) => ChoiceChip(
                      label: Text(label(v)),
                      selected: freq == v,
                      onSelected: (_) => _setBackupFreq(v),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            laatsteTekst(),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// Schrijft de backupfrequentie direct weg (zelfde patroon als de
  /// check-in-instellingen: geen Opslaan-knop nodig).
  Future<void> _setBackupFreq(String freq) async {
    try {
      final existing = await db.getSettings();
      final merged = Map<String, dynamic>.from(existing ?? {});
      merged[BackupService.autoBackupFreqKey] = freq;
      await db.updateSettingsMap(merged);
      if (mounted) setState(() => _settings = merged);
    } catch (e, stackTrace) {
      AppLogger.error('Backupfrequentie opslaan mislukt', error: e, stackTrace: stackTrace);
      if (mounted) _showError(AppLocalizations.of(context).konInstellingenNietOpslaan);
    }
  }

  /// Opent de systeemkiezer voor de backupmap (SAF) en herlaadt daarna de
  /// instellingen, zodat de gekozen mapnaam meteen in beeld staat.
  Future<void> _kiesBackupMap() async {
    try {
      await BackupMapService.kiesBackupMap();
      final vers = await db.getSettings();
      if (mounted) setState(() => _settings = vers);
    } catch (e, stackTrace) {
      AppLogger.error('Backupmap kiezen mislukt', error: e, stackTrace: stackTrace);
      if (mounted) _showError(AppLocalizations.of(context).konInstellingenNietOpslaan);
    }
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
        const SizedBox(height: 4),
        Text(
          '${AppLocalizations.of(context).tijdzone}: ${NotificationHelper.tijdzoneNaam}',
          style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                  fontSize: 16,
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

  Widget _buildTextField(String label, TextEditingController controller,
      {ValueChanged<String>? onChanged, VoidCallback? onEditingAfgerond}) {
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
        onChanged: onChanged,
        onEditingComplete: onEditingAfgerond,
        onTapOutside: (_) => onEditingAfgerond?.call(),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
      ),
    );
  }

  Widget _buildTimeField(String label, String key,
      {Future<void> Function(String tijd)? onSaved}) {
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
        onTap: () => _showTimePicker(label, key, onSaved: onSaved),
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
              fontSize: 16,
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
}
