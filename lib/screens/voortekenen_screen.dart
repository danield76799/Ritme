import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../service_locator.dart';

class VoortekenenScreen extends StatefulWidget {
  const VoortekenenScreen({super.key});

  @override
  State<VoortekenenScreen> createState() => _VoortekenenScreenState();
}

class _VoortekenenScreenState extends State<VoortekenenScreen> {
  List<Map<String, dynamic>> _checklist = [];
  Map<int, Map<String, int>> _todaysLogs = {}; // checklist_id -> {present, severity}
  Map<int, String> _todaysNotes = {}; // checklist_id -> notes
  bool _isLoading = true;
  bool _isSaving = false;

  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final checklist = await db.getEnabledProdromalChecklist();
      final todaysLogs = await db.getProdromalLogs(_todayDate);

      final logsMap = <int, Map<String, int>>{};
      final notesMap = <int, String>{};
      for (var log in todaysLogs) {
        final cid = log['checklist_id'];
        if (cid != null) {
          logsMap[cid] = {
            'present': log['present'] is int ? log['present'] : int.tryParse('${log['present']}') ?? 0,
            'severity': log['severity'] is int ? log['severity'] : int.tryParse('${log['severity']}') ?? 1,
          };
          notesMap[cid] = log['notes']?.toString() ?? '';
        }
      }

      if (mounted) {
        setState(() {
          _checklist = checklist;
          _todaysLogs = logsMap;
          _todaysNotes = notesMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'manie':
        return '⚠️ Manie/hypomanie';
      case 'depressie':
        return '🔵 Depressie';
      case 'gemengd':
        return '🟡 Gemengd/stress';
      default:
        return category;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'manie':
        return Colors.orange;
      case 'depressie':
        return Colors.blue;
      case 'gemengd':
        return Colors.amber.shade700;
      default:
        return Colors.grey;
    }
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    try {
      for (var item in _checklist) {
        final cid = item['id'] as int;
        final log = _todaysLogs[cid];
        await db.insertProdromalLog({
          'date': _todayDate,
          'checklist_id': cid,
          'present': log?['present'] ?? 0,
          'severity': log?['severity'] ?? 1,
          'notes': _todaysNotes[cid] ?? '',
        });
      }

      // Check for warnings
      final summary = await db.getProdromalSummary(_todayDate);
      final manieCount = summary?['manie_count'];
      final depressieCount = summary?['depressie_count'];

      if (mounted) {
        String message = 'Voortekenen opgeslagen ✓';
        if (manieCount != null && manieCount > 3) {
          message += '\n⚠️ Let op: ${manieCount} manie-voortekenen vandaag';
        }
        if (depressieCount != null && depressieCount > 3) {
          message += '\n⚠️ Let op: ${depressieCount} depressie-voortekenen vandaag';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: (manieCount > 3 || depressieCount > 3) ? Colors.orange : AppTheme.primaryTeal,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fout bij opslaan'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(backgroundColor: AppTheme.primaryTeal, title: const Text('Voortekenen', style: TextStyle(color: Colors.white))),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal)),
      );
    }

    String? lastCategory;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        title: const Text('Voortekenen', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton.icon(
            onPressed: () => _showHistory(context),
            icon: const Icon(Icons.history, color: Colors.white),
            label: const Text('Historie', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Check dagelijks je voortekenen. Bij 4+ signalen in één categorie: overleg met je behandelaar.',
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Checklist items grouped by category
            ..._checklist.map((item) {
              final category = item['category'] as String;
              final showHeader = category != lastCategory;
              lastCategory = category;
              final cid = item['id'] as int;
              final log = _todaysLogs[cid];
              final isPresent = (log?['present'] ?? 0) == 1;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showHeader) ...[
                    const SizedBox(height: 8),
                    Text(
                      _categoryLabel(category),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _categoryColor(category)),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _buildCheckItem(item, isPresent, cid, log?['severity'] ?? 1),
                ],
              );
            }),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Opslaan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(Map<String, dynamic> item, bool isPresent, int cid, int severity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isPresent ? Colors.orange.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPresent ? Colors.orange.shade300 : Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            final newPresent = isPresent ? 0 : 1;
            _todaysLogs[cid] = {'present': newPresent, 'severity': severity};
            if (!isPresent) {
              _todaysNotes[cid] = _todaysNotes[cid] ?? '';
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                isPresent ? Icons.check_box : Icons.check_box_outline_blank,
                color: isPresent ? Colors.orange : Colors.grey.shade400,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item['sign'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isPresent ? FontWeight.w600 : FontWeight.normal,
                    color: AppTheme.textCharcoal,
                  ),
                ),
              ),
              if (isPresent)
                PopupMenuButton<int>(
                  padding: EdgeInsets.zero,
                  icon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: severity >= 3 ? Colors.red.shade100 : severity == 2 ? Colors.orange.shade100 : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      severity >= 3 ? 'Ernstig' : severity == 2 ? 'Matig' : 'Licht',
                      style: TextStyle(fontSize: 11, color: severity >= 3 ? Colors.red : severity == 2 ? Colors.orange.shade800 : Colors.green.shade800),
                    ),
                  ),
                  onSelected: (val) {
                    setState(() {
                      _todaysLogs[cid] = {'present': 1, 'severity': val};
                    });
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 1, child: Text('Licht', style: TextStyle(color: Colors.green.shade700))),
                    PopupMenuItem(value: 2, child: Text('Matig', style: TextStyle(color: Colors.orange.shade700))),
                    PopupMenuItem(value: 3, child: Text('Ernstig', style: TextStyle(color: Colors.red.shade700))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Voortekenen Historie'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: db.getRecentProdromalTrends(14),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Nog geen historie'));
              }
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, i) {
                  final item = snapshot.data![i];
                  final count = item['warning_count'];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: count > 5 ? Colors.red.shade100 : Colors.orange.shade100,
                      child: Text('$count', style: TextStyle(color: count > 5 ? Colors.red : Colors.orange.shade800, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(item['date'] as String),
                    subtitle: Text('$count voortekenen', style: TextStyle(color: Colors.grey[600])),
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Sluiten'))],
      ),
    );
  }
}
