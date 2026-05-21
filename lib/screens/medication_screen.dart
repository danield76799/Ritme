import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';
import '../service_locator.dart';
import '../widgets/datum_navigator.dart';
import '../utils/logger.dart';
import '../services/notification_helper.dart';

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
      final intakes = await db.getMedicationIntake(_formattedDate);

      Map<int, int> intakeMap = {};
      for (var intake in intakes) {
        // Handle both String and int types for medication_id
        dynamic rawMedId = intake['medication_id'];
        int? medId;
        if (rawMedId is int) {
          medId = rawMedId;
        } else if (rawMedId is String) {
          medId = int.tryParse(rawMedId);
        }
        
        // Handle both String and int types for aantal_ingenomen
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

      setState(() {
        _configs = configs;
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
      
      // If reminder time is set, also create a schedule and notification
      if (reminderTime != null && reminderEnabled) {
        final timeStr = '${reminderTime.hour.toString().padLeft(2, '0')}:${reminderTime.minute.toString().padLeft(2, '0')}';
        await db.insertMedicationSchedule(id, timeStr, '1,2,3,4,5,6,7');
        
        // Schedule push notification
        try {
          await NotificationHelper.instance.scheduleMedicationReminder(
            medicationId: id,
            medicationName: name,
            dosage: '$dosage $unit',
            time: timeStr,
            daysOfWeek: [1, 2, 3, 4, 5, 6, 7], // Daily
          );
          
          // Show immediate test notification to confirm it works
          await NotificationHelper.instance.showTestNotification();
          
          // Debug: Show pending notifications
          try {
            final pending = await NotificationHelper.instance.getPendingNotificationCount();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Geplande notificaties: $pending'),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          } catch (e) {
            debugPrint('Error checking pending: $e');
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Herinnering gezet voor $name om $timeStr'),
                backgroundColor: Colors.green[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (notifError) {
          AppLogger.error('Notification scheduling failed', error: notifError);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Medicatie opgeslagen, maar herinnering kon niet worden gezet: $notifError'),
                backgroundColor: Colors.orange[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
      
      _loadData();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to add medication', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kon medicatie niet toevoegen. Probeer opnieuw.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _updateIntake(int configId, int change) async {
    try {
      int current = _intakesForDay[configId] ?? 0;
      int newVal = current + change;
      if (newVal < 0) return;

      await db.insertMedicationIntakeMap({
        'medication_id': configId,
        'date': _formattedDate,
        'aantal_ingenomen': newVal,
      });
      _loadData();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update medication intake', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kon inname niet bijwerken. Probeer opnieuw.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _deleteMedication(int configId) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Medicatie verwijderen?'),
          content: const Text('Deze actie kan niet ongedaan worden. Alle innamegegevens voor deze medicatie worden ook verwijderd.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuleren'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Verwijderen', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Cancel notification before deleting
        await NotificationHelper.instance.cancelMedicationReminder(configId);
        
        await db.deleteMedicationConfig(configId);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Medicatie verwijderd'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete medication', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kon medicatie niet verwijderen. Probeer opnieuw.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }


  Future<void> _editMedicationReminderTime(int configId, String name, bool reminderEnabled, String currentTime) async {
    // Parse current time
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
        await db.updateMedicationConfig(configId, {'reminder_time': newTimeStr});
        
        // Reschedule notification if reminders are enabled
        if (reminderEnabled) {
          await NotificationHelper.instance.scheduleMedicationReminder(
            medicationId: configId,
            medicationName: name,
            dosage: '',
            time: newTimeStr,
            daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
          );
        }

        _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Herinnertijd gewijzigd naar \$newTimeStr')),
          );
        }
      } catch (e) {
        debugPrint('Error updating reminder time: \$e');
      }
    }
  }
  Future<void> _resetDatabase() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Database resetten?'),
          content: const Text('Dit wist ALLE data inclusief medicatie, stemmingen, en instellingen. Dit kan niet ongedaan worden gemaakt.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuleren'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Resetten', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await db.clearAllData();
        
        // Cancel all notifications
        await NotificationHelper.instance.cancelAllReminders();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Database gereset. Herstart de app.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        
        _loadData();
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to reset database', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kon database niet resetten.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
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
        builder: (context, setDialogState) => Theme(
          data: ThemeData.light().copyWith(
            dialogBackgroundColor: Colors.white,
            textTheme: const TextTheme(bodyLarge: TextStyle(color: Colors.black)),
          ),
          child: AlertDialog(
            title: const Text('Nieuwe Medicatie', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Naam (bijv. Lithium)',
                      labelStyle: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
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
                      borderSide: const BorderSide(color: AppTheme.primaryTeal, width: 2),
                    ),
                  ),
                  onChanged: (v) => name = v,
                ),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Dosering',
                    labelStyle: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
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
                      borderSide: const BorderSide(color: AppTheme.primaryTeal, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => dosage = double.tryParse(v) ?? 0,
                ),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Eenheid (mg, ml, stuks)',
                    labelStyle: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
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
                      borderSide: const BorderSide(color: AppTheme.primaryTeal, width: 2),
                    ),
                  ),
                  onChanged: (v) => unit = v,
                ),
                const SizedBox(height: 16),
                // Reminder toggle
                Row(
                  children: [
                    const Text('Herinnering'),
                    const Spacer(),
                    Switch(
                      value: reminderEnabled,
                      onChanged: (value) {
                        setDialogState(() {
                          reminderEnabled = value;
                        });
                      },
                      activeColor: AppTheme.primaryTeal,
                    ),
                  ],
                ),
                // Time picker (only if reminder enabled)
                if (reminderEnabled)
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: reminderTime ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          reminderTime = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tijdstip herinnering',
                      ),
                      child: Text(
                        reminderTime == null 
                          ? 'Selecteer tijd' 
                          : '${reminderTime!.hour.toString().padLeft(2, '0')}:${reminderTime!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: reminderTime == null ? Colors.grey : Colors.black,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuleer'),
            ),
            ElevatedButton(
              onPressed: () {
                if (name.isNotEmpty) {
                  _addMedication(name, dosage, unit, reminderEnabled: reminderEnabled, reminderTime: reminderTime);
                }
                Navigator.pop(context);
              },
              child: const Text('Opslaan'),
            ),
          ],
        ),
      ),
    ),
  );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Medicatie',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddMedicationDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: _resetDatabase,
            tooltip: 'Reset database',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: DatumNavigator(
              geselecteerdeDatum: _selectedDate,
              onDatumVeranderd: _onDatumVeranderd,
            ),
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
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: TextStyle(fontSize: 16, color: Colors.red[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Opnieuw proberen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
            ),
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
          Icon(Icons.medication_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Geen medicatie',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            'Tik + om toe te voegen',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
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
    // Handle both int and String ids from Hive
    dynamic rawId = config['id'];
    int? configId;
    if (rawId is int) {
      configId = rawId;
    } else if (rawId is String) {
      configId = int.tryParse(rawId);
    }
    if (configId == null) {
      print('Skipping invalid medication entry - id: $rawId, type: ${rawId.runtimeType}');
      return const SizedBox.shrink(); // Skip invalid entries
    }
    int count = _intakesForDay[configId] ?? 0;
    String name = config['naam']?.toString() ?? 'Onbekend';
    String dosage = '${config['dosering']?.toString() ?? ''} ${config['eenheid']?.toString() ?? ''}';
    bool reminderEnabled = (config['reminder_enabled']?.toString() ?? '1') == '1';
    String? reminderTime = config['reminder_time']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.medication, color: AppTheme.primaryTeal, size: 24),
          ),
          // Name & dosage
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textCharcoal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dosage,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  if (reminderTime != null)
                    InkWell(
                      onTap: () => _editMedicationReminderTime(configId!, name, reminderEnabled, reminderTime),
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            reminderEnabled ? Icons.notifications_active : Icons.notifications_off,
                            size: 12,
                            color: reminderEnabled ? AppTheme.primaryTeal : Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            reminderTime,
                            style: TextStyle(
                              fontSize: 11,
                              color: reminderEnabled ? AppTheme.primaryTeal : Colors.grey[400],
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.edit,
                            size: 10,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Counter
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCounterBtn(
                icon: Icons.remove,
                onPressed: count > 0 ? () => _updateIntake(configId!, -1) : null,
              ),
              Container(
                width: 36,
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textCharcoal,
                  ),
                ),
              ),
              _buildCounterBtn(
                icon: Icons.add,
                onPressed: () => _updateIntake(configId!, 1),
                isPrimary: true,
              ),
              const SizedBox(width: 8),
              _buildDeleteBtn(
                onPressed: () => _deleteMedication(configId!),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildCounterBtn({
    required IconData icon,
    required VoidCallback? onPressed,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isPrimary ? AppTheme.primaryTeal : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isPrimary ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteBtn({
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.delete_outline,
            size: 18,
            color: Colors.red[400],
          ),
        ),
      ),
    );
  }
}
