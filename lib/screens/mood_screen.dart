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
  double _stemmingHoog = 50.0;  // Hoogste stemming niveau (0-100)
  double _stemmingLaag = 50.0;  // Laagste stemming niveau (0-100)
  bool _gesplitsteStemming = false; // Of er een gesplitste stemming is
  int _stemmingsOmslagen = 0;
  bool _ontstemdeManie = false;
  double _urenSlaap = 7.0;
  double _gewicht = 0.0;
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
        // Life Chart: stemming 0-100 (gesplitst mogelijk)
        final stemmingHoog = log['stemming_hoog'] as double?;
        final stemmingLaag = log['stemming_laag'] as double?;
        if (stemmingHoog != null) {
          _stemmingHoog = stemmingHoog;
        }
        if (stemmingLaag != null) {
          _stemmingLaag = stemmingLaag;
          _gesplitsteStemming = true;
        } else {
          _stemmingLaag = _stemmingHoog;
          _gesplitsteStemming = false;
        }
        
        _stemmingsOmslagen = log['stemmingsomslagen'] as int? ?? 0;
        _ontstemdeManie = log['ontstemde_manie'] as bool? ?? false;
        _urenSlaap = log['uren_slaap'] as double? ?? 7.0;
        _gewicht = log['gewicht'] as double? ?? 0.0;
      } else {
        _stemmingHoog = 50.0;
        _stemmingLaag = 50.0;
        _gesplitsteStemming = false;
        _stemmingsOmslagen = 0;
        _ontstemdeManie = false;
        _urenSlaap = 7.0;
        _gewicht = 0.0;
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
    try {
      if (!isDbInitialized) {
        await initDatabase();
      }
      
      await db.upsertDailyLog({
        'date': _formattedDate,
        'stemming_hoog': _stemmingHoog,
        'stemming_laag': _gesplitsteStemming ? _stemmingLaag : _stemmingHoog,
        'gesplitste_stemming': _gesplitsteStemming,
        'stemmingsomslagen': _stemmingsOmslagen,
        'ontstemde_manie': _ontstemdeManie,
        'uren_slaap': _urenSlaap,
        'gewicht': _gewicht,
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
    } catch (e) {
      debugPrint('MoodScreen _opslaan error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij opslaan: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  String _getStemmingLabel(double waarde) {
    if (waarde <= 10) return 'Uiterst depressief';
    if (waarde <= 25) return 'Ernstig depressief';
    if (waarde <= 40) return 'Matig depressief';
    if (waarde <= 45) return 'Licht depressief';
    if (waarde <= 55) return 'Neutraal';
    if (waarde <= 65) return 'Licht manisch';
    if (waarde <= 75) return 'Matig manisch';
    if (waarde <= 90) return 'Ernstig manisch';
    return 'Uiterst manisch';
  }

  Color _getStemmingKleur(double waarde) {
    if (waarde <= 10) return Colors.grey[800]!;     // Uiterst depressief - donkergrijs
    if (waarde <= 25) return Colors.grey[600]!;     // Ernstig depressief - grijs
    if (waarde <= 40) return Colors.blue[400]!;     // Matig depressief - blauw
    if (waarde <= 45) return Colors.blue[200]!;     // Licht depressief - lichtblauw
    if (waarde <= 55) return Colors.green[400]!;    // Neutraal - groen
    if (waarde <= 65) return Colors.yellow[600]!;   // Licht manisch - geel
    if (waarde <= 75) return Colors.orange[500]!;   // Matig manisch - oranje
    if (waarde <= 90) return Colors.orange[700]!;   // Ernstig manisch - donkeroranje
    return Colors.red[500]!;                          // Uiterst manisch - rood
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
          'Life Chart',
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
                        // Hoogste stemming (0-100)
                        _buildStemmingCard(
                          title: 'Hoogste stemming vandaag',
                          value: _stemmingHoog,
                          onChanged: (value) => setState(() => _stemmingHoog = value),
                          color: _getStemmingKleur(_stemmingHoog),
                        ),
                        const SizedBox(height: 12),
                        
                        // Gesplitste stemming toggle
                        if (_gesplitsteStemming)
                          _buildStemmingCard(
                            title: 'Laagste stemming vandaag',
                            value: _stemmingLaag,
                            onChanged: (value) => setState(() => _stemmingLaag = value),
                            color: _getStemmingKleur(_stemmingLaag),
                          ),
                        
                        // Toggle gesplitste stemming
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Stemming veranderde vandaag',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Switch(
                                value: _gesplitsteStemming,
                                onChanged: (value) => setState(() => _gesplitsteStemming = value),
                                activeColor: AppTheme.primaryTeal,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Ontstemde manie
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
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.warning_amber, color: Colors.red, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ontstemde manie',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'Manisch maar ongelukkig/irritant',
                                      style: TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Checkbox(
                                value: _ontstemdeManie,
                                onChanged: (value) => setState(() => _ontstemdeManie = value ?? false),
                                activeColor: Colors.red,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Uren slaap - Time picker
                        _buildTimePickerCard(
                          title: 'Uren slaap vannacht',
                          subtitle: 'Dutjes overdag tellen niet mee',
                          value: _urenSlaap,
                          onChanged: (value) => setState(() => _urenSlaap = value),
                          icon: Icons.bedtime,
                          iconColor: Colors.indigo,
                        ),
                        const SizedBox(height: 12),
                        
                        // Gewicht
                        _buildNumberCard(
                          title: 'Gewicht (kg)',
                          subtitle: 'Optioneel',
                          value: _gewicht,
                          onChanged: (value) => setState(() => _gewicht = value),
                          min: 0,
                          max: 200,
                          step: 0.1,
                          icon: Icons.monitor_weight,
                          iconColor: Colors.blue,
                        ),
                        const SizedBox(height: 12),
                        
                        // Stemmingsomslagen
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
                                      'Aantal plotselinge grote veranderingen (30+ punten)',
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

  Widget _buildStemmingCard({
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  value.round().toString(),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  _getStemmingLabel(value),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: Colors.grey[200],
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.2),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: onChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('😞 0', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                Text('50', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                Text('100 😄', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberCard({
    required String title,
    required String subtitle,
    required double value,
    required ValueChanged<double> onChanged,
    required double min,
    required double max,
    required double step,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
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
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCounterBtn(Icons.remove, value > min ? () => onChanged((value - step).clamp(min, max)) : null),
              Container(
                width: 50,
                alignment: Alignment.center,
                child: Text(
                  value.toStringAsFixed(step < 1 ? 1 : 0),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              _buildCounterBtn(Icons.add, value < max ? () => onChanged((value + step).clamp(min, max)) : null, isPrimary: true),
            ],
          ),
        ],
      ),
    );
  }

  // Time picker for sleep time
  Widget _buildTimePickerCard({
    required String title,
    required String subtitle,
    required double value,
    required ValueChanged<double> onChanged,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
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
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final hours = value.floor();
              final minutes = ((value - hours) * 60).round();
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: hours, minute: minutes),
                builder: (context, child) {
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                    child: child!,
                  );
                },
              );
              if (time != null) {
                onChanged(time.hour + time.minute / 60.0);
              }
            },
            child: Text(
              '${value.floor()}:${((value - value.floor()) * 60).round().toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

