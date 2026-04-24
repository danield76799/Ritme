import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../main.dart';

const Color primaryTeal = Color(0xFF4FB2C1);
const Color textCharcoal = Color(0xFF333333);
const Color backgroundColor = Color(0xFFFAFAFA);

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _activiteiten = [
    {'naam': 'Opstaan', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0},
    {'naam': 'Eerste contact', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0},
    {'naam': 'Werk / Hobby', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0},
    {'naam': 'Avondeten', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0},
    {'naam': 'Naar bed', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load target times from settings
    final settings = await db.getSettings();
    if (settings != null) {
      _activiteiten[0]['richttijd'] = _parseTimeOfDay(settings['target_wake_time']);
      _activiteiten[1]['richttijd'] = _parseTimeOfDay(settings['target_first_contact']);
      _activiteiten[2]['richttijd'] = _parseTimeOfDay(settings['target_work']);
      _activiteiten[3]['richttijd'] = _parseTimeOfDay(settings['target_dinner']);
      _activiteiten[4]['richttijd'] = _parseTimeOfDay(settings['target_sleep_time']);
    }

    // Load today's activities
    final activities = await db.getSrmActivities(_todayDate);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  TimeOfDay? _parseTimeOfDay(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return null;
    }
  }

  String _formatTijd(TimeOfDay? tijd) {
    if (tijd == null) return '--:--';
    final uur = tijd.hour.toString().padLeft(2, '0');
    final minuut = tijd.minute.toString().padLeft(2, '0');
    return '$uur:$minuut';
  }

  String _timeOfDayToString(TimeOfDay? tijd) {
    if (tijd == null) return '';
    return '${tijd.hour.toString().padLeft(2, '0')}:${tijd.minute.toString().padLeft(2, '0')}';
  }

  // Bereken SRT punten: 1 punt als binnen +/- 45 minuten van richttijd
  int _berekenSrtPunt(TimeOfDay? werkelijke, TimeOfDay? richt) {
    if (werkelijke == null || richt == null) return 0;
    
    final werkelijkeMinuten = werkelijke.hour * 60 + werkelijke.minute;
    final richtMinuten = richt.hour * 60 + richt.minute;
    final verschil = (werkelijkeMinuten - richtMinuten).abs();
    
    return verschil <= 45 ? 1 : 0;
  }

  Future<void> _kiesTijd(BuildContext context, int index) async {
    final TimeOfDay? gekozenTijd = await showTimePicker(
      context: context,
      initialTime: _activiteiten[index]['werkelijke_tijd'] ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: primaryTeal),
          ),
          child: child!,
        );
      },
    );

    if (gekozenTijd != null) {
      setState(() {
        _activiteiten[index]['werkelijke_tijd'] = gekozenTijd;
      });
    }
  }

  Future<void> _opslaan() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    int totaalSrtPunten = 0;

    for (int i = 0; i < _activiteiten.length; i++) {
      final activiteit = _activiteiten[i];
      final werkelijke = activiteit['werkelijke_tijd'] as TimeOfDay?;
      final richt = activiteit['richttijd'] as TimeOfDay?;
      final pScore = activiteit['p_score'] as int;
      
      final srtPunt = _berekenSrtPunt(werkelijke, richt);
      totaalSrtPunten += srtPunt;

      await db.insertSrmActivityMap({
        'date': _todayDate,
        'activity_type': activiteit['naam'],
        'actual_time': _timeOfDayToString(werkelijke),
        'p_score': pScore,
        'srt_point': srtPunt,
      });
    }

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SRM activiteiten opgeslagen! SRT punten: $totaalSrtPunten/${_activiteiten.length}'),
          backgroundColor: primaryTeal,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: primaryTeal),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryTeal,
        elevation: 0,
        title: const Text('SRM Meting', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Uitleg P-Score
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('P-score (betrokkenheid anderen):', style: TextStyle(fontWeight: FontWeight.bold, color: textCharcoal)),
                const SizedBox(height: 8),
                Text(
                  '0 = Alleen\n1 = Anderen aanwezig\n2 = Anderen deden ook mee\n3 = Anderen stimuleerden mij',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Text(
                  'SRT punt: 1 punt als binnen ±45 min van richttijd',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _activiteiten.length,
              itemBuilder: (context, index) {
                final activiteit = _activiteiten[index];
                final srtPunt = _berekenSrtPunt(
                  activiteit['werkelijke_tijd'],
                  activiteit['richttijd'],
                );
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              activiteit['naam'],
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textCharcoal),
                            ),
                          ),
                          if (activiteit['werkelijke_tijd'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: srtPunt == 1 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                srtPunt == 1 ? '+1 SRT' : '0 SRT',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: srtPunt == 1 ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Richttijd: ${_formatTijd(activiteit['richttijd'])}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          // Tijd invullen knop
                          Expanded(
                            child: InkWell(
                              onTap: () => _kiesTijd(context, index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: backgroundColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.access_time, size: 18, color: primaryTeal),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatTijd(activiteit['werkelijke_tijd']),
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textCharcoal),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // P-score knoppen
                          Row(
                            children: [0, 1, 2, 3].map((score) {
                              bool isGeselecteerd = activiteit['p_score'] == score;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    activiteit['p_score'] = score;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isGeselecteerd ? primaryTeal : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$score',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isGeselecteerd ? Colors.white : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _opslaan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Activiteiten Opslaan', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
