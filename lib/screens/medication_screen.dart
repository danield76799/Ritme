import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../service_locator.dart';
import '../widgets/datum_navigator.dart';
import '../utils/logger.dart';
import '../services/notification_helper.dart';
import '../generated/l10n/app_localizations.dart';

class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _configs = [];
  Map<int, int> _intakesForDay = {};
  bool _isLoading = true;
  String? _errorMessage;

  String get _formattedDate {
    return DateFormat('yyyy-MM-dd').format(_selectedDate);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final configs = await db.getMedicationConfigs();
      final schedules = await db.getMedicationSchedules();
      final intakes = await db.getMedicationIntake(_formattedDate);
      Map<int, int> intakeMap = {};
      for (var intake in intakes) {
        dynamic rawMedId = intake['medication_id'];
        int? medId;
        if (rawMedId is int) {
          medId = rawMedId;
        } else if (rawMedId is String) {
          medId = int.tryParse(rawMedId);
        }
        dynamic rawAantal = intake['aantal_ingenomen'];
        int? aantal;
        if (rawAantal is int) {
          aantal = rawAantal;
        } else if (rawAantal is String) {
          aantal = int.tryParse(rawAantal) ?? 0;
        } else {
          aantal = 0;
        }
        if (medId != null) {
          intakeMap[medId] = aantal;
        }
      }

      // Combineer configs met reminder_time uit medication_schedule
      final mergedConfigs = configs.map((config) {
        dynamic rawId = config['id'];
        int? configId;
        if (rawId is int) {
          configId = rawId;
        } else if (rawId is String) {
          configId = int.tryParse(rawId);
        }
        final schedule = schedules.firstWhere(
          (s) {
            dynamic rawSchedId = s['medication_id'];
            int? schedId;
            if (rawSchedId is int) schedId = rawSchedId;
            else if (rawSchedId is String) schedId = int.tryParse(rawSchedId);
            return schedId != null && schedId == configId;
          },
          orElse: () => {},
        );
        return {
          ...config,
          'reminder_time': schedule['reminder_time']?.toString(),
          'days_of_week': schedule['days_of_week']?.toString() ?? '1,2,3,4,5,6,7',
          'schedule_id': schedule['id'],
        };
      }).toList();

      setState(() {
        _configs = mergedConfigs;
        _intakesForDay = intakeMap;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load medication data', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Kon medicatiegegevens niet laden.\n\nFout: $e';
        _isLoading = false;
      });
    }
  }

  void _onDatumVeranderd(DateTime nieuweDatum) {
    setState(() => _selectedDate = nieuweDatum);
    _loadData();
  }

  Future<void> _addMedication(String name, double dosage, String unit, {bool reminderEnabled = true, TimeOfDay? reminderTime}) async {
    try {
      final id = await db.insertMedicationConfig(name, dosage.toString(), unit, reminderEnabled: reminderEnabled);
      if (reminderTime != null && reminderEnabled) {
        final timeStr = '${reminderTime.hour.toString().padLeft(2, '0')}:${reminderTime.minute.toString().padLeft(2, '0')}';
        await db.insertMedicationSchedule(id, timeStr, '1,2,3,4,5,6,7');
        try {
          await NotificationHelper.instance.scheduleMedicationReminder(
            id: id,
            medicationName: name,
            time: timeStr,
            days: [1, 2, 3, 4, 5, 6, 7],
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context).herinneringGezet(name, timeStr)),
                backgroundColor: Colors.green[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (notifError) {
          AppLogger.error('Notification scheduling failed', error: notifError);
        }
      }
      _loadData();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to add medication', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _toggleIntake(int configId) async {
    try {
      final current = _intakesForDay[configId] ?? 0;
      final newVal = current > 0 ? 0 : 1;
      await db.insertMedicationIntakeMap({
        'medication_id': configId,
        'date': _formattedDate,
        'aantal_ingenomen': newVal,
      });
      _loadData();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to toggle medication intake', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _deleteMedication(int configId) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context).medicatieVerwijderen),
          content: Text(AppLocalizations.of(context).dezeActieOngedaan),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context).annuleren)),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(AppLocalizations.of(context).verwijderen, style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await NotificationHelper.instance.cancelMedicationReminder(configId);
        await db.deleteMedicationConfig(configId);
        _loadData();
      }
    } catch (e) {
      AppLogger.error('Failed to delete medication', error: e);
    }
  }

  Future<void> _editMedicationReminderTime(int configId, String name, bool reminderEnabled, String currentTime) async {
    final parts = currentTime.split(':');
    TimeOfDay reminderTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: reminderTime,
      helpText: 'Wijzig herinnertijd voor $name',
    );
    if (picked != null) {
      final newTimeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      try {
        // Cancel any prior scheduled notification for this medication before
        // re-scheduling, so we don't end up with a stale notification at the
        // old time.
        await NotificationHelper.instance.cancelMedicationReminder(configId);

        // Wipe all existing schedules for this medication and insert exactly
        // one fresh row. This prevents duplicate schedule rows from
        // accumulating (e.g. from older versions that inserted a new row
        // instead of updating).
        final schedules = await db.getMedicationSchedules();
        for (final s in schedules) {
          dynamic rawMedId = s['medication_id'];
          int? schedMedId;
          if (rawMedId is int) {
            schedMedId = rawMedId;
          } else if (rawMedId is String) {
            schedMedId = int.tryParse(rawMedId);
          }
          if (schedMedId == configId && s['id'] != null) {
            final scheduleId = s['id'] is int
                ? s['id'] as int
                : int.tryParse(s['id'].toString());
            if (scheduleId != null) {
              await db.deleteMedicationSchedule(scheduleId);
            }
          }
        }
        await db.insertMedicationSchedule(configId, newTimeStr, '1,2,3,4,5,6,7');

        if (reminderEnabled) {
          await NotificationHelper.instance.scheduleMedicationReminder(
            id: configId,
            medicationName: name,
            time: newTimeStr,
            days: [1, 2, 3, 4, 5, 6, 7],
          );
        }
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).herinnertijdGewijzigd(newTimeStr))),
          );
        }
      } catch (e) {
        debugPrint('Error updating reminder time: $e');
      }
    }
  }

  Future<void> _resetDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).databaseResetten),
        content: Text(AppLocalizations.of(context).wistAlleData),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context).annuleren)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context).resetten, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await db.clearAllData();
      await NotificationHelper.instance.cancelAllReminders();
      _loadData();
    }
  }

  void _showAddMedicationDialog() {
    String name = '';
    double dosage = 0;
    String unit = 'mg';
    TimeOfDay? reminderTime;
    bool reminderEnabled = true;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Theme(
            data: ThemeData.light().copyWith(
              dialogBackgroundColor: Colors.white,
              textTheme: TextTheme(bodyLarge: TextStyle(color: Colors.black)),
            ),
            child: AlertDialog(
              title: Text(AppLocalizations.of(context).nieuweMedicatie, style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Naam
                    TextField(
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).naamBijvLithium,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (v) => name = v,
                    ),
                    const SizedBox(height: 12),
                    // Dosering + eenheid op één rij
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context).dosering,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) => dosage = double.tryParse(v.replaceAll(',', '.')) ?? 0,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 96,
                          child: DropdownButtonFormField<String>(
                            initialValue: unit,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context).eenheidMgMlStuks,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            ),
                            items: ['mg', 'ml', 'stuks', 'µg', 'IE']
                                .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 15))))
                                .toList(),
                            onChanged: (v) => setDialogState(() => unit = v ?? 'mg'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Herinnering-switch als eigen rij, netjes uitgelijnd
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(AppLocalizations.of(context).herinnering, style: TextStyle(color: Colors.black, fontSize: 16)),
                      value: reminderEnabled,
                      onChanged: (value) => setDialogState(() => reminderEnabled = value),
                      activeColor: AppTheme.primaryTeal,
                    ),
                    if (reminderEnabled)
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: reminderTime ?? TimeOfDay.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => reminderTime = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context).tijdstipHerinnering,
                            filled: true,
                            fillColor: Colors.grey.shade200,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            reminderTime == null
                              ? AppLocalizations.of(context).selecteerTijdMed
                              : '${reminderTime!.hour.toString().padLeft(2, '0')}:${reminderTime!.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(color: Colors.black, fontSize: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context).annuleer)),
                ElevatedButton(
                  onPressed: () {
                    if (name.isNotEmpty) {
                      _addMedication(name, dosage, unit, reminderEnabled: reminderEnabled, reminderTime: reminderTime);
                    }
                    Navigator.pop(context);
                  },
                  child: Text(AppLocalizations.of(context).opslaan),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _checkNotificationPermissions() async {
    final granted = await NotificationHelper.instance.requestNotificationPermissions();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).notificatiepermissieGeweigerdZetDeze)),
      );
      return;
    }

    final batteryOpt = await NotificationHelper.instance.openBatteryOptimizationSettings();
    if (!batteryOpt && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).accuOptimalisatieNotificatiesBlokkeren)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).medicatie, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
        actions: [
          IconButton(icon: Icon(Icons.add), onPressed: _showAddMedicationDialog),
          IconButton(
            icon: Icon(Icons.notifications_active_outlined),
            tooltip: AppLocalizations.of(context).notificatiepermissiesControleren,
            onPressed: _checkNotificationPermissions,
          ),
          IconButton(icon: Icon(Icons.delete_forever, color: Colors.red), onPressed: _resetDatabase),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: DatumNavigator(geselecteerdeDatum: _selectedDate, onDatumVeranderd: _onDatumVeranderd),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
                : _errorMessage != null
                    ? _buildErrorState()
                    : _configs.isEmpty
                        ? _buildEmptyState()
                        : _buildMedList(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
          SizedBox(height: 12),
          Text(_errorMessage!, style: TextStyle(fontSize: 16, color: Colors.red[600]), textAlign: TextAlign.center),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context).opnieuwProberen),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medication_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context).geenMedicatie, style: TextStyle(fontSize: 16, color: Color(0xFF333333))),
          const SizedBox(height: 4),
          Text(AppLocalizations.of(context).tikToeVoegen, style: TextStyle(fontSize: 13, color: Color(0xFF555555))),
        ],
      ),
    );
  }

  Widget _buildMedList() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _configs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _buildCompactMedCard(_configs[i]),
    );
  }

  Widget _buildCompactMedCard(Map<String, dynamic> config) {
    dynamic rawId = config['id'];
    int? configId;
    if (rawId is int) configId = rawId; else if (rawId is String) configId = int.tryParse(rawId);
    if (configId == null) return SizedBox.shrink();
    int count = _intakesForDay[configId] ?? 0;
    String name = config['naam']?.toString() ?? AppLocalizations.of(context).onbekend;
    String dosage = '${config['dosering']?.toString() ?? ''} ${config['eenheid']?.toString() ?? ''}';
    bool reminderEnabled = (config['reminder_enabled']?.toString() ?? '1') == '1';
    String? reminderTime = config['reminder_time']?.toString();

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48, margin: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(color: AppTheme.primaryTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.medication, color: AppTheme.primaryTeal, size: 24),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal)),
                  const SizedBox(height: 2),
                  Text(dosage, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: InkWell(
                      onTap: () => _editMedicationReminderTime(configId!, name, reminderEnabled, reminderTime ?? '08:00'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: reminderTime != null
                              ? (reminderEnabled ? AppTheme.primaryTeal.withValues(alpha: 0.1) : Colors.grey.shade100)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: reminderTime != null
                              ? (reminderEnabled ? AppTheme.primaryTeal.withValues(alpha: 0.4) : Colors.grey.shade300!)
                              : Colors.grey.shade400),
                          boxShadow: reminderTime != null && reminderEnabled ? [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))] : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(reminderTime != null
                                ? (reminderEnabled ? Icons.access_time_filled : Icons.notifications_off)
                                : Icons.access_time,
                                size: 14,
                                color: reminderTime != null
                                    ? (reminderEnabled ? AppTheme.primaryTeal : Colors.grey.shade400)
                                    : Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Text(
                              reminderTime ?? AppLocalizations.of(context).stelTijdIn,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: reminderTime != null
                                    ? (reminderEnabled ? AppTheme.primaryTeal : Colors.grey.shade500)
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.edit_calendar, size: 12, color: reminderTime != null ? (reminderEnabled ? AppTheme.primaryTeal : Colors.grey.shade400) : Colors.grey.shade500),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIntakeToggleBtn(
                configId: configId,
                taken: count > 0,
              ),
              const SizedBox(width: 8),
              _buildDeleteBtn(onPressed: () => _deleteMedication(configId!)),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildCounterBtn({required IconData icon, required VoidCallback? onPressed, bool isPrimary = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: isPrimary ? AppTheme.primaryTeal : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: isPrimary ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  Widget _buildIntakeToggleBtn({required int configId, required bool taken}) {
    final l10n = AppLocalizations.of(context);
    final label = taken ? l10n.medicatieGenomen : l10n.medicatieNietGenomen;
    final icon = taken ? Icons.check_circle : Icons.add_circle_outline;
    final bg = taken ? AppTheme.primaryTeal : Colors.grey.shade100;
    final fg = taken ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleIntake(configId),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: taken ? Colors.white : Colors.grey.shade600),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteBtn({required VoidCallback? onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
        ),
      ),
    );
  }
}
