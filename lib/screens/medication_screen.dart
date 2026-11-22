import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../service_locator.dart';
import '../utils/adherentie.dart';
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
  // Zacht-verwijderde medicatie: blijft zichtbaar (alleen-lezen) zodat de
  // inname-historie in eerdere dagen zichtbaar blijft.
  List<Map<String, dynamic>> _stoppedConfigs = [];
  Map<int, int> _intakesForDay = {};
  Map<int, String> _intakeDoseringForDay = {}; // per-dag dosering snapshot
  Map<int, Adherentie> _adherentie = {};
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
      final allConfigs = await db.getMedicationConfigsAll();
      final stopped = <Map<String, dynamic>>[];
      for (final c in allConfigs) {
        final del = c['deleted'];
        final isDeleted = del == 1 || del == '1' || del == true;
        if (isDeleted) stopped.add(c);
      }
      final schedules = await db.getMedicationSchedules();
      final intakes = await db.getMedicationIntake(_formattedDate);
      Map<int, int> intakeMap = {};
      // Adherentie per medicatie over de laatste 30 dagen (of sinds aanmaak).
      // Alleen voor vaste (niet-zo-nodig) medicatie.
      Map<int, Adherentie> adherentie = {};
      try {
        final nu = DateTime.now();
        final start = DateTime(nu.year, nu.month, nu.day).subtract(const Duration(days: 29));
        final fmt = DateFormat('yyyy-MM-dd');
        final range = await db.getMedicationIntakeRange(fmt.format(start), fmt.format(nu));
        adherentie = berekenAdherentie(
          intakes: range,
          configs: configs,
          vandaag: nu,
        );
      } catch (e) {
        AppLogger.error('Adherentie berekenen mislukt', error: e);
      }
      Map<int, String> doseringMap = {};
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
          // Alleen dosering opslaan als die expliciet gezet is (niet null/leeg)
          final d = intake['dosering']?.toString();
          if (d != null && d.isNotEmpty) {
            doseringMap[medId] = d;
          }
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
            if (rawSchedId is int) {
              schedId = rawSchedId;
            } else if (rawSchedId is String) schedId = int.tryParse(rawSchedId);
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
        _stoppedConfigs = stopped;
        _intakesForDay = intakeMap;
        _intakeDoseringForDay = doseringMap;
        _adherentie = adherentie;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load medication data', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = AppLocalizations.of(context).medicatieLadenMislukt;
        _isLoading = false;
      });
    }
  }

  void _onDatumVeranderd(DateTime nieuweDatum) {
    setState(() => _selectedDate = nieuweDatum);
    _loadData();
  }

  Future<void> _addMedication(String name, double dosage, String unit, {bool reminderEnabled = true, TimeOfDay? reminderTime, bool zoNodig = false}) async {
    name = name.trim();
    if (name.isEmpty) return;
    try {
      // 'Zo nodig'-medicatie krijgt nooit een herinnering: het is geen verplichting.
      final id = await db.insertMedicationConfig(name, dosage.toString(), unit, reminderEnabled: reminderEnabled && !zoNodig, zoNodig: zoNodig);
      if (!zoNodig && reminderTime != null && reminderEnabled) {
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
                // Colors.green[700] gaf witte tekst maar 4.12:1;
                // AppTheme.success haalt 5.13:1.
                backgroundColor: AppTheme.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.smallRadius)),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (notifError) {
          AppLogger.error('Notification scheduling failed', error: notifError);
        }
      }
      // Forceer een synchrone refresh zodat de nieuwe medicatie (incl. eenheid)
      // zichtbaar is voordat het dialoogvenster volledig sluit.
      if (mounted) _loadData();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadData();
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to add medication', error: e, stackTrace: stackTrace);
    }
  }

  bool _isZoNodig(Map<String, dynamic> config) {
    final v = config['zo_nodig'];
    return v == 1 || v == '1' || v == true;
  }

  Future<void> _setPrnCount(int configId, int newCount) async {
    final clamped = newCount.clamp(0, 99);
    try {
      // Bewaar een bestaande per-dag-dosering als die er is; anders de config.
      final existingIntakes = await db.getMedicationIntake(_formattedDate);
      final existing = existingIntakes.firstWhere(
        (i) {
          final rawId = i['medication_id'];
          if (rawId is int) return rawId == configId;
          if (rawId is String) return int.tryParse(rawId) == configId;
          return false;
        },
        orElse: () => {},
      );
      String dosering = existing['dosering']?.toString() ?? '';
      if (dosering.isEmpty) {
        final config = _configs.firstWhere(
          (c) {
            final rawId = c['id'];
            if (rawId is int) return rawId == configId;
            if (rawId is String) return int.tryParse(rawId) == configId;
            return false;
          },
          orElse: () => {},
        );
        dosering = config['dosering']?.toString() ?? '';
      }
      await db.insertMedicationIntakeMap({
        'medication_id': configId,
        'date': _formattedDate,
        'aantal_ingenomen': clamped,
        'dosering': dosering,
      });
      _loadData();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set intake count', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _toggleIntake(int configId) async {
    try {
      final current = _intakesForDay[configId] ?? 0;
      final newVal = current > 0 ? 0 : 1;
      // Behoud bestaande dosering als die er is; anders huidige config
      final existingIntakes = await db.getMedicationIntake(_formattedDate);
      final existing = existingIntakes.firstWhere(
        (i) {
          final rawId = i['medication_id'];
          if (rawId is int) return rawId == configId;
          if (rawId is String) return int.tryParse(rawId) == configId;
          return false;
        },
        orElse: () => {},
      );
      String dosering = existing['dosering']?.toString() ?? '';
      if (dosering.isEmpty) {
        final config = _configs.firstWhere(
          (c) {
            final rawId = c['id'];
            if (rawId is int) return rawId == configId;
            if (rawId is String) return int.tryParse(rawId) == configId;
            return false;
          },
          orElse: () => {},
        );
        dosering = config['dosering']?.toString() ?? '';
      }
      await db.insertMedicationIntakeMap({
        'medication_id': configId,
        'date': _formattedDate,
        'aantal_ingenomen': newVal,
        'dosering': dosering,
      });
      // Afgevinkt of weer verwijderd — medicatie-herinneringen van vandaag
      // aanpassen (goed) zodat een ingevulde medicatie vandaag niet meer pingt.
      try {
        await NotificationHelper.instance.rescheduleAllMedicationReminders();
      } catch (e) {
        AppLogger.error('Herplannen medicatie-herinnering mislukt', error: e);
      }
      _loadData();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to toggle medication intake', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _editIntakeDosering(int configId, String medName, String currentDosering) async {
    final controller = TextEditingController(text: currentDosering);
    final confirmed = await showDialog<String>(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text('$medName — dosering'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Bijv. 5 of 2.5',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.smallRadius)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context).annuleer)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(AppLocalizations.of(context).opslaan),
            ),
          ],
        );
      },
    );
    if (confirmed == null || confirmed.isEmpty) return;

    // Huidige standaarddosis uit de config opzoeken, zodat we die kunnen
    // vergelijken met de nieuwe per-dag dosering.
    final config = _configs.firstWhere(
      (c) {
        final rawId = c['id'];
        final cfgId = rawId is int ? rawId : (rawId is String ? int.tryParse(rawId) : null);
        return cfgId == configId;
      },
      orElse: () => {},
    );
    final standaard = config['dosering']?.toString() ?? '';

    try {
      await db.insertMedicationIntakeMap({
        'medication_id': configId,
        'date': _formattedDate,
        'aantal_ingenomen': _intakesForDay[configId] ?? 0,
        'dosering': confirmed,
      });

      // Wijkt de per-dag dosering af van de standaarddosis, dan vragen of de
      // standaarddosis mee aangepast moet worden. Zo blijft de config in sync
      // met de werkelijke (structurele) dosisverandering.
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      if (standaard.isNotEmpty && standaard != confirmed) {
        final updateStandaard = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            final cs = Theme.of(dialogContext).colorScheme;
            return AlertDialog(
              title: Text(l10n.medStandaardTitel),
              content: Text(l10n.medStandaardBody(medName, confirmed, standaard)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(l10n.nee),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                  ),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(l10n.ja),
                ),
              ],
            );
          },
        );
        if (updateStandaard == true) {
          await db.updateMedicationConfig(configId, {'dosering': confirmed});
        }
      }

      _loadData();
    } catch (e) {
      AppLogger.error('Failed to edit intake dosage', error: e);
    }
  }

  String _configName(Map<String, dynamic> config) =>
      config['naam']?.toString() ?? AppLocalizations.of(context).onbekend;

  Future<void> _stopMedication(int configId, String name) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context).medicatieStoppenTitel),
          content: Text(AppLocalizations.of(context).medicatieStoppenBody(name)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context).annuleren)),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              child: Text(AppLocalizations.of(context).stoppen, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await NotificationHelper.instance.cancelMedicationReminder(configId);
        await db.deleteMedicationConfig(configId);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).medicatieGestoptSnack(name)),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.smallRadius)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Failed to stop medication', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).verwijderenMislukt),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.smallRadius)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _editMedication(Map<String, dynamic> config, int configId) async {
    String name = config['naam']?.toString() ?? '';
    double dosage = double.tryParse(config['dosering']?.toString() ?? '0') ?? 0;
    String unit = config['eenheid']?.toString() ?? 'mg';
    bool reminderEnabled = (config['reminder_enabled']?.toString() ?? '1') == '1';
    bool zoNodig = _isZoNodig(config);
    final wasZoNodig = zoNodig;

    await showDialog(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final textColor = cs.onSurface;
        final labelColor = cs.onSurfaceVariant;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog.adaptive(
              title: Text(AppLocalizations.of(context).medicatieWijzigen),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 340,
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: TextEditingController(text: name),
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).naamBijvLithium,
                        labelStyle: TextStyle(color: labelColor),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.smallRadius)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.smallRadius), borderSide: BorderSide(color: cs.outline)),
                      ),
                      onChanged: (v) => name = v,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(AppLocalizations.of(context).zoNodig, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                      subtitle: Text(AppLocalizations.of(context).zoNodigUitleg, style: TextStyle(color: labelColor, fontSize: 12)),
                      value: zoNodig,
                      onChanged: (value) => setDialogState(() => zoNodig = value),
                      activeThumbColor: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(text: dosage > 0 ? dosage.toString() : ''),
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context).dosering,
                              labelStyle: TextStyle(color: labelColor),
                              filled: true,
                              fillColor: cs.surfaceContainerHighest,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.smallRadius)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.smallRadius), borderSide: BorderSide(color: cs.outline)),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) => dosage = double.tryParse(v.replaceAll(',', '.')) ?? 0,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 96,
                          child: DropdownButtonFormField<String>(
                            style: TextStyle(color: textColor),
                            dropdownColor: cs.surface,
                            initialValue: unit,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context).eenheidMgMlStuks,
                              labelStyle: TextStyle(color: labelColor),
                              filled: true,
                              fillColor: cs.surfaceContainerHighest,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.smallRadius)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.smallRadius), borderSide: BorderSide(color: cs.outline)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            ),
                            items: ['mg', 'ml', 'stuks', 'µg', 'IE']
                                .map((u) => DropdownMenuItem(value: u, child: Text(u, style: TextStyle(color: textColor, fontSize: 16))))
                                .toList(),
                            onChanged: (v) => setDialogState(() => unit = v ?? 'mg'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
                ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context).annuleer, style: TextStyle(color: cs.primary))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
                  onPressed: () async {
                    if (name.isNotEmpty) {
                      await db.updateMedicationConfig(configId, {
                        'naam': name,
                        'dosering': dosage.toString(),
                        'eenheid': unit,
                        'zo_nodig': zoNodig ? 1 : 0,
                        'reminder_enabled': (zoNodig || !reminderEnabled) ? 0 : 1,
                      });
                      if (zoNodig && !wasZoNodig) {
                        // Schakel de herinnering helemaal uit: planningen wissen
                        // en de geplande notificaties annuleren.
                        try {
                          final schedules = await db.getMedicationSchedules();
                          for (final s in schedules) {
                            dynamic rawMedId = s['medication_id'];
                            int? schedMedId = rawMedId is int ? rawMedId : int.tryParse(rawMedId?.toString() ?? '');
                            final scheduleId = s['id'] is int ? s['id'] as int : int.tryParse(s['id']?.toString() ?? '');
                            if (schedMedId == configId && scheduleId != null) {
                              await db.deleteMedicationSchedule(scheduleId);
                            }
                          }
                          await NotificationHelper.instance.cancelMedicationReminder(configId);
                        } catch (e) {
                          AppLogger.error('Zo-nodig: herinneringen wissen mislukt', error: e);
                        }
                      }
                      if (!mounted) return;
                      _loadData();
                    }
                    if (mounted && context.mounted) Navigator.pop(context);
                  },
                  child: Text(AppLocalizations.of(context).opslaan),
                ),
              ],
            );
          },
        );
      },
    );
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
      helpText: AppLocalizations.of(context).wijzigHerinnertijdVoor(name),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text(AppLocalizations.of(context).resetten, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await db.clearAllData();
      // cancelAll() wist ALLE notificaties, dus ook de check-in herinneringen.
      // Na een reset staan de instellingen weer op de standaardwaarden, dus
      // opnieuw plannen geeft de gebruiker meteen de verwachte meldingen terug
      // in plaats van stilte tot de volgende app-start.
      await NotificationHelper.instance.cancelAllReminders();
      await NotificationHelper.instance.rescheduleCheckinReminders();
      _loadData();
    }
  }

  String _normalizeMedName(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Zoekt een bestaande kaart met dezelfde naam (actief heeft voorrang).
  Map<String, dynamic>? _findDuplicateMedication(String name) {
    final n = _normalizeMedName(name);
    if (n.isEmpty) return null;
    for (final c in _configs) {
      if (_normalizeMedName(c['naam']?.toString() ?? '') == n) return c;
    }
    for (final c in _stoppedConfigs) {
      if (_normalizeMedName(c['naam']?.toString() ?? '') == n) return c;
    }
    return null;
  }

  /// Vraag wat te doen bij een dubbele naam. Geeft 'add', 'edit', 'restart' of null.
  Future<String?> _askDuplicateChoice(Map<String, dynamic> match) {
    final cs = Theme.of(context).colorScheme;
    final bestaatActief = _configs.any((c) => identical(c, match) || c['id'] == match['id']);
    final naam = match['naam']?.toString() ?? '';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(bestaatActief
            ? AppLocalizations.of(context).medicatieBestaat(naam)
            : AppLocalizations.of(context).medicatieBestaatGestopt(naam),
            style: TextStyle(color: cs.onSurface)),
        content: Text(AppLocalizations.of(context).medicatieBestaatUitleg,
            style: TextStyle(color: cs.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'add'),
            child: Text(AppLocalizations.of(context).tochApartToevoegen,
                style: TextStyle(color: cs.primary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, bestaatActief ? 'edit' : 'restart'),
            style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
            child: Text(bestaatActief
                ? AppLocalizations.of(context).bestaandeBewerken
                : AppLocalizations.of(context).opnieuwStarten),
          ),
        ],
      ),
    );
  }

  void _showAddMedicationDialog() {
    String name = '';
    double dosage = 0;
    String unit = 'mg';
    TimeOfDay? reminderTime;
    bool reminderEnabled = true;
    bool zoNodig = false;
    showDialog(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final textColor = cs.onSurface;
        final labelColor = cs.onSurfaceVariant;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: cs.surface,
              surfaceTintColor: Colors.transparent,
              title: Text(AppLocalizations.of(context).nieuweMedicatie, style: TextStyle(color: textColor)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 340,
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Naam
                    TextField(
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).naamBijvLithium,
                        labelStyle: TextStyle(color: labelColor),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.smallRadius)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.smallRadius), borderSide: BorderSide(color: cs.outline)),
                      ),
                      onChanged: (v) => name = v,
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 6),
                    // Zo nodig: geen vaste verplichting/herinnering
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(AppLocalizations.of(context).zoNodig, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                      subtitle: Text(AppLocalizations.of(context).zoNodigUitleg, style: TextStyle(color: labelColor, fontSize: 12)),
                      value: zoNodig,
                      onChanged: (value) => setDialogState(() => zoNodig = value),
                      activeThumbColor: Theme.of(context).colorScheme.primary,
                    ),
                    // Herinnering-switch als eigen rij, netjes uitgelijnd
                    if (!zoNodig) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(AppLocalizations.of(context).herinnering, style: TextStyle(color: textColor)),
                      value: reminderEnabled,
                      onChanged: (value) => setDialogState(() => reminderEnabled = value),
                      activeThumbColor: Theme.of(context).colorScheme.primary,
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
                            labelStyle: TextStyle(color: labelColor),
                            filled: true,
                            fillColor: cs.surfaceContainerHighest,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.smallRadius)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.smallRadius), borderSide: BorderSide(color: cs.outline)),
                          ),
                          child: Text(
                            reminderTime == null
                              ? AppLocalizations.of(context).selecteerTijdMed
                              : '${reminderTime!.hour.toString().padLeft(2, '0')}:${reminderTime!.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(color: textColor, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context).annuleer, style: TextStyle(color: cs.primary))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
                  onPressed: () async {
                    if (name.isEmpty) {
                      Navigator.pop(context);
                      return;
                    }
                    final dup = _findDuplicateMedication(name);
                    if (dup != null) {
                      final choice = await _askDuplicateChoice(dup);
                      if (!context.mounted) return;
                      if (choice == 'add') {
                        Navigator.pop(context);
                        await _addMedication(name, dosage, unit, reminderEnabled: reminderEnabled, reminderTime: reminderTime, zoNodig: zoNodig);
                      } else if (choice == 'edit') {
                        Navigator.pop(context);
                        final id = dup['id'] is int ? dup['id'] as int : int.tryParse(dup['id']?.toString() ?? '');
                        if (id != null) _editMedication(dup, id);
                      } else if (choice == 'restart') {
                        Navigator.pop(context);
                        final id = dup['id'] is int ? dup['id'] as int : int.tryParse(dup['id']?.toString() ?? '');
                        if (id != null) await _reactivateMedication(id);
                      }
                      // 'cancel' (null): niets doen, dialoog blijft staan
                      return;
                    }
                    Navigator.pop(context);
                    await _addMedication(name, dosage, unit, reminderEnabled: reminderEnabled, reminderTime: reminderTime, zoNodig: zoNodig);
                  },
                  child: Text(AppLocalizations.of(context).opslaan),
                ),
              ],
            );
          },
        );
      },
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
        title: Text(AppLocalizations.of(context).medicatie, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        actions: [
          IconButton(icon: Icon(Icons.add_rounded), tooltip: AppLocalizations.of(context).nieuweMedicatie, onPressed: _showAddMedicationDialog),
          IconButton(
            icon: Icon(Icons.notifications_active_outlined),
            tooltip: AppLocalizations.of(context).notificatiepermissiesControleren,
            onPressed: _checkNotificationPermissions,
          ),
          IconButton(
              icon: Icon(Icons.delete_forever_rounded,
                  // De AppBar is in dark mode LICHT en in light mode DONKER,
                  // dus de rode tint moet per mode de andere kant op. De oude
                  // Colors.red.shade300 haalde op beide balken <2:1 en was
                  // daardoor onzichtbaar — gevaarlijk voor een knop die de
                  // database wist.
                  color: AppTheme.dangerOnAppBar(Theme.of(context).brightness)),
              tooltip: AppLocalizations.of(context).resetten,
              onPressed: _resetDatabase),
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
                ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                : _errorMessage != null
                    ? _buildErrorState()
                    : (_configs.isEmpty && _stoppedConfigs.isEmpty)
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
          Icon(Icons.error_outline, size: 48, color: AppTheme.danger(context)),
          const SizedBox(height: 12),
          // red[600] zakte op de donkere kaart naar 3.15:1, precies wanneer er
          // iets mis is. danger() kiest per mode een leesbare tint.
          Text(_errorMessage!,
              style: TextStyle(fontSize: 16, color: AppTheme.danger(context)),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context).opnieuwProberen),
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary),
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
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            ),
            child: Icon(Icons.medication_rounded, size: 44, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context).geenMedicatie, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal)),
          const SizedBox(height: 4),
          Text(AppLocalizations.of(context).tikToeVoegen, style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textMedium)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showAddMedicationDialog,
            icon: Icon(Icons.add_rounded),
            label: Text(AppLocalizations.of(context).nieuweMedicatie),
          ),
        ],
      ),
    );
  }

  Widget _buildMedList() {
    final vast = _configs.where((c) => !_isZoNodig(c)).toList();
    final nodig = _configs.where((c) => _isZoNodig(c)).toList();
    final showHeaders = vast.isNotEmpty && nodig.isNotEmpty;
    final items = <Widget>[
      if (showHeaders && vast.isNotEmpty)
        _sectionHeader(AppLocalizations.of(context).vasteMedicatie),
      for (final c in vast) _buildCompactMedCard(c),
      if (showHeaders && nodig.isNotEmpty) ...[
        const SizedBox(height: 8),
        _sectionHeader(AppLocalizations.of(context).sectieZoNodig,
            subtitle: AppLocalizations.of(context).zoNodigUitleg),
      ] else if (nodig.isNotEmpty) ...[
        _sectionHeader(AppLocalizations.of(context).sectieZoNodig,
            subtitle: AppLocalizations.of(context).zoNodigUitleg),
      ],
      for (final c in nodig) _buildCompactMedCard(c),
      if (_stoppedConfigs.isNotEmpty) ...[
        const SizedBox(height: 12),
        _sectionHeader(AppLocalizations.of(context).sectieGestopt,
            subtitle: AppLocalizations.of(context).gestoptUitleg),
        for (final c in _stoppedConfigs) _buildStoppedMedCard(c),
      ],
    ];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          items[i],
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
        ],
      ),
    );
  }

  /// Alleen-lezen kaart voor gestopte (verwijderde) medicatie: naam +
  /// dosering + 'gestopt'-label en de inname-status voor de getoonde dag.
  /// Zo blijft de historie van de medicatie zichtbaar in eerdere dagen.
  Widget _buildStoppedMedCard(Map<String, dynamic> config) {
    dynamic rawId = config['id'];
    final int? configId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    final cs = Theme.of(context).colorScheme;
    final naam = config['naam']?.toString() ?? '';
    final dosering = '${config['dosering'] ?? ''} ${config['eenheid'] ?? ''}'.trim();
    final count = configId == null ? 0 : (_intakesForDay[configId] ?? 0);
    final taken = count > 0;
    final gestoptOp = config['stopped_at']?.toString();
    String? gestoptLabel;
    if (gestoptOp != null && gestoptOp.isNotEmpty) {
      final d = DateTime.tryParse(gestoptOp);
      if (d != null) {
        gestoptLabel = AppLocalizations.of(context).gestoptOp(DateFormat('d MMM y', 'nl').format(d));
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.surfaceContainerHighest,
                ),
                child: Icon(Icons.medication_rounded, size: 24, color: cs.outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      naam,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (dosering.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(dosering, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                          ),
                        const SizedBox(width: 6),
                        Text(
                          gestoptLabel ?? AppLocalizations.of(context).sectieGestopt,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.outline, letterSpacing: 0.3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Icon(taken ? Icons.check_circle_rounded : Icons.circle_outlined,
                      size: 26, color: taken ? cs.primary : cs.outline),
                  const SizedBox(height: 2),
                  Text(
                    taken
                        ? AppLocalizations.of(context).medicatieGenomen
                        : AppLocalizations.of(context).medicatieNietGenomen,
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: configId == null ? null : () => _reactivateMedication(configId),
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: Text(AppLocalizations.of(context).heractiveer),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _reactivateMedication(int id) async {
    try {
      await db.reactivateMedicationConfig(id);
      if (!mounted) return;
      await _loadData();
      // Herinneringen opnieuw inplannen is best effort: de UI (en de test)
      // mag hier niet op wachten of op falen.
      try {
        await NotificationHelper.instance.rescheduleAllMedicationReminders();
      } catch (e) {
        AppLogger.error('Herinneringen opnieuw plannen na heractivering mislukt', error: e);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).medicatieHeractiveerd),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.smallRadius)),
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to reactivate medication', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).heractiveerMislukt),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.smallRadius)),
          ),
        );
      }
    }
  }

  /// Stepper voor zo-nodig-medicatie: − [aantal] +
  Widget _buildPrnStepper(int configId, int count) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _stepButton(Icons.remove_rounded, count > 0 ? () => _setPrnCount(configId, count - 1) : null, cs),
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: count > 0 ? cs.primary : cs.outline,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    '×',
                    style: TextStyle(fontSize: 12, color: cs.outline, height: 1.0),
                  ),
                ],
              ),
            ),
            _stepButton(Icons.add_rounded, () => _setPrnCount(configId, count + 1), cs),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          count == 0
              ? AppLocalizations.of(context).zoNodig
              : AppLocalizations.of(context).prnVandaagGenomen(count),
          style: TextStyle(fontSize: 12, color: cs.outline),
        ),
      ],
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onPressed, ColorScheme cs) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: onPressed == null ? 0.35 : 1,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: cs.primary),
          ),
        ),
      ),
    );
  }

  Color _adherentieKleur(int pct) {
    if (pct >= 75) return AppTheme.success;
    if (pct >= 40) return AppTheme.warning;
    return AppTheme.danger(context);
  }

  Widget _buildCompactMedCard(Map<String, dynamic> config) {
    dynamic rawId = config['id'];
    int? configId;
    if (rawId is int) {
      configId = rawId;
    } else if (rawId is String) configId = int.tryParse(rawId);
    if (configId == null) return SizedBox.shrink();
    int count = _intakesForDay[configId] ?? 0;
    final zoNodig = _isZoNodig(config);
    String name = config['naam']?.toString() ?? AppLocalizations.of(context).onbekend;
    // Per-dag dosering uit intake; anders huidige config (voor nieuwe dagen)
    String dagDosering = _intakeDoseringForDay[configId] ?? config['dosering']?.toString() ?? '';
    String dosage = '$dagDosering ${config['eenheid']?.toString() ?? ''}';
    bool reminderEnabled = (config['reminder_enabled']?.toString() ?? '1') == '1';
    String? reminderTime = config['reminder_time']?.toString();
    final taken = count > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: taken
            ? Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.08)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: taken
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
              : Theme.of(context).dividerColor,
          width: taken ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
          children: [
            // Pill-icoon in zachte cirkel; check-vinkje wanneer ingenomen
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: taken ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.12),
              ),
              child: taken
                  ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 26)
                  : Icon(Icons.medication_rounded, color: Theme.of(context).colorScheme.primary, size: 24),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(dosage.trim().isEmpty ? '—' : dosage.trim(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textMedium)),
                        ),
                        if (taken) ...[
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _editIntakeDosering(configId!, name, dagDosering),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              child: Icon(Icons.edit_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        if (zoNodig)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              AppLocalizations.of(context).zoNodig,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onTertiaryContainer,
                                letterSpacing: 0.3,
                              ),
                            ),
                          )
                        else if (reminderTime != null && reminderEnabled)
                          Icon(Icons.notifications_active_rounded, size: 14, color: Theme.of(context).colorScheme.primary)
                        else
                          Icon(Icons.notifications_off_rounded, size: 14, color: Theme.of(context).colorScheme.outline),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (zoNodig) ...[
              _buildPrnStepper(configId, count),
            ] else ...[
            Column(
              children: [
                // Grote tikbare intake-knop
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _toggleIntake(configId!),
                    borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: taken ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            taken ? Icons.check_rounded : Icons.add_rounded,
                            size: 17,
                            color: taken
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            taken ? AppLocalizations.of(context).medicatieGenomen : AppLocalizations.of(context).medicatieNietGenomen,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: taken
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Herinnering-tijd (tappable)
                InkWell(
                  onTap: () => _editMedicationReminderTime(configId!, name, reminderEnabled, reminderTime ?? '08:00'),
                  borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(reminderTime != null ? Icons.access_time_rounded : Icons.access_time,
                            size: 12, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          reminderTime ?? AppLocalizations.of(context).stelTijdIn,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: reminderTime != null
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            ],
            const SizedBox(width: 4),
            _buildEditBtn(onPressed: () => _editMedication(config, configId!)),
            _buildDeleteBtn(onPressed: () => _stopMedication(configId!, _configName(config))),
          ],
            ),
            if (!zoNodig && _adherentie[configId] != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.show_chart, size: 14, color: _adherentieKleur(_adherentie[configId]!.percentage)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _adherentie[configId]!.percentage / 100,
                        minHeight: 4,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(_adherentieKleur(_adherentie[configId]!.percentage)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).adherentieDagen(_adherentie[configId]!.dagen, _adherentie[configId]!.percentage),
                    style: TextStyle(fontSize: 12, color: AppTheme.secondaryText(context)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditBtn({required VoidCallback? onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primary.withAlpha(25),
          ),
          child: Icon(Icons.edit_outlined, size: 18,
              color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildDeleteBtn({required VoidCallback? onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.danger(context).withValues(alpha: 0.10),
          ),
          child: Icon(Icons.stop_circle_outlined, size: 18,
              color: AppTheme.danger(context)),
        ),
      ),
    );
  }
}
