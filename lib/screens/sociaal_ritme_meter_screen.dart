import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../service_locator.dart';
import '../utils/logger.dart';

class SociaalRitmeMeterScreen extends StatefulWidget {
  const SociaalRitmeMeterScreen({super.key});

  @override
  State<SociaalRitmeMeterScreen> createState() => _SociaalRitmeMeterScreenState();
}

class _SociaalRitmeMeterScreenState extends State<SociaalRitmeMeterScreen> {
  List<Map<String, dynamic>> _activities = [];
  Map<String, dynamic>? _settings;
  bool _isLoading = true;
  String? _errorMessage;

  // De 5 standaard activiteiten
  final List<Map<String, dynamic>> _standaardActiviteiten = [
    {'naam': 'Opstaan', 'icoon': Icons.wb_sunny_outlined, 'targetKey': 'target_opstaan'},
    {'naam': 'Eerste contact', 'icoon': Icons.person_outline, 'targetKey': 'target_contact'},
    {'naam': 'Werk / Hobby', 'icoon': Icons.work_outline, 'targetKey': 'target_werk'},
    {'naam': 'Avondeten', 'icoon': Icons.restaurant_outlined, 'targetKey': 'target_eten'},
    {'naam': 'Naar bed', 'icoon': Icons.bedtime_outlined, 'targetKey': 'target_slapen'},
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
      final today = DateTime.now().toIso8601String().split('T')[0];
      final activities = await db.getSrmActivities(today);
      final settings = await db.getSettings();

      setState(() {
        _activities = activities;
        _settings = settings;
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

  String _getTargetTime(String key) {
    final value = _settings?[key];
    AppLogger.debug('Getting target time for key: $key, value: $value, settings keys: ${_settings?.keys.toList()}');
    if (value == null || value.toString().isEmpty || value.toString() == '--:--') {
      return '--:--';
    }
    return value.toString();
  }

  Map<String, dynamic>? _getActivityForType(String type) {
    try {
      return _activities.firstWhere((a) => a['activity_type'] == type);
    } catch (e) {
      return null;
    }
  }

  Color _getPScoreColor(int score) {
    if (score >= 5) return Colors.green.shade600;  // Perfect
    if (score >= 4) return Colors.green.shade400;  // Goed
    if (score >= 3) return Colors.orange.shade400; // OK (cutoff)
    if (score >= 2) return Colors.orange.shade600; // Matig
    if (score >= 1) return Colors.red.shade500;    // Slecht
    return Colors.grey.shade400;                    // Geen activiteit
  }

  String _getPScoreLabel(int score) {
    if (score >= 5) return '✓✓';  // Perfect
    if (score >= 4) return '✓';   // Goed
    if (score >= 3) return '~';   // OK
    if (score >= 2) return '!';   // Matig
    if (score >= 1) return '!!';  // Slecht
    return '-';                    // Geen activiteit
  }

  IconData _getPScoreIcon(int score) {
    if (score >= 5) return Icons.check_circle;
    if (score >= 4) return Icons.check_circle_outline;
    if (score >= 3) return Icons.access_time;
    if (score >= 2) return Icons.warning_amber;
    if (score >= 1) return Icons.error_outline;
    return Icons.circle_outlined;
  }

  int _calculatePScore(String? targetTime, String? actualTime) {
    if (targetTime == null || targetTime == '--:--' || actualTime == null || actualTime.isEmpty) {
      return 0;
    }
    
    // Parse times
    final targetParts = targetTime.split(':');
    final actualParts = actualTime.split(':');
    
    if (targetParts.length < 2 || actualParts.length < 2) return 0;
    
    final targetMinutes = (int.tryParse(targetParts[0]) ?? 0) * 60 + (int.tryParse(targetParts[1]) ?? 0);
    final actualMinutes = (int.tryParse(actualParts[0]) ?? 0) * 60 + (int.tryParse(actualParts[1]) ?? 0);
    
    // P-score berekening volgens officiële SRM methode (IPSRT):
    // 5 punten = binnen 15 minuten
    // 4 punten = binnen 30 minuten
    // 3 punten = binnen 45 minuten (cutoff)
    // 2 punten = binnen 60 minuten
    // 1 punt = meer dan 60 minuten
    // 0 punten = geen activiteit
    final diff = (actualMinutes - targetMinutes).abs();
    
    if (diff <= 15) return 5;
    if (diff <= 30) return 4;
    if (diff <= 45) return 3;
    if (diff <= 60) return 2;
    return 1; // Meer dan 60 min maar wel gedaan
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Sociaal Ritme', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Vernieuwen',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : _errorMessage != null
              ? _buildErrorWidget()
              : _buildContent(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          SizedBox(height: 12),
          Text(_errorMessage!, style: TextStyle(fontSize: 16, color: Colors.black)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Opnieuw proberen'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // Tel hoeveel activiteiten zijn VOLTOOID (hebben een actual_time OF p_score > 0)
    final voltooidCount = _activities.where((a) {
      final actualTime = a['actual_time']?.toString();
      final hasActualTime = actualTime != null && actualTime.isNotEmpty && actualTime != '--:--';
      final hasPScore = (a['p_score'] ?? 0) > 0;
      return hasActualTime || hasPScore;
    }).length;

    return Column(
      children: [
        // Header met datum en summary
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryTeal,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Text(
                DateFormat('EEEE d MMMM', 'nl_NL').format(DateTime.now()),
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '$voltooidCount / 5 activiteiten voltooid',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.surface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Lijst van activiteiten
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _standaardActiviteiten.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final activiteit = _standaardActiviteiten[index];
              return _buildActivityCard(activiteit);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activiteit) {
    final naam = activiteit['naam'] as String;
    final icoon = activiteit['icoon'] as IconData;
    final targetKey = activiteit['targetKey'] as String;

    final targetTijd = _getTargetTime(targetKey);
    final dbActiviteit = _getActivityForType(naam);
    final isGedaan = dbActiviteit != null && (dbActiviteit['actual_time']?.toString().isNotEmpty ?? false);
    final werkTijd = dbActiviteit?['actual_time'] as String? ?? null;
    final pScore = _calculatePScore(targetTijd, werkTijd);

    final pColor = _getPScoreColor(pScore);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icoon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isGedaan
                    ? AppTheme.primaryTeal.withValues(alpha: 0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icoon,
                color: isGedaan ? AppTheme.primaryTeal : Colors.grey.shade400,
                size: 24,
              ),
            ),
            SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    naam,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isGedaan ? AppTheme.textCharcoal : Colors.black,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      // Target tijd
                      Icon(Icons.schedule_outlined, size: 14, color: Colors.grey.shade400),
                      SizedBox(width: 4),
                      Text(
                        'Doel: $targetTijd',
                        style: TextStyle(
                          fontSize: 13, 
                          color: targetTijd == '--:--' ? Colors.grey.shade400 : Colors.black,
                          fontWeight: targetTijd == '--:--' ? FontWeight.normal : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (isGedaan) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 14, color: AppTheme.primaryTeal),
                        const SizedBox(width: 4),
                        Text(
                          'Werkelijk: $werkTijd',
                          style: TextStyle(fontSize: 13, color: AppTheme.primaryTeal),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // P-score indicator (subtle)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: pColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getPScoreLabel(pScore),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: pColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}