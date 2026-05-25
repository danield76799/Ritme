import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../service_locator.dart';
import '../widgets/datum_navigator.dart';

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  List<Map<String, dynamic>> _weightLogs = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  




  @override
  void initState() {
    super.initState();
    _loadWeightLogs();
  }

  Future<void> _loadWeightLogs() async {
    try {
      final logs = await db.getWeightLogs();
      // Sort by date ascending (oldest first) so most recent is on the right
      logs.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
      if (mounted) {
        setState(() {
          _weightLogs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('ERROR loading weight logs: $e');
      if (mounted) {
        setState(() {
          _weightLogs = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addWeightLog() async {
    // Check if weight already logged today
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final existingLog = _weightLogs.firstWhere(
      (log) => log['date'] == today,
      orElse: () => {},
    );
    
    final alreadyLoggedToday = existingLog.isNotEmpty;
    
    if (alreadyLoggedToday) {
      // Show edit dialog instead of error
      final weightController = TextEditingController(
        text: existingLog['weight']?.toString() ?? '',
      );
      final notesController = TextEditingController(
        text: existingLog['notes']?.toString() ?? '',
      );

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Gewicht bewerken'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Gewicht (kg) - gebruik punt (.)',
                  hintText: 'Bijv. 101.5',
                  prefixIcon: const Icon(Icons.monitor_weight),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notities (optioneel)',
                  prefixIcon: const Icon(Icons.notes),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            if (existingLog.isNotEmpty) ...[
              TextButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Gewicht verwijderen?'),
                      content: const Text('Deze actie kan niet ongedaan worden.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Annuleren'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Verwijderen', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    if (existingLog['id'] != null) {
                      await db.deleteWeightLog(existingLog['id']);
                    }
                    Navigator.pop(context, {'_delete': true});
                  }
                },
                child: const Text('Verwijderen', style: TextStyle(color: Colors.red)),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuleren'),
            ),
            ElevatedButton(
              onPressed: () {
                if (weightController.text.isNotEmpty) {
                  final normalizedWeight = weightController.text.replaceAll(',', '.');
                  final weight = double.tryParse(normalizedWeight);
                  
                  if (weight == null || weight < 20 || weight > 300) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Gewicht moet tussen 20 en 300 kg zijn. Gebruik een punt (.) als decimaal.'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                    return;
                  }
                  
                  Navigator.pop(context, {
                    'weight': weight,
                    'notes': notesController.text,
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Opslaan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (result != null) {
        // Delete old log and insert new one
        if (existingLog['id'] != null) {
          await db.deleteWeightLog(existingLog['id']);
        }
        await db.insertWeightLog(
          today,
          result['weight'],
          result['notes'].isEmpty ? null : result['notes'],
        );
        _loadWeightLogs();
      }
      return;
    }
    
    // New weight log
    final weightController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Gewicht toevoegen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Gewicht (kg) - gebruik punt (.)',
                hintText: 'Bijv. 101.5',
                prefixIcon: const Icon(Icons.monitor_weight),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notities (optioneel)',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () {
              if (weightController.text.isNotEmpty) {
                // Accept both comma and dot as decimal separator
                final normalizedWeight = weightController.text.replaceAll(',', '.');
                final weight = double.tryParse(normalizedWeight);
                
                // Validatie: gewicht moet realistisch zijn (20-300 kg)
                if (weight == null || weight < 20 || weight > 300) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Gewicht moet tussen 20 en 300 kg zijn. Gebruik een punt (.) als decimaal.'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  return;
                }
                
                Navigator.pop(context, {
                  'weight': weight,
                  'notes': notesController.text,
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Opslaan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      await db.insertWeightLog(
        dateStr,
        result['weight'],
        result['notes'].isEmpty ? null : result['notes'],
      );
      _loadWeightLogs();
    }
  }

  Future<void> _deleteWeightLog(int id) async {
    await db.deleteWeightLog(id);
    _loadWeightLogs();
  }

  List<FlSpot> _getChartData() {
    final spots = <FlSpot>[];
    for (int i = 0; i < _weightLogs.length; i++) {
      final log = _weightLogs[i];
      final weightValue = log['weight'];
      double weight;
      if (weightValue is String) {
        weight = double.tryParse(weightValue) ?? 0.0;
      } else if (weightValue is num) {
        weight = weightValue.toDouble();
      } else {
        weight = 0.0;
      }
      spots.add(FlSpot(i.toDouble(), weight));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        title: const Text(
          'Gewicht',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Datum navigator
                    DatumNavigator(
                      geselecteerdeDatum: _selectedDate,
                      onDatumVeranderd: (date) {
                        setState(() => _selectedDate = date);
                      },
                    ),
                    const SizedBox(height: 24),

                    // Grafiek
                    if (_weightLogs.length >= 2)
                      Container(
                        height: 250,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true, drawVerticalLine: false),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _getChartData(),
                                isCurved: true,
                                color: AppTheme.primaryTeal,
                                barWidth: 3,
                                dotData: FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (_weightLogs.length >= 2) const SizedBox(height: 24),

                    // Statistieken
                    if (_weightLogs.isNotEmpty)
                      _buildStatsCard(),

                    if (_weightLogs.isNotEmpty) const SizedBox(height: 24),

                    // Geschiedenis
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Geschiedenis',
                          style: TextStyle(
                            color: AppTheme.textCharcoal,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_weightLogs.isEmpty)
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.monitor_weight_outlined, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'Nog geen gewicht gelogd',
                              style: TextStyle(color: Colors.grey[500], fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _weightLogs.length,
                        itemBuilder: (context, index) {
                          // Show in reverse order (newest first)
                          final log = _weightLogs[_weightLogs.length - 1 - index];
                          final date = DateTime.parse(log['date']);
                          return Dismissible(
                            key: Key(log['id'].toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) async {
                              try {
                                await _deleteWeightLog(log['id']);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Gewicht verwijderd'),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Kon gewicht niet verwijderen: $e'),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                                // Reload to show the item again
                                _loadWeightLogs();
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.monitor_weight, color: AppTheme.primaryTeal),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${log['weight']} kg',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textCharcoal,
                                          ),
                                        ),
                                        if (log['notes'] != null && log['notes'].toString().isNotEmpty)
                                          Text(
                                            log['notes'],
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    DateFormat('d MMM yyyy').format(date),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addWeightLog,
        backgroundColor: AppTheme.primaryTeal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          _weightLogs.any((log) => log['date'] == DateFormat('yyyy-MM-dd').format(DateTime.now())) 
            ? 'Gewicht bewerken' 
            : 'Gewicht loggen',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final weights = _weightLogs.map((log) {
      final w = log['weight'];
      if (w is String) return double.tryParse(w) ?? 0.0;
      if (w is num) return w.toDouble();
      return 0.0;
    }).toList();
    final minWeight = weights.reduce((a, b) => a < b ? a : b);
    final maxWeight = weights.reduce((a, b) => a > b ? a : b);
    final avgWeight = weights.reduce((a, b) => a + b) / weights.length;
    
    double? weightChange;
    if (_weightLogs.length >= 2) {
      final firstValue = _weightLogs.first['weight'];
      final lastValue = _weightLogs.last['weight'];
      final first = (firstValue is String) ? double.tryParse(firstValue) ?? 0.0 : (firstValue as num).toDouble();
      final last = (lastValue is String) ? double.tryParse(lastValue) ?? 0.0 : (lastValue as num).toDouble();
      weightChange = last - first;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryTeal, AppTheme.primaryTeal.withValues(alpha: 0.8)],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistieken',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Gemiddeld', '${avgWeight.toStringAsFixed(1)} kg'),
              ),
              Expanded(
                child: _buildStatItem('Min', '${minWeight.toStringAsFixed(1)} kg'),
              ),
              Expanded(
                child: _buildStatItem('Max', '${maxWeight.toStringAsFixed(1)} kg'),
              ),
            ],
          ),
          if (weightChange != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    weightChange <= 0 ? Icons.trending_down : Icons.trending_up,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Verandering: ${weightChange > 0 ? '+' : ''}${weightChange.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}



