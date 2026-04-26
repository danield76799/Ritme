import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../widgets/datum_navigator.dart';

const Color primaryTeal = Color(0xFF4FB2C1);
const Color textCharcoal = Color(0xFF333333);
const Color backgroundColor = Color(0xFFF7F9FA);

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Datum navigatie
  DateTime _geselecteerdeDatum = DateTime.now();

  String get _formattedDate {
    return '${_geselecteerdeDatum.year}-${_geselecteerdeDatum.month.toString().padLeft(2, '0')}-${_geselecteerdeDatum.day.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _activiteiten = [
    {'naam': 'Opstaan', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0, 'icoon': Icons.bedtime_outlined},
    {'naam': 'Eerste contact', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0, 'icoon': Icons.coffee_outlined},
    {'naam': 'Werk / Hobby', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0, 'icoon': Icons.work_outline},
    {'naam': 'Avondeten', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0, 'icoon': Icons.restaurant_outlined},
    {'naam': 'Naar bed', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0, 'icoon': Icons.nights_stay_outlined},
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

    // Load selected date's activities
    final activities = await db.getSrmActivities(_formattedDate);
    
    // Populate actual times and p-scores from database
    for (var activity in activities) {
      final index = _activiteiten.indexWhere((a) => a['naam'] == activity['activity_type']);
      if (index != -1) {
        _activiteiten[index]['werkelijke_tijd'] = _parseTimeOfDay(activity['actual_time']);
        _activiteiten[index]['p_score'] = activity['p_score'] ?? 0;
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onDatumVeranderd(DateTime nieuweDatum) {
    setState(() {
      _geselecteerdeDatum = nieuweDatum;
      _isLoading = true;
      // Reset activiteiten voor nieuwe datum
      _activiteiten = [
        {'naam': 'Opstaan', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0, 'icoon': Icons.bedtime_outlined},
        {'naam': 'Eerste contact', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0, 'icoon': Icons.coffee_outlined},
        {'naam': 'Werk / Hobby', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0, 'icoon': Icons.work_outline},
        {'naam': 'Avondeten', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0, 'icoon': Icons.restaurant_outlined},
        {'naam': 'Naar bed', 'richttijd': null, 'werkelijke_tijd': null, 'p_score': 0, 'icoon': Icons.nights_stay_outlined},
      ];
    });
    _loadData();
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
        'date': _formattedDate,
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
          content: Text(
            'SRM activiteiten voor ${_formattedDate} opgeslagen! SRT punten: $totaalSrtPunten/${_activiteiten.length}',
          ),
          backgroundColor: primaryTeal,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _showAddActivityDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddActivityBottomSheet(),
    );
  }

  Widget _buildAddActivityBottomSheet() {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Nieuwe Activiteit',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textCharcoal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Voeg een aangepaste activiteit toe voor ${DateFormat('d MMMM', 'nl_NL').format(_geselecteerdeDatum)}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          TextField(
            decoration: InputDecoration(
              labelText: 'Activiteit naam',
              hintText: 'Bijv. Sporten, Lezen, Mediteren',
              prefixIcon: Icon(Icons.label_outline, color: primaryTeal),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryTeal, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              labelText: 'Tijdstip',
              hintText: '14:30',
              prefixIcon: Icon(Icons.access_time, color: primaryTeal),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryTeal, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            keyboardType: TextInputType.datetime,
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              labelText: 'P-Score (0-3)',
              hintText: '0 = Alleen, 3 = Anderen stimuleerden mij',
              prefixIcon: Icon(Icons.people_outline, color: primaryTeal),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryTeal, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: Implementeer activiteit toevoegen logica
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Activiteit Toevoegen',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
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
        title: const Text(
          'SRM Activiteiten',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Datum Navigator
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: DatumNavigator(
              geselecteerdeDatum: _geselecteerdeDatum,
              onDatumVeranderd: _onDatumVeranderd,
            ),
          ),

          // Uitleg P-Score
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SRM Meting ${_geselecteerdeDatum.day == DateTime.now().day ? 'vandaag' : 'voor ${DateFormat('d MMMM', 'nl_NL').format(_geselecteerdeDatum)}'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textCharcoal,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'P-score (betrokkenheid anderen):',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textCharcoal,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '0 = Alleen  •  1 = Anderen aanwezig  •  2 = Anderen deden mee  •  3 = Anderen stimuleerden mij',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SRT punt: 1 punt als binnen ±45 min van richttijd',
                        style: TextStyle(
                          fontSize: 12,
                          color: primaryTeal,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Activiteiten lijst
          Expanded(
            child: _activiteiten.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _activiteiten.length,
                    itemBuilder: (context, index) => _buildActivityCard(index),
                  ),
          ),

          // Opslaan knop
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _opslaan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Activiteiten Opslaan',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddActivityDialog,
        backgroundColor: primaryTeal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Activiteit Toevoegen',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryTeal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.self_improvement_outlined,
              size: 64,
              color: primaryTeal.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Nog geen activiteiten gelogd',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textCharcoal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tijd voor ontspanning?\nVoeg je eerste activiteit toe!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showAddActivityDialog,
            icon: const Icon(Icons.add),
            label: const Text('Activiteit Toevoegen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(int index) {
    final activiteit = _activiteiten[index];
    final srtPunt = _berekenSrtPunt(
      activiteit['werkelijke_tijd'],
      activiteit['richttijd'],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryTeal.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    activiteit['icoon'] as IconData,
                    color: primaryTeal,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Title and SRT badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activiteit['naam'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textCharcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (activiteit['werkelijke_tijd'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: srtPunt == 1
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            srtPunt == 1 ? '+1 SRT punt' : '0 SRT punten',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: srtPunt == 1 ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Time chips
            Row(
              children: [
                // Planned time
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gepland',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              _formatTijd(activiteit['richttijd']),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: textCharcoal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Actual time
                Expanded(
                  child: InkWell(
                    onTap: () => _kiesTijd(context, index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: activiteit['werkelijke_tijd'] != null
                            ? primaryTeal.withOpacity(0.1)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: activiteit['werkelijke_tijd'] != null
                            ? Border.all(color: primaryTeal.withOpacity(0.3))
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: activiteit['werkelijke_tijd'] != null
                                ? primaryTeal
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Werkelijk',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: activiteit['werkelijke_tijd'] != null
                                      ? primaryTeal
                                      : Colors.grey[600],
                                ),
                              ),
                              Text(
                                _formatTijd(activiteit['werkelijke_tijd']),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: activiteit['werkelijke_tijd'] != null
                                      ? primaryTeal
                                      : textCharcoal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // P-Score
            Row(
              children: [
                Text(
                  'P-Score:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 12),
                ...[0, 1, 2, 3].map((score) {
                  bool isGeselecteerd = activiteit['p_score'] == score;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        activiteit['p_score'] = score;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isGeselecteerd ? primaryTeal : Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isGeselecteerd
                            ? [
                                BoxShadow(
                                  color: primaryTeal.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        '$score',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isGeselecteerd ? Colors.white : Colors.grey[600],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
