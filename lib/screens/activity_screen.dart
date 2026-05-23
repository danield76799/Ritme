import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../utils/app_theme.dart';
import '../service_locator.dart';
import '../widgets/datum_navigator.dart';
import '../utils/logger.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _geselecteerdeDatum = DateTime.now();

  // Sleep data
  String? _bedTime;
  String? _wakeTime;
  int _awakeMinutes = 0;
  double? _calculatedSleepHours;

  String get _formattedDate {
    return '${_geselecteerdeDatum.year}-${_geselecteerdeDatum.month.toString().padLeft(2, '0')}-${_geselecteerdeDatum.day.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _activiteiten = [
    {'naam': 'Opstaan', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0, 'icoon': Icons.wb_sunny_outlined},
    {'naam': 'Eerste contact', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0, 'icoon': Icons.person_outline},
    {'naam': 'Werk / Hobby', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0, 'icoon': Icons.work_outline},
    {'naam': 'Avondeten', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0, 'icoon': Icons.restaurant_outlined},
    {'naam': 'Naar bed', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0, 'icoon': Icons.bedtime_outlined},
  ];

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
      final settings = await db.getSettings();
      if (settings != null) {
        _activiteiten[0]['richttijd'] = _parseTimeOfDay(settings['target_wake_time']);
        _activiteiten[1]['richttijd'] = _parseTimeOfDay(settings['target_first_contact']);
        _activiteiten[2]['richttijd'] = _parseTimeOfDay(settings['target_work']);
        _activiteiten[3]['richttijd'] = _parseTimeOfDay(settings['target_dinner']);
        _activiteiten[4]['richttijd'] = _parseTimeOfDay(settings['target_sleep_time']);
      }

      final activities = await db.getSrmActivities(_formattedDate);
      
      for (var activity in activities) {
        final index = _activiteiten.indexWhere((a) => a['naam'] == activity['activity_type']);
        if (index != -1) {
          _activiteiten[index]['werkelijke_tijd'] = _parseTimeOfDay(activity['actual_time']?.toString());
          dynamic rawPScore = activity['p_score'];
          int pScore;
          if (rawPScore is int) {
            pScore = rawPScore;
          } else if (rawPScore is String) {
            pScore = int.tryParse(rawPScore) ?? 0;
          } else {
            pScore = 0;
          }
          _activiteiten[index]['p_score'] = pScore;
        }
      }

      // Load sleep data
      final sleepLog = await db.getSleepLog(_formattedDate);
      if (sleepLog != null) {
        setState(() {
          _bedTime = sleepLog['bed_time']?.toString();
          _wakeTime = sleepLog['wake_time']?.toString();
          _awakeMinutes = sleepLog['awake_minutes'] ?? 0;
          _calculatedSleepHours = sleepLog['sleep_hours']?.toDouble();
        });
        
        // Pre-fill "Opstaan" activity with wake time if sleep log exists
        final wakeTimeStr = sleepLog['wake_time']?.toString();
        if (wakeTimeStr != null && wakeTimeStr.isNotEmpty) {
          _activiteiten[0]['werkelijke_tijd'] = _parseTimeOfDay(wakeTimeStr);
          // Bereken p_score op basis van target vs actual time
          final targetTijd = _activiteiten[0]['richttijd'];
          if (targetTijd != null && targetTijd != '--:--') {
            final diff = _berekenTijdVerschil(targetTijd, wakeTimeStr);
            _activiteiten[0]['p_score'] = _berekenPScore(diff);
          } else {
            _activiteiten[0]['p_score'] = 1; // Geen target, markeer als gedaan
          }
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load activity data', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Kon activiteitengegevens niet laden. Probeer opnieuw.';
      });
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _onDatumVeranderd(DateTime nieuweDatum) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(nieuweDatum.year, nieuweDatum.month, nieuweDatum.day);
    
    if (selected.isAfter(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Je kunt geen activiteiten in de toekomst loggen'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    
    setState(() {
      _geselecteerdeDatum = nieuweDatum;
      _isLoading = true;
      _bedTime = null;
      _wakeTime = null;
      _awakeMinutes = 0;
      _calculatedSleepHours = null;
      _activiteiten = [
        {'naam': 'Opstaan', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0, 'icoon': Icons.wb_sunny_outlined},
        {'naam': 'Eerste contact', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0, 'icoon': Icons.person_outline},
        {'naam': 'Werk / Hobby', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0, 'icoon': Icons.work_outline},
        {'naam': 'Avondeten', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0, 'icoon': Icons.restaurant_outlined},
        {'naam': 'Naar bed', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0, 'icoon': Icons.bedtime_outlined},
      ];
    });
    _loadData();
  }

  TimeOfDay? _parseTimeOfDay(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return null;
    }
  }

  // Bereken tijdsverschil in minuten tussen twee tijden (HH:MM format)
  int _berekenTijdVerschil(String targetTime, String actualTime) {
    final targetParts = targetTime.split(':');
    final actualParts = actualTime.split(':');
    
    if (targetParts.length < 2 || actualParts.length < 2) return 0;
    
    final targetMinutes = (int.tryParse(targetParts[0]) ?? 0) * 60 + (int.tryParse(targetParts[1]) ?? 0);
    final actualMinutes = (int.tryParse(actualParts[0]) ?? 0) * 60 + (int.tryParse(actualParts[1]) ?? 0);
    
    return (actualMinutes - targetMinutes).abs();
  }
  
  // Bereken p-score op basis van tijdsverschil in minuten
  int _berekenPScore(int diffMinutes) {
    // P-score berekening volgens officiële SRM methode (IPSRT):
    // 5 punten = binnen 15 minuten
    // 4 punten = binnen 30 minuten
    // 3 punten = binnen 45 minuten (cutoff)
    // 2 punten = binnen 60 minuten
    // 1 punt = meer dan 60 minuten
    // 0 punten = geen activiteit
    if (diffMinutes <= 15) return 5;
    if (diffMinutes <= 30) return 4;
    if (diffMinutes <= 45) return 3;
    if (diffMinutes <= 60) return 2;
    return 1; // Meer dan 60 min maar wel gedaan
  }

  String _formatTijd(TimeOfDay? tijd) {
    if (tijd == null) return '--:--';
    return '${tijd.hour.toString().padLeft(2, '0')}:${tijd.minute.toString().padLeft(2, '0')}';
  }

  Color _getScoreColor(int score) {
    if (score >= 3) return Colors.green;
    if (score >= 2) return Colors.orange;
    if (score >= 1) return Colors.red.shade400;
    return Colors.grey;
  }

  Future<void> _toggleActivity(int index) async {
    try {
      final activity = _activiteiten[index];
      String name = activity['naam'];
      
      String timeStr;
      int currentScore;
      dynamic rawScore = activity['p_score'];
      if (rawScore is int) {
        currentScore = rawScore;
      } else if (rawScore is String) {
        currentScore = int.tryParse(rawScore) ?? 0;
      } else {
        currentScore = 0;
      }
      
      // For "Opstaan", use wake_time from sleep log if available (skip time picker)
      if (name == 'Opstaan' && _wakeTime != null && _wakeTime!.isNotEmpty) {
        timeStr = _wakeTime!;
        // Toggle the score only
        int newScore = currentScore == 0 ? 1 : 0;
        await db.insertSrmActivity(_formattedDate, name, timeStr, newScore, null);
        _loadData();
        return;
      }
      
      // For other activities or if no wake_time, show time picker
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          );
        },
      );
      
      if (picked == null) return;
      
      timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';

      // Bereken p_score op basis van target vs actual time
      final targetTijd = activity['richttijd'];
      int newScore;
      if (targetTijd != null && targetTijd != '--:--') {
        final diff = _berekenTijdVerschil(targetTijd, timeStr);
        newScore = _berekenPScore(diff);
      } else {
        newScore = currentScore == 0 ? 1 : 0; // Toggle als er geen target is
      }

      await db.insertSrmActivity(_formattedDate, name, timeStr, newScore, null);

      _loadData();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to toggle activity', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kon activiteit niet opslaan. Probeer opnieuw.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  String _formatSleepDuration(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h > 0 && m > 0) return '${h}u ${m}m slaap';
    if (h > 0) return '${h}u slaap';
    return '${m}m slaap';
  }

  Future<void> _setBedTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseTimeOfDay(_bedTime) ?? const TimeOfDay(hour: 22, minute: 0),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _bedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
      _saveSleepData();
    }
  }

  Future<void> _setWakeTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseTimeOfDay(_wakeTime) ?? const TimeOfDay(hour: 7, minute: 0),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _wakeTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
      _saveSleepData();
    }
  }

  Future<void> _setAwakeTime() async {
    int selectedMinutes = _awakeMinutes;
    
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (BuildContext context) {
        return Container(
          height: 300,
          color: Colors.grey[900],
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey[850],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuleer', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    const Text(
                      'Wakker gelegen',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _awakeMinutes = selectedMinutes;
                        });
                        _saveSleepData();
                        Navigator.pop(context);
                      },
                      child: const Text('Klaar', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.grey),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 40,
                  onSelectedItemChanged: (index) {
                    selectedMinutes = index * 15;
                  },
                  scrollController: FixedExtentScrollController(initialItem: _awakeMinutes ~/ 15),
                  backgroundColor: Colors.grey[900],
                  children: List.generate(49, (index) {
                    final minutes = index * 15;
                    final hours = minutes ~/ 60;
                    final mins = minutes % 60;
                    String label;
                    if (hours > 0 && mins > 0) {
                      label = '${hours}u ${mins}m';
                    } else if (hours > 0) {
                      label = '${hours}u';
                    } else {
                      label = '${mins}m';
                    }
                    return Center(
                      child: Text(
                        label,
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveSleepData() async {
    if (_bedTime != null && _wakeTime != null) {
      final sleepHours = _calculateSleepHours(_bedTime!, _wakeTime!, _awakeMinutes);
      setState(() {
        _calculatedSleepHours = sleepHours;
      });
      
      await db.insertSleepLog(_formattedDate, _bedTime!, _wakeTime!, _awakeMinutes);
      
      // Also update daily log with calculated sleep hours
      await db.upsertDailyLog({
        'date': _formattedDate,
        'uren_slaap': sleepHours,
      });
      
      // Also save "Opstaan" activity with wake_time (auto-completed)
      if (_wakeTime != null) {
        // Bereken p_score op basis van target vs actual wake time
        final targetTijd = _activiteiten[0]['richttijd'];
        int pScore = 1; // Default als er geen target is
        if (targetTijd != null && targetTijd != '--:--') {
          final diff = _berekenTijdVerschil(targetTijd, _wakeTime!);
          pScore = _berekenPScore(diff);
        }
        await db.insertSrmActivity(_formattedDate, 'Opstaan', _wakeTime!, pScore, null);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Slaapduur: ${_formatSleepDuration(sleepHours)}'),
            backgroundColor: AppTheme.primaryTeal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  double _calculateSleepHours(String bedTime, String wakeTime, int awakeMinutes) {
    try {
      final bedParts = bedTime.split(':');
      final wakeParts = wakeTime.split(':');
      
      int bedHour = int.parse(bedParts[0]);
      int bedMinute = int.parse(bedParts[1]);
      int wakeHour = int.parse(wakeParts[0]);
      int wakeMinute = int.parse(wakeParts[1]);
      
      int bedMinutes = bedHour * 60 + bedMinute;
      int wakeMinutes = wakeHour * 60 + wakeMinute;
      
      if (wakeMinutes < bedMinutes) {
        wakeMinutes += 24 * 60;
      }
      
      int totalMinutes = wakeMinutes - bedMinutes - awakeMinutes;
      return totalMinutes / 60.0;
    } catch (e) {
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Activiteit & Slaap',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: DatumNavigator(
              geselecteerdeDatum: _geselecteerdeDatum,
              onDatumVeranderd: _onDatumVeranderd,
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
                : _errorMessage != null
                    ? _buildErrorState()
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          // Sleep section
                          _buildSectionHeader('Slaap'),
                          _buildSleepCard(),
                          const SizedBox(height: 24),
                          
                          // Activities section
                          _buildSectionHeader('Sociaal Ritme Meter'),
                          ..._activiteiten.asMap().entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildCompactActivityCard(entry.key),
                            );
                          }).toList(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sleep hours display
          if (_calculatedSleepHours != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.nights_stay, color: AppTheme.primaryTeal),
                  const SizedBox(width: 8),
                  Text(
                    _formatSleepDuration(_calculatedSleepHours!),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                ],
              ),
            ),
          if (_calculatedSleepHours != null) const SizedBox(height: 16),
          
          // Bed time
          _buildSleepTimeField(
            'Naar bed gegaan',
            _bedTime ?? 'Tik om tijd in te stellen',
            Icons.bedtime,
            _setBedTime,
          ),
          const SizedBox(height: 12),
          
          // Wake time
          _buildSleepTimeField(
            'Opgestaan',
            _wakeTime ?? 'Tik om tijd in te stellen',
            Icons.wb_sunny,
            _setWakeTime,
          ),
          const SizedBox(height: 12),
          
          // Awake time
          _buildSleepTimeField(
            'Wakker gelegen',
            _formatAwakeTime(),
            Icons.access_time,
            _setAwakeTime,
          ),
        ],
      ),
    );
  }

  String _formatAwakeTime() {
    if (_awakeMinutes == 0) return 'Tik om tijd in te stellen';
    final hours = _awakeMinutes ~/ 60;
    final mins = _awakeMinutes % 60;
    if (hours > 0 && mins > 0) return '${hours}u ${mins}m';
    if (hours > 0) return '${hours}u';
    return '${mins}m';
  }

  Widget _buildSleepTimeField(String label, String value, IconData icon, VoidCallback onTap) {
    final hasValue = value != 'Tik om tijd in te stellen';
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: hasValue ? AppTheme.primaryTeal.withValues(alpha: 0.05) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasValue ? AppTheme.primaryTeal.withValues(alpha: 0.3) : Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasValue ? AppTheme.primaryTeal : Colors.grey[400],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                      color: hasValue ? Colors.black : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
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

  Widget _buildCompactActivityCard(int index) {
    final activity = _activiteiten[index];
    String naam = activity['naam'];
    IconData icoon = activity['icoon'] ?? Icons.circle;
    TimeOfDay? richtTijd = activity['richttijd'];
    TimeOfDay? werkTijd = activity['werkelijke_tijd'];
    int pScore;
    dynamic rawScore = activity['p_score'];
    if (rawScore is int) {
      pScore = rawScore;
    } else if (rawScore is String) {
      pScore = int.tryParse(rawScore) ?? 0;
    } else {
      pScore = 0;
    }
    bool isDone = werkTijd != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone ? AppTheme.primaryTeal.withValues(alpha: 0.3) : Colors.grey.shade100,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleActivity(index),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDone ? AppTheme.primaryTeal : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icoon,
                    size: 20,
                    color: isDone ? Colors.white : Colors.grey[500],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        naam,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDone ? Colors.black : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (richtTijd != null) ...[
                            Icon(Icons.schedule, size: 12, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              _formatTijd(richtTijd),
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],
                          if (werkTijd != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.check_circle, size: 12, color: AppTheme.primaryTeal),
                            const SizedBox(width: 4),
                            Text(
                              _formatTijd(werkTijd),
                              style: TextStyle(fontSize: 11, color: AppTheme.primaryTeal, fontWeight: FontWeight.w500),
                            ),
                          ] else ...[
                            const SizedBox(width: 8),
                            Icon(Icons.touch_app, size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              'Tik om tijd in te stellen',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getScoreColor(pScore).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'P$pScore',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getScoreColor(pScore),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
