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
      // Sort by date descending, then by id descending (most recent first)
      logs.sort((a, b) {
        final dateA = a['date']?.toString() ?? '';
        final dateB = b['date']?.toString() ?? '';
        final dateCompare = dateB.compareTo(dateA);
        if (dateCompare != 0) return dateCompare;
        final idA = a['id'] as int? ?? 0;
        final idB = b['id'] as int? ?? 0;
        return idB.compareTo(idA);
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Database Opruimen'),
        content: const Text(
          'Dit markeert alle dubbele logs per dag als leeg.\n\n'
          'Alleen de meest recente log per dag blijft behouden.\n\n'
          'Weet je zeker dat je door wilt gaan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Opruimen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      // Groepeer per datum
      Map<String, List<Map<String, dynamic>>> logsByDate = {};
      for (var log in _logs) {
        final date = log['date']?.toString();
        if (date != null) {
          logsByDate.putIfAbsent(date, () => []).add(log);
        }
      }

      int cleanedCount = 0;

      // Voor elke datum, behoud alleen de eerste (meest recente) log
      for (var entry in logsByDate.entries) {
        final logsForDate = entry.value;
        if (logsForDate.length > 1) {
          // Overschrijf oude logs met lege waarden (behalve de eerste)
          for (int i = 1; i < logsForDate.length; i++) {
            final oldLog = logsForDate[i];
            await db.upsertDailyLog({
              'date': entry.key,
              'stemming_hoog': null,
              'stemming_laag': null,
              'gesplitste_stemming': null,
              'stemmingsomslagen': null,
              'ontstemde_manie': null,
              'daglicht': null,
              'sociale_contacten': null,
              'sleep_hours': null,
              'uren_slaap': null,
              'awake_minutes': null,
            });
            cleanedCount++;
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$cleanedCount dubbele logs opgeruimd!'),
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
      // Wis alle data door lege logs te maken voor alle datums
      final allLogs = await db.getDailyLogs();
      for (var log in allLogs) {
        final date = log['date']?.toString();
        if (date != null) {
          await db.upsertDailyLog({
            'date': date,
            'stemming_hoog': null,
            'stemming_laag': null,
            'gesplitste_stemming': null,
            'stemmingsomslagen': null,
            'ontstemde_manie': null,
            'daglicht': null,
            'sociale_contacten': null,
            'sleep_hours': null,
            'uren_slaap': null,
            'awake_minutes': null,
          });
        }
      }

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
                          label: const Text('Dubbele Opruimen'),
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
                              color: Colors.black.withValues(alpha: 0.05),
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
              color: Colors.grey.shade600,
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
                color: Colors.blue.withValues(alpha: 0.1),
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