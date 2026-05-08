import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../service_locator.dart';
import '../utils/logger.dart';

class MedicationScheduleScreen extends StatefulWidget {
  const MedicationScheduleScreen({super.key});

  @override
  State<MedicationScheduleScreen> createState() => _MedicationScheduleScreenState();
}

class _MedicationScheduleScreenState extends State<MedicationScheduleScreen> {
  List<Map<String, dynamic>> _schedules = [];
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
      // Get medication schedules from database
      final schedules = await (db as dynamic).getMedicationSchedules?.call() ?? [];
      setState(() {
        _schedules = schedules;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load medication schedules', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Kon medicatieschema niet laden.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Medicatie Schema', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : _errorMessage != null
              ? _buildErrorWidget()
              : _schedules.isEmpty
                  ? _buildEmptyState()
                  : _buildSchedulesList(),
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
            'Geen schema ingesteld',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            'Voeg een medicatieschema toe',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _schedules.length,
      itemBuilder: (context, index) {
        final schedule = _schedules[index];
        return _buildScheduleCard(schedule);
      },
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    final time = schedule['reminder_time'] ?? '--:--';
    final days = schedule['days_of_week'] ?? '1,2,3,4,5,6,7';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryTeal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.access_time, color: AppTheme.primaryTeal),
        ),
        title: Text('Herinnering: $time', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Dagen: $days'),
      ),
    );
  }
}
