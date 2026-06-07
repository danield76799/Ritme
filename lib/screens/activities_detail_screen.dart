import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../service_locator.dart';

class ActivitiesDetailScreen extends StatefulWidget {
  const ActivitiesDetailScreen({super.key});

  @override
  State<ActivitiesDetailScreen> createState() => _ActivitiesDetailScreenState();
}

class _ActivitiesDetailScreenState extends State<ActivitiesDetailScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _dailyActivities = [];
  int _totalCount = 0;
  Map<String, int> _typeBreakdown = {};
  String? _errorMessage;

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
      final now = DateTime.now();
      
      List<Map<String, dynamic>> daysData = [];
      Map<String, int> typeCounts = {};
      int total = 0;

      for (int i = 0; i < 7; i++) {
        final checkDate = now.subtract(Duration(days: i));
        final checkDateStr = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
        final dayActivities = await db.getSrmActivities(checkDateStr);
        
        if (dayActivities.isNotEmpty) {
          List<Map<String, dynamic>> acts = [];
          for (var activity in dayActivities) {
            final type = activity['activity_type']?.toString() ?? 'Onbekend';
            acts.add({
              'type': type,
              'actual_time': activity['actual_time']?.toString() ?? '-',
              'target_time': activity['target_time']?.toString() ?? '-',
              'p_score': _parseInt(activity['p_score']),
            });
            typeCounts[type] = (typeCounts[type] ?? 0) + 1;
            total++;
          }
          
          daysData.add({
            'date': checkDateStr,
            'day': _dayName(checkDate.weekday),
            'dayFull': _dayNameFull(checkDate.weekday),
            'dateShort': '${checkDate.day}/${checkDate.month}',
            'activities': acts,
            'count': acts.length,
          });
        }
      }

      setState(() {
        _dailyActivities = daysData;
        _totalCount = total;
        _typeBreakdown = typeCounts;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('ActivitiesDetailScreen error: $e');
      debugPrint(stackTrace.toString());
      setState(() {
        _isLoading = false;
        _errorMessage = 'Kon activiteiten niet laden: $e';
      });
    }
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _dayName(int weekday) {
    const days = ['', 'Ma', 'Di', 'Wo', 'Do', 'Vr', 'Za', 'Zo'];
    return days[weekday];
  }

  String _dayNameFull(int weekday) {
    const days = ['', 'Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag', 'Zondag'];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        title: const Text(
          'Activiteiten Deze Week',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : _errorMessage != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppTheme.primaryTeal,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary card
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
                              const Icon(
                                Icons.check_circle_outline,
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '$_totalCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'totale activiteiten deze week',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Type breakdown
                        if (_typeBreakdown.isNotEmpty) ...[
                          const Text(
                            'Verdeling per type',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textCharcoal,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
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
                            child: Column(
                              children: _typeBreakdown.entries.map((entry) {
                                final percentage = _totalCount > 0 
                                    ? (entry.value / _totalCount * 100).toStringAsFixed(0)
                                    : '0';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getActivityIcon(entry.key),
                                        color: AppTheme.primaryTeal,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          entry.key,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: AppTheme.textCharcoal,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${entry.value}x ($percentage%)',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textCharcoal,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        
                        // Daily breakdown
                        const Text(
                          'Per dag',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textCharcoal,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        if (_dailyActivities.isEmpty)
                          _buildEmptyState('Geen activiteiten deze week', 'Voeg activiteiten toe via het Sociaal Ritme scherm.')
                        else
                          ..._dailyActivities.map((day) => _buildDayCard(day)),
                      ],
                    ),
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

  Widget _buildDayCard(Map<String, dynamic> day) {
    final activities = (day['activities'] as List<dynamic>).cast<Map<String, dynamic>>();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Text(
                  day['dayFull'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.textCharcoal,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  day['dateShort'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${day['count']} activiteiten',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Activities list
          ...activities.map((activity) => _buildActivityRow(activity)),
        ],
      ),
    );
  }

  Widget _buildActivityRow(Map<String, dynamic> activity) {
    final pScore = _parseInt(activity['p_score']);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200!, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getActivityIcon(activity['type']),
            color: _getPScoreColor(pScore),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['type'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: AppTheme.textCharcoal,
                  ),
                ),
                if (activity['actual_time'] != '-')
                  Text(
                    'Om ${activity['actual_time']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getPScoreColor(pScore),
              shape: BoxShape.circle,
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
          Icon(Icons.event_busy_outlined, size: 48, color: Colors.grey.shade400),
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
