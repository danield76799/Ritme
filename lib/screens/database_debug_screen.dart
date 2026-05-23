import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../service_locator.dart';

class DatabaseDebugScreen extends StatefulWidget {
  const DatabaseDebugScreen({super.key});

  @override
  State<DatabaseDebugScreen> createState() => _DatabaseDebugScreenState();
}

class _DatabaseDebugScreenState extends State<DatabaseDebugScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final logs = await db.getDailyLogs();
      // Sort by date descending
      logs.sort((a, b) {
        final dateA = a['date']?.toString() ?? '';
        final dateB = b['date']?.toString() ?? '';
        return dateB.compareTo(dateA);
      });
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cleanupDatabase() async {
    // Toon bevestigingsdialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Database Opruimen'),
        content: const Text(
          'Dit verwijdert alle dubbele logs per dag en houdt alleen de meest recente log over.\n\n'
          'Weet je zeker dat je door wilt gaan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Opruimen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final db = await db.database;
      
      // Haal alle logs op
      final allLogs = await db.query('daily_logs', orderBy: 'date DESC, id DESC');
      
      // Groepeer per datum
      Map<String, List<int>> logsByDate = {};
      for (var log in allLogs) {
        final date = log['date']?.toString();
        final id = log['id'] as int?;
        if (date != null && id != null) {
          logsByDate.putIfAbsent(date, () => []).add(id);
        }
      }
      
      int deletedCount = 0;
      
      // Verwijder alle logs behalve de eerste (meest recente) per datum
      for (var entry in logsByDate.entries) {
        final ids = entry.value;
        if (ids.length > 1) {
          // Behoud de eerste (hoogste ID = meest recente)
          final idsToDelete = ids.sublist(1);
          for (var id in idsToDelete) {
            await db.delete('daily_logs', where: 'id = ?', whereArgs: [id]);
            deletedCount++;
          }
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$deletedCount dubbele logs verwijderd!'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadData(); // Herlaad de lijst
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fout bij opruimen: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetDatabase() async {
    // Toon bevestigingsdialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Database Reset'),
        content: const Text(
          'Dit verwijdert ALLE data uit de database.\n\n'
          'Dit kan niet ongedaan worden gemaakt!\n\n'
          'Weet je zeker dat je door wilt gaan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ALLES WISSEN'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final db = await db.database;
      await db.delete('daily_logs');
      await db.delete('life_events');
      await db.delete('srm_activities');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alle data is verwijderd!'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadData(); // Herlaad de lijst
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fout bij reset: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Database Debug', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primaryTeal,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Actie knoppen
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _cleanupDatabase,
                          icon: const Icon(Icons.cleaning_services),
                          label: const Text('Dubbele Verwijderen'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _resetDatabase,
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Alles Wissen'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Lijst van logs
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final date = log['date']?.toString() ?? 'Geen datum';
                      final stemming = log['stemming_hoog']?.toString() ?? '-';
                      final sleepHours = log['sleep_hours']?.toString() ?? '-';
                      final urenSlaap = log['uren_slaap']?.toString() ?? '-';
                      final awakeMinutes = log['awake_minutes']?.toString() ?? '-';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Datum: $date',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDataRow('Stemming:', stemming),
                            _buildDataRow('Sleep Hours:', sleepHours, isSleep: true),
                            _buildDataRow('Uren Slaap:', urenSlaap, isSleep: true),
                            _buildDataRow('Awake Minutes:', awakeMinutes),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDataRow(String label, String value, {bool isSleep = false}) {
    final hasData = value != '-' && value != 'null' && value.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isSleep && hasData ? Colors.blue : (hasData ? Colors.black : Colors.grey[400]),
            ),
          ),
          if (isSleep && hasData)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'SLAAP',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}