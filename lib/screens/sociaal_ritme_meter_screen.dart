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
    final value = _settings?[key] as String?;
    if (value == null || value.isEmpty) return '--:--';
    return value;
  }

  Map<String, dynamic>? _getActivityForType(String type) {
    try {
      return _activities.firstWhere((a) => a['activity_type'] == type);
    } catch (e) {
      return null;
    }
  }

  Color _getPScoreColor(int score) {
    if (score >= 3) return Colors.green;
    if (score >= 2) return Colors.orange;
    if (score >= 1) return Colors.red.shade400;
    return Colors.grey;
  }

  String _getPScoreLabel(int score) {
    if (score >= 3) return 'Op tijd ✓';
    if (score >= 2) return 'Deels op tijd';
    if (score >= 1) return 'Te laat';
    return 'Niet gedaan';
  }

  IconData _getPScoreIcon(int score) {
    if (score >= 3) return Icons.check_circle;
    if (score >= 2) return Icons.access_time;
    if (score >= 1) return Icons.warning_amber;
    return Icons.circle_outlined;
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
          const SizedBox(height: 12),
          Text(_errorMessage!, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
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
    // Tel hoeveel activiteiten zijn ingepland
    final ingeplandCount = _activities.where((a) => (a['p_score'] ?? 0) > 0).length;

    return Column(
      children: [
        // Header met datum en summary
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryTeal,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Text(
                DateFormat('EEEE d MMMM', 'nl_NL').format(DateTime.now()),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$ingeplandCount / 5 activiteiten ingepland',
                style: const TextStyle(
                  color: Colors.white,
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
    final isGedaan = dbActiviteit != null && (dbActiviteit['p_score'] ?? 0) > 0;
    final werkTijd = dbActiviteit?['actual_time'] as String? ?? null;
    final pScore = dbActiviteit?['p_score'] as int? ?? 0;

    final pColor = _getPScoreColor(pScore);

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
                color: isGedaan ? AppTheme.primaryTeal : Colors.grey[400],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

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
                      color: isGedaan ? AppTheme.textCharcoal : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Richt tijd
                      Icon(Icons.flag_outlined, size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        'Richt: $targetTijd',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
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

            // P-score badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: pColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Icon(
                    _getPScoreIcon(pScore),
                    color: pColor,
                    size: 20,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'P$pScore',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: pColor,
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
}