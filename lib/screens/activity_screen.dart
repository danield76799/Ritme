import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../service_locator.dart';
import '../widgets/datum_navigator.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  bool _isLoading = true;
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
    setState(() => _isLoading = true);

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
        _activiteiten[index]['werkelijke_tijd'] = _parseTimeOfDay(activity['actual_time']);
        _activiteiten[index]['p_score'] = activity['p_score'] ?? 0;
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _onDatumVeranderd(DateTime nieuweDatum) {
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
    final activity = _activiteiten[index];
    String name = activity['naam'];
    TimeOfDay nu = TimeOfDay.now();
    String timeStr = '${nu.hour.toString().padLeft(2, '0')}:${nu.minute.toString().padLeft(2, '0')}';

    int currentScore = activity['p_score'] ?? 0;
    int newScore = currentScore == 0 ? 1 : 0;

    await db.insertSrmActivity(_formattedDate, name, timeStr, newScore, null);

    _loadData();
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
