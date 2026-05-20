import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../service_locator.dart';
import '../widgets/datum_navigator.dart';

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {

  DateTime _geselecteerdeDatum = DateTime.now();
  double _stemmingWaarde = 50.0;
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
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      if (!isDbInitialized) {
        debugPrint('MoodScreen: db not initialized, initializing...');
        await initDatabase();
      }
      final log = await db.getDailyLog(_formattedDate);
      if (!mounted) return;
      if (log != null) {
        final stemming = log['stemming_ochtend'] as int?;
        if (stemming != null) {
          _stemmingWaarde = ((stemming + 5) / 10 * 100).clamp(0.0, 100.0);
        }
        final omslagen = log['stemmingsomslagen'] as int?;
        if (omslagen != null) _stemmingsOmslagen = omslagen;
      } else {
        _stemmingWaarde = 50.0;
        _stemmingsOmslagen = 0;
      }
    } catch (e, stack) {
      debugPrint('MoodScreen _loadData error: $e');
      debugPrint('Stack: $stack');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _onDatumVeranderd(DateTime nieuweDatum) {
    setState(() => _geselecteerdeDatum = nieuweDatum);
    _loadData();
  }

  Future<void> _opslaan() async {
    final stemming = ((_stemmingWaarde / 100) * 10 - 5).round();
    
    // Validatie: stemming moet tussen -5 en 5 zijn
    if (stemming < -5 || stemming > 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Stemming waarde moet tussen -5 en 5 zijn'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return;
    }
    
    // Validatie: omslagen moet tussen 0 en 10 zijn
    if (_stemmingsOmslagen < 0 || _stemmingsOmslagen > 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Aantal omslagen moet tussen 0 en 10 zijn'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return;
    }

    await db.upsertDailyLog({
      'date': _formattedDate,
      'stemming_ochtend': stemming,
      'stemmingsomslagen': _stemmingsOmslagen,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Opgeslagen!'),
          backgroundColor: AppTheme.primaryTeal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 1),
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
    if (waarde <= 10) return Colors.grey[700]!;      // Uiterst depressief - donkergrijs
    if (waarde <= 25) return Colors.grey[500]!;      // Depressief - grijs
    if (waarde <= 40) return Colors.blue[300]!;      // Neerslachtig - lichtblauw
    if (waarde <= 60) return Colors.green[400]!;     // Neutraal - groen
    if (waarde <= 75) return Colors.orange[400]!;    // Opgewekt - oranje
    if (waarde <= 90) return Colors.orange[700]!;    // Manisch - donkeroranje
    return Colors.red[400]!;                           // Uiterst manisch - rood
  }

  void _veranderOmslagen(int change) {
    setState(() {
      _stemmingsOmslagen = (_stemmingsOmslagen + change).clamp(0, 10);
    });
  }

  @override
  Widget build(BuildContext context) {
    try {
      return _buildMoodScreen(context);
    } catch (e, stack) {
      debugPrint('MoodScreen build error: $e');
      debugPrint('Stack: $stack');
      return Scaffold(
        appBar: AppBar(title: const Text('Stemming - Fout')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text('Fout: $e', style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildMoodScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Stemming',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _opslaan,
            child: const Text('Opslaan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : Column(
              children: [
                Container(color: Colors.white, child: DatumNavigator(geselecteerdeDatum: _geselecteerdeDatum, onDatumVeranderd: _onDatumVeranderd)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Compact mood card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            children: [
                              // Date label
                              Text(
                                DateFormat('EEEE d MMMM', 'nl_NL').format(_geselecteerdeDatum),
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 16),
                              // Mood value
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                                decoration: BoxDecoration(
                                  color: _getStemmingKleur(_stemmingWaarde).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _stemmingWaarde.round().toString(),
                                      style: TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        color: _getStemmingKleur(_stemmingWaarde),
                                      ),
                                    ),
                                    Text(
                                      _getStemmingLabel(_stemmingWaarde),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: _getStemmingKleur(_stemmingWaarde),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Slider
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: _getStemmingKleur(_stemmingWaarde),
                                  inactiveTrackColor: Colors.grey[200],
                                  thumbColor: _getStemmingKleur(_stemmingWaarde),
                                  overlayColor: _getStemmingKleur(_stemmingWaarde).withValues(alpha: 0.2),
                                  trackHeight: 6,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                                ),
                                child: Slider(
                                  value: _stemmingWaarde,
                                  min: 0,
                                  max: 100,
                                  divisions: 100,
                                  onChanged: (value) => setState(() => _stemmingWaarde = value),
                                ),
                              ),
                              // Labels
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('😞 Depressief', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                    Text('Neutraal', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                    Text('Manisch 😄', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Mood swings counter
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.swap_vert, color: Colors.orange, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Stemmingsomslagen',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                                    ),
                                    Text(
                                      'Aantal keren dat stemming wisselde',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildCounterBtn(Icons.remove, _stemmingsOmslagen > 0 ? () => _veranderOmslagen(-1) : null),
                                  Container(width: 36, alignment: Alignment.center, child: Text('$_stemmingsOmslagen', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                                  _buildCounterBtn(Icons.add, () => _veranderOmslagen(1), isPrimary: true),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCounterBtn(IconData icon, VoidCallback? onPressed, {bool isPrimary = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isPrimary ? AppTheme.primaryTeal : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: isPrimary ? Colors.white : Colors.grey[600]),
        ),
      ),
    );
  }
}

