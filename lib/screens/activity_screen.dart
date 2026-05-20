import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../service_locator.dart';
import '../widgets/datum_navigator.dart';
import '../widgets/app_scaffold.dart';
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
          // Handle both int and String types for p_score
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
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load activity data', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Kon activiteitengegevens niet laden. Probeer opnieuw.';
      });
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _onDatumVeranderd(DateTime nieuweDatum) {
    // Validatie: blokkeer toekomstige datums
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
      
      // Show time picker instead of using current time
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
      
      if (picked == null) return; // User cancelled
      
      String timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';

      int currentScore = activity['p_score'] ?? 0;
      int newScore = currentScore == 0 ? 1 : 0;

      await db.insertSrmActivity(_formattedDate, name, timeStr, newScore, null);

      // Auto-calculate sleep time if both wake and sleep are set
      _updateSleepTime();

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

  void _updateSleepTime() {
    // Find wake up and bed times
    final wakeUp = _activiteiten.firstWhere((a) => a['naam'] == 'Opstaan', orElse: () => {})['werkelijke_tijd'] as TimeOfDay?;
    final bedTime = _activiteiten.firstWhere((a) => a['naam'] == 'Naar bed', orElse: () => {})['werkelijke_tijd'] as TimeOfDay?;
    
    if (wakeUp != null && bedTime != null) {
      // Calculate sleep duration
      double sleepHours = _calculateSleepHours(bedTime, wakeUp);
      
      // Update daily log with sleep time
      db.upsertDailyLog({
        'date': _formattedDate,
        'uren_slaap': sleepHours,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Slaaptijd berekend: ${sleepHours.toStringAsFixed(1)} uur'),
            backgroundColor: AppTheme.primaryTeal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  double _calculateSleepHours(TimeOfDay bedTime, TimeOfDay wakeUp) {
    int bedMinutes = bedTime.hour * 60 + bedTime.minute;
    int wakeMinutes = wakeUp.hour * 60 + wakeUp.minute;
    
    if (wakeMinutes < bedMinutes) {
      // Slept past midnight
      wakeMinutes += 24 * 60;
    }
    
    return (wakeMinutes - bedMinutes) / 60.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Activiteiten',
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
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _activiteiten.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _buildCompactActivityCard(i),
                      ),
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

  Widget _buildCompactActivityCard(int index) {
    final activity = _activiteiten[index];
    String naam = activity['naam'];
    IconData icoon = activity['icoon'] ?? Icons.circle;
    TimeOfDay? richtTijd = activity['richttijd'];
    TimeOfDay? werkTijd = activity['werkelijke_tijd'];
    int pScore = activity['p_score'] ?? 0;
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
                // Icon with status
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
                // Name & times
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        naam,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDone ? AppTheme.textCharcoal : Colors.grey[600],
                          decoration: isDone ? null : TextDecoration.none,
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
                            Icon(Icons.touch_app, size: 12, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              'Tik om tijd in te stellen',
                              style: TextStyle(fontSize: 11, color: Colors.grey[400], fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // P-score indicator
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
