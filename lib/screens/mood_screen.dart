import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../service_locator.dart';
import '../widgets/datum_navigator.dart';

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  final Color primaryTeal = const Color(0xFF4FB2C1);
  final Color textCharcoal = const Color(0xFF333333);
  final Color backgroundColor = const Color(0xFFF7F9FA);

  // Datum navigatie
  DateTime _geselecteerdeDatum = DateTime.now();

  // Stemming waarden
  double _stemmingWaarde = 50.0; // 0-100 (0=depressief, 50=neutraal, 100=manisch)
  int _stemmingsOmslagen = 0;
  bool _isLoading = true;

  String get _formattedDate {
    return '${_geselecteerdeDatum.year}-${_geselecteerdeDatum.month.toString().padLeft(2, '0')}-${_geselecteerdeDatum.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final log = await db.getDailyLog(_formattedDate);

    if (log != null) {
      // Converteer stemming_ochtend (-5 tot +5) naar 0-100 schaal
      final stemming = log['stemming_ochtend'] as int?;
      if (stemming != null) {
        _stemmingWaarde = ((stemming + 5) / 10 * 100).clamp(0.0, 100.0);
      }

      final omslagen = log['stemmingsomslagen'] as int?;
      if (omslagen != null) {
        _stemmingsOmslagen = omslagen;
      }
    } else {
      // Reset naar defaults
      _stemmingWaarde = 50.0;
      _stemmingsOmslagen = 0;
    }

    setState(() => _isLoading = false);
  }

  void _onDatumVeranderd(DateTime nieuweDatum) {
    setState(() {
      _geselecteerdeDatum = nieuweDatum;
    });
    _loadData();
  }

  Future<void> _opslaan() async {
    // Converteer 0-100 terug naar -5 tot +5
    final stemming = ((_stemmingWaarde / 100) * 10 - 5).round();

    await db.upsertDailyLog({
      'date': _formattedDate,
      'stemming_ochtend': stemming,
      'stemmingsomslagen': _stemmingsOmslagen,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stemming voor ${_formattedDate} opgeslagen!'),
          backgroundColor: primaryTeal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  String _getStemmingLabel(double waarde) {
    if (waarde <= 10) return 'Uiterst depressief';
    if (waarde <= 25) return 'Depressief';
    if (waarde <= 40) return 'Neerslachtig';
    if (waarde <= 60) return 'Neutraal';
    if (waarde <= 75) return 'Opgewekt';
    if (waarde <= 90) return 'Manisch';
    return 'Uiterst manisch';
  }

  Color _getStemmingKleur(double waarde) {
    if (waarde <= 25) return Colors.blue[700]!;
    if (waarde <= 40) return Colors.blue[400]!;
    if (waarde <= 60) return Colors.grey[500]!;
    if (waarde <= 75) return Colors.orange[400]!;
    return Colors.red[400]!;
  }

  void _veranderOmslagen(int change) {
    setState(() {
      _stemmingsOmslagen = (_stemmingsOmslagen + change).clamp(0, 10);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryTeal,
        elevation: 0,
        title: const Text(
          'Stemming',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryTeal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Datum Navigator
                  Container(
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
                    child: DatumNavigator(
                      geselecteerdeDatum: _geselecteerdeDatum,
                      onDatumVeranderd: _onDatumVeranderd,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stemming Slider Kaart
                  Container(
                    padding: const EdgeInsets.all(24),
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
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryTeal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.sentiment_satisfied_outlined,
                                color: primaryTeal,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Hoe voel je je?',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textCharcoal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Geef aan hoe je stemming is op ${DateFormat('d MMMM').format(_geselecteerdeDatum)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Stemming waarde display
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          decoration: BoxDecoration(
                            color: _getStemmingKleur(_stemmingWaarde).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _stemmingWaarde.round().toString(),
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: _getStemmingKleur(_stemmingWaarde),
                                ),
                              ),
                              Text(
                                _getStemmingLabel(_stemmingWaarde),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: _getStemmingKleur(_stemmingWaarde),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Slider
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: primaryTeal,
                            inactiveTrackColor: Colors.grey[200],
                            thumbColor: primaryTeal,
                            overlayColor: primaryTeal.withOpacity(0.2),
                            trackHeight: 8,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 12,
                              elevation: 4,
                            ),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                          ),
                          child: Slider(
                            value: _stemmingWaarde,
                            min: 0,
                            max: 100,
                            divisions: 100,
                            onChanged: (value) {
                              setState(() {
                                _stemmingWaarde = value;
                              });
                            },
                          ),
                        ),

                        // Labels onder slider
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                children: [
                                  Icon(Icons.sentiment_very_dissatisfied, color: Colors.blue[700], size: 20),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Depressief',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Icon(Icons.sentiment_neutral, color: Colors.grey[500], size: 20),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Neutraal',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Icon(Icons.sentiment_very_satisfied, color: Colors.red[400], size: 20),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Manisch',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stemmingsomslagen Kaart
                  Container(
                    padding: const EdgeInsets.all(24),
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
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryTeal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.swap_vert,
                                color: primaryTeal,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Stemmingsschommelingen',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textCharcoal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Aantal plotselinge grote veranderingen in stemming vandaag',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Teller
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.remove, color: textCharcoal),
                              ),
                              onPressed: () => _veranderOmslagen(-1),
                            ),
                            Container(
                              width: 80,
                              alignment: Alignment.center,
                              child: Text(
                                '$_stemmingsOmslagen',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: _stemmingsOmslagen > 0 ? Colors.orange[700] : textCharcoal,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primaryTeal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.add, color: primaryTeal),
                              ),
                              onPressed: () => _veranderOmslagen(1),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            _stemmingsOmslagen == 0
                                ? 'Geen schommelingen'
                                : _stemmingsOmslagen == 1
                                    ? '1 schommeling'
                                    : '$_stemmingsOmslagen schommelingen',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Opslaan knop
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _opslaan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryTeal,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Stemming Opslaan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}