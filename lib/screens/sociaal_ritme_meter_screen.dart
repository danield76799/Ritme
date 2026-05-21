import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../service_locator.dart';
import '../utils/logger.dart';

class SociaalRitmeMeterScreen extends StatefulWidget {
  const SociaalRitmeMeterScreen({super.key});

  @override
  State<SociaalRitmeMeterScreen> createState() => _SociaalRitmeMeterScreenState();
}

class _SociaalRitmeMeterScreenState extends State<SociaalRitmeMeterScreen> {
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;
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
      final today = DateTime.now().toIso8601String().split('T')[0];
      final activities = await db.getSrmActivities(today);
      setState(() {
        _activities = activities;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load SRM data', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Kon sociaal ritme data niet laden.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Sociaal Ritme', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : _errorMessage != null
              ? _buildErrorWidget()
              : _activities.isEmpty
                  ? _buildEmptyState()
                  : _buildActivitiesList(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Opnieuw proberen'),
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
          Icon(Icons.schedule_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Geen activiteiten vandaag',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            'Voeg activiteiten toe via het Activiteitenscherm',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _activities.length,
      itemBuilder: (context, index) {
        final activity = _activities[index];
        return _buildActivityCard(activity);
      },
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final type = activity['activity_type'] ?? 'Onbekend';
    final time = activity['actual_time'] ?? '--:--';
    final pScore = activity['p_score'] ?? 0;
    final hasData = activity['actual_time'] != null;
    
    // Get icon for activity type
    IconData activityIcon = _getActivityIcon(type);
    
    // P-score kleur
    Color scoreColor;
    String scoreLabel;
    if (!hasData) {
      scoreColor = Colors.grey;
      scoreLabel = 'Niet ingevuld';
    } else if (pScore >= 3) {
      scoreColor = Colors.green;
      scoreLabel = 'Helemaal op tijd';
    } else if (pScore >= 2) {
      scoreColor = Colors.orange;
      scoreLabel = 'Kort gemist';
    } else if (pScore >= 1) {
      scoreColor = Colors.red.shade400;
      scoreLabel = 'Gemist';
    } else {
      scoreColor = Colors.grey;
      scoreLabel = 'Niet ingevuld';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Activity icon in colored circle
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(activityIcon, color: scoreColor, size: 28),
            ),
            const SizedBox(width: 16),
            // Activity info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasData ? 'Om $time' : 'Tijd niet ingevuld',
                    style: TextStyle(
                      fontSize: 14,
                      color: hasData ? const Color(0xFF666666) : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            // P-score badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    pScore >= 3 ? Icons.check_circle : (hasData ? Icons.access_time : Icons.remove_circle_outline),
                    size: 16,
                    color: scoreColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    hasData ? 'P$pScore' : '-',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'Opstaan':
        return Icons.wb_sunny;
      case 'Eerste contact':
        return Icons.person_add;
      case 'Werk / Hobby':
        return Icons.work;
      case 'Avondeten':
        return Icons.restaurant;
      case 'Naar bed':
        return Icons.bedtime;
      default:
        return Icons.schedule;
    }
  }
}
