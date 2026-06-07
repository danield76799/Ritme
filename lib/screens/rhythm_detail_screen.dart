import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../service_locator.dart';

class RhythmDetailScreen extends StatefulWidget {
  const RhythmDetailScreen({super.key});

  @override
  State<RhythmDetailScreen> createState() => _RhythmDetailScreenState();
}

class _RhythmDetailScreenState extends State<RhythmDetailScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _activities = [];
  double _stabilityScore = 0;
  int _totalActivities = 0;
  int _onTimeCount = 0;
  Map<String, int> _activityTypeCounts = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      
      // Haal settings op voor target times
      final settings = await db.getSettings();
      final targetTimes = {
        'Opstaan': settings?['target_opstaan']?.toString(),
        'Eerste contact': settings?['target_contact']?.toString(),
        'Werk / Hobby': settings?['target_werk']?.toString(),
        'Avondeten': settings?['target_eten']?.toString(),
        'Naar bed': settings?['target_slapen']?.toString(),
      };
      
      List<Map<String, dynamic>> allActivities = [];
      int totalOnTime = 0;
      int totalActs = 0;
      Map<String, int> typeCounts = {};

      for (int i = 0; i < 7; i++) {
        final checkDate = now.subtract(Duration(days: i));
        final checkDateStr = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
        final dayActivities = await db.getSrmActivities(checkDateStr);
        
        for (var activity in dayActivities) {
          final type = activity['activity_type']?.toString() ?? 'Onbekend';
          final dbPScore = _parseInt(activity['p_score']);
          final actualTime = activity['actual_time']?.toString();
          final dbTargetTime = activity['target_time']?.toString();
          
          // Gebruik target_time uit database, anders uit settings
          final targetTime = dbTargetTime ?? targetTimes[type];
          
          // Bereken p-score opnieuw als we target_time hebben
          int pScore;
          if (targetTime != null && targetTime.isNotEmpty && actualTime != null && actualTime.isNotEmpty) {
            pScore = _calculatePScore(targetTime, actualTime);
          } else {
            pScore = dbPScore;
          }
          
          allActivities.add({
            'date': checkDateStr,
            'day': _dayName(checkDate.weekday),
            'type': type,
            'p_score': pScore,
            'actual_time': actualTime ?? '-',
            'target_time': targetTime ?? '-',
            'on_time': pScore >= 3,
          });
          
          totalActs++;
          if (pScore >= 3) totalOnTime++;
          typeCounts[type] = (typeCounts[type] ?? 0) + 1;
        }
      }

      setState(() {
        _activities = allActivities;
        _totalActivities = totalActs;
        _onTimeCount = totalOnTime;
        _stabilityScore = totalActs > 0 ? (totalOnTime / totalActs * 100) : 0;
        _activityTypeCounts = typeCounts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
  
  // Bereken p-score op basis van tijdsverschil
  int _calculatePScore(String targetTime, String actualTime) {
    final targetParts = targetTime.split(':');
    final actualParts = actualTime.split(':');
    
    if (targetParts.length < 2 || actualParts.length < 2) return 0;
    
    final targetMinutes = (int.tryParse(targetParts[0]) ?? 0) * 60 + (int.tryParse(targetParts[1]) ?? 0);
    final actualMinutes = (int.tryParse(actualParts[0]) ?? 0) * 60 + (int.tryParse(actualParts[1]) ?? 0);
    
    final diff = (actualMinutes - targetMinutes).abs();
    
    if (diff <= 15) return 5;
    if (diff <= 30) return 4;
    if (diff <= 45) return 3;
    if (diff <= 60) return 2;
    return 1;
  }

  String _dayName(int weekday) {
    const days = ['', 'Ma', 'Di', 'Wo', 'Do', 'Vr', 'Za', 'Zo'];
    return days[weekday];
  }

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'opstaan':
        return Icons.wb_sunny_outlined;
      case 'slapen':
      case 'naar bed':
        return Icons.nightlight_round;
      case 'eten':
      case 'maaltijd':
        return Icons.restaurant;
      case 'werk':
      case 'werken':
        return Icons.work_outline;
      case 'sociaal contact':
      case 'contact':
        return Icons.people_outline;
      default:
        return Icons.schedule;
    }
  }

  Color _getPScoreColor(int score) {
    if (score >= 5) return Colors.green;
    if (score >= 3) return AppTheme.primaryTeal;
    if (score >= 1) return Colors.orange;
    return Colors.redAccent;
  }

  String _getPScoreLabel(int score) {
    if (score >= 5) return 'Perfect';
    if (score >= 3) return 'Op tijd';
    if (score >= 1) return 'Enigszins';
    return 'Gemist';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        title: const Text(
          'Ritme Stabiliteit',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppTheme.primaryTeal,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stability score card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryTeal,
                            AppTheme.primaryTeal.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryTeal.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Stabiliteit Score',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_stabilityScore.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_onTimeCount van $_totalActivities activiteiten op tijd',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Activity type breakdown
                    if (_activityTypeCounts.isNotEmpty) ...[
                      const Text(
                        'Activiteit types',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textCharcoal,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _activityTypeCounts.entries.map((entry) {
                          return Chip(
                            avatar: Icon(
                              _getActivityIcon(entry.key),
                              size: 18,
                              color: AppTheme.primaryTeal,
                            ),
                            label: Text('${entry.key}: ${entry.value}'),
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey.shade300!),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Activities list
                    const Text(
                      'Activiteiten deze week',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textCharcoal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (_activities.isEmpty)
                      _buildEmptyState('Geen activiteiten gevonden', 'Voeg SRM activiteiten toe via het Sociaal Ritme scherm.')
                    else
                      ..._activities.map((activity) => _buildActivityItem(activity)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final pScore = activity['p_score'] as int;
    final isOnTime = activity['on_time'] as bool;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getPScoreColor(pScore).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getActivityIcon(activity['type']),
              color: _getPScoreColor(pScore),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['type'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.textCharcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${activity['day']} • Daadwerkelijk: ${activity['actual_time']}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black,
                  ),
                ),
                if (activity['target_time'] != '-') ...[
                  const SizedBox(height: 2),
                  Text(
                    'Target: ${activity['target_time']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getPScoreColor(pScore).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getPScoreLabel(pScore),
              style: TextStyle(
                color: _getPScoreColor(pScore),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.schedule_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}