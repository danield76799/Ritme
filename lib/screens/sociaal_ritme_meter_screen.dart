import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../service_locator.dart';
import '../widgets/datum_navigator.dart';

class SociaalRitmeMeterScreen extends StatefulWidget {
  const SociaalRitmeMeterScreen({super.key});

  @override
  State<SociaalRitmeMeterScreen> createState() => _SociaalRitmeMeterScreenState();
}

class _SociaalRitmeMeterScreenState extends State<SociaalRitmeMeterScreen> {
  DateTime _geselecteerdeDatum = DateTime.now();
  bool _isLoading = true;

  // SRM velden
  TimeOfDay? _opstaanTijd;
  TimeOfDay? _eersteContactTijd;
  int _eersteContactPersonen = 0;
  TimeOfDay? _werkBeginTijd;
  TimeOfDay? _avondetenTijd;
  TimeOfDay? _naarBedTijd;
  double _slaapUren = 7.0;
  bool _ontstemdeManie = false;
  double _stemmingWaarde = 0.0; // -5 tot +5
  int _stemmingsOmslagen = 0;
  String _medicatie = '';
  String _alcoholDrugs = '';
  String _opmerkingen = '';
  String _gebeurtenissen = '';

  // SRT Score
  int _srtScore = 0;

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
      _opstaanTijd = _parseTime(log['opstaan']);
      _eersteContactTijd = _parseTime(log['eerste_contact']);
      _eersteContactPersonen = log['eerste_contact_p'] ?? 0;
      _werkBeginTijd = _parseTime(log['werk_begin']);
      _avondetenTijd = _parseTime(log['avondeten']);
      _naarBedTijd = _parseTime(log['naar_bed']);
      _slaapUren = log['slaap_uren']?.toDouble() ?? 7.0;
      _ontstemdeManie = log['ontstemde_manie'] == 1;
      _stemmingWaarde = log['stemming']?.toDouble() ?? 0.0;
      _stemmingsOmslagen = log['stemmingsomslagen'] ?? 0;
      _medicatie = log['medicatie'] ?? '';
      _alcoholDrugs = log['alcohol_drugs'] ?? '';
      _opmerkingen = log['opmerkingen'] ?? '';
      _gebeurtenissen = log['gebeurtenissen'] ?? '';
    }

    _berekenSRTScore();

    if (mounted) setState(() => _isLoading = false);
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return null;
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '--:--';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _berekenSRTScore() {
    int score = 0;
    final now = TimeOfDay.now();

    // Opstaan (doel: 08:00)
    if (_opstaanTijd != null) {
      final doel = const TimeOfDay(hour: 8, minute: 0);
      if (_binnenTolerantie(_opstaanTijd!, doel, 45)) score++;
    }

    // Eerste contact (doel: 10:00)
    if (_eersteContactTijd != null) {
      final doel = const TimeOfDay(hour: 10, minute: 0);
      if (_binnenTolerantie(_eersteContactTijd!, doel, 45)) score++;
    }

    // Werk begin (doel: 13:30)
    if (_werkBeginTijd != null) {
      final doel = const TimeOfDay(hour: 13, minute: 30);
      if (_binnenTolerantie(_werkBeginTijd!, doel, 45)) score++;
    }

    // Avondeten (doel: 18:30)
    if (_avondetenTijd != null) {
      final doel = const TimeOfDay(hour: 18, minute: 30);
      if (_binnenTolerantie(_avondetenTijd!, doel, 45)) score++;
    }

    // Naar bed (doel: 23:00)
    if (_naarBedTijd != null) {
      final doel = const TimeOfDay(hour: 23, minute: 0);
      if (_binnenTolerantie(_naarBedTijd!, doel, 45)) score++;
    }

    setState(() => _srtScore = score);
  }

  bool _binnenTolerantie(TimeOfDay actual, TimeOfDay doel, int minuten) {
    final actualMinuten = actual.hour * 60 + actual.minute;
    final doelMinuten = doel.hour * 60 + doel.minute;
    return (actualMinuten - doelMinuten).abs() <= minuten;
  }

  Future<void> _selectTime(BuildContext context, String label, TimeOfDay? current, Function(TimeOfDay) onSelect) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryTeal,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onSelect(picked);
      _berekenSRTScore();
    }
  }

  Future<void> _opslaan() async {
    await db.upsertDailyLog({
      'date': _formattedDate,
      'opstaan': _formatTime(_opstaanTijd),
      'eerste_contact': _formatTime(_eersteContactTijd),
      'eerste_contact_p': _eersteContactPersonen,
      'werk_begin': _formatTime(_werkBeginTijd),
      'avondeten': _formatTime(_avondetenTijd),
      'naar_bed': _formatTime(_naarBedTijd),
      'slaap_uren': _slaapUren,
      'ontstemde_manie': _ontstemdeManie ? 1 : 0,
      'stemming': _stemmingWaarde,
      'stemmingsomslagen': _stemmingsOmslagen,
      'medicatie': _medicatie,
      'alcohol_drugs': _alcoholDrugs,
      'opmerkingen': _opmerkingen,
      'gebeurtenissen': _gebeurtenissen,
      'srt_score': _srtScore,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SRM opgeslagen! SRT Score: $_srtScore/5'),
          backgroundColor: AppTheme.primaryTeal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onDatumVeranderd(DateTime nieuweDatum) {
    setState(() => _geselecteerdeDatum = nieuweDatum);
    _loadData();
  }

  String _getStemmingLabel(double waarde) {
    if (waarde <= -4) return 'Ernstig depressief';
    if (waarde <= -3) return 'Matig depressief';
    if (waarde <= -2) return 'Licht depressief';
    if (waarde <= -1) return 'Neerslachtig';
    if (waarde == 0) return 'Stabiel';
    if (waarde <= 1) return 'Opgewekt';
    if (waarde <= 2) return 'Licht manisch';
    if (waarde <= 3) return 'Matig manisch';
    if (waarde <= 4) return 'Fors manisch';
    return 'Psychotisch';
  }

  Color _getStemmingKleur(double waarde) {
    if (waarde <= -2) return Colors.blue[700]!;
    if (waarde <= -1) return Colors.blue[400]!;
    if (waarde == 0) return Colors.green[500]!;
    if (waarde <= 2) return Colors.orange[400]!;
    return Colors.red[400]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        title: const Text(
          'Sociaal Ritme Meter',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _opslaan,
            tooltip: 'Opslaan',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Datum navigator
                    DatumNavigator(
                      geselecteerdeDatum: _geselecteerdeDatum,
                      onDatumVeranderd: _onDatumVeranderd,
                    ),
                    const SizedBox(height: 20),

                    // SRT Score banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryTeal, AppTheme.primaryTeal.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryTeal.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'SRT Score',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$_srtScore',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                '/5',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _srtScore >= 4 ? 'Uitstekend ritme!' : 
                            _srtScore >= 3 ? 'Goed ritme' : 
                            _srtScore >= 2 ? 'Matig ritme' : 'Aandacht nodig',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Tijdsactiviteiten sectie
                    _buildSectieTitel('Dagelijkse Activiteiten'),
                    const SizedBox(height: 12),

                    _buildTijdKaart(
                      'Opstaan',
                      Icons.wb_sunny_outlined,
                      _opstaanTijd,
                      (tijd) => setState(() => _opstaanTijd = tijd),
                      doel: '08:00',
                    ),
                    _buildTijdKaart(
                      'Eerste contact',
                      Icons.people_outline,
                      _eersteContactTijd,
                      (tijd) => setState(() => _eersteContactTijd = tijd),
                      doel: '10:00',
                    ),
                    _buildTijdKaart(
                      'Begin werk/school',
                      Icons.work_outline,
                      _werkBeginTijd,
                      (tijd) => setState(() => _werkBeginTijd = tijd),
                      doel: '13:30',
                    ),
                    _buildTijdKaart(
                      'Avondeten',
                      Icons.restaurant_outlined,
                      _avondetenTijd,
                      (tijd) => setState(() => _avondetenTijd = tijd),
                      doel: '18:30',
                    ),
                    _buildTijdKaart(
                      'Naar bed',
                      Icons.bedtime_outlined,
                      _naarBedTijd,
                      (tijd) => setState(() => _naarBedTijd = tijd),
                      doel: '23:00',
                    ),

                    const SizedBox(height: 24),

                    // Slaap sectie
                    _buildSectieTitel('Slaap'),
                    const SizedBox(height: 12),
                    _buildSlaapKaart(),

                    const SizedBox(height: 24),

                    // Stemming sectie
                    _buildSectieTitel('Stemming'),
                    const SizedBox(height: 12),
                    _buildStemmingKaart(),

                    const SizedBox(height: 24),

                    // Medicatie sectie
                    _buildSectieTitel('Medicatie & Gebruik'),
                    const SizedBox(height: 12),
                    _buildMedicatieKaart(),

                    const SizedBox(height: 24),

                    // Gebeurtenissen sectie
                    _buildSectieTitel('Gebeurtenissen & Opmerkingen'),
                    const SizedBox(height: 12),
                    _buildGebeurtenissenKaart(),

                    const SizedBox(height: 32),

                    // Opslaan knop
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _opslaan,
                        icon: const Icon(Icons.save),
                        label: const Text(
                          'Opslaan',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectieTitel(String titel) {
    return Row(
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
          titel,
          style: TextStyle(
            color: AppTheme.textCharcoal,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTijdKaart(
    String label,
    IconData icon,
    TimeOfDay? tijd,
    Function(TimeOfDay) onSelect, {
    required String doel,
  }) {
    final isBinnenDoel = tijd != null && _binnenTolerantie(
      tijd, 
      _parseTime(doel)!, 
      45
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isBinnenDoel 
                ? Colors.green.withOpacity(0.1) 
                : AppTheme.primaryTeal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isBinnenDoel ? Colors.green : AppTheme.primaryTeal,
          ),
        ),
        title: Text(label),
        subtitle: Text('Doel: $doel'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tijd != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isBinnenDoel 
                      ? Colors.green.withOpacity(0.1) 
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatTime(tijd),
                  style: TextStyle(
                    color: isBinnenDoel ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.access_time),
              onPressed: () => _selectTime(context, label, tijd, onSelect),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlaapKaart() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.nightlight_round, color: AppTheme.primaryTeal),
                const SizedBox(width: 8),
                const Text(
                  'Aantal uren slaap',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Slider(
              value: _slaapUren,
              min: 0,
              max: 12,
              divisions: 24,
              label: '${_slaapUren.toStringAsFixed(1)} uur',
              activeColor: AppTheme.primaryTeal,
              onChanged: (value) => setState(() => _slaapUren = value),
            ),
            Center(
              child: Text(
                '${_slaapUren.toStringAsFixed(1)} uur',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTeal,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _ontstemdeManie,
                  activeColor: AppTheme.primaryTeal,
                  onChanged: (value) => setState(() => _ontstemdeManie = value ?? false),
                ),
                const Expanded(
                  child: Text(
                    'Ontstemde manie (ongelukkig ondanks manie)',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStemmingKaart() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sentiment_satisfied_alt, color: _getStemmingKleur(_stemmingWaarde)),
                const SizedBox(width: 8),
                Text(
                  'Stemming: ${_getStemmingLabel(_stemmingWaarde)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getStemmingKleur(_stemmingWaarde),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Slider(
              value: _stemmingWaarde,
              min: -5,
              max: 5,
              divisions: 10,
              label: _stemmingWaarde.toStringAsFixed(0),
              activeColor: _getStemmingKleur(_stemmingWaarde),
              onChanged: (value) => setState(() => _stemmingWaarde = value),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Depressief', style: TextStyle(color: Colors.blue[700], fontSize: 12)),
                Text('Stabiel', style: TextStyle(color: Colors.green[500], fontSize: 12)),
                Text('Manisch', style: TextStyle(color: Colors.red[400], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Stemmingsschommelingen: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => setState(() => _stemmingsOmslagen = (_stemmingsOmslagen - 1).clamp(0, 10)),
                ),
                Text(
                  '$_stemmingsOmslagen',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _stemmingsOmslagen = (_stemmingsOmslagen + 1).clamp(0, 10)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicatieKaart() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medication_outlined, color: AppTheme.primaryTeal),
                const SizedBox(width: 8),
                const Text(
                  'Medicatie',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: _medicatie),
              onChanged: (value) => _medicatie = value,
              decoration: InputDecoration(
                hintText: 'Naam, dosering, aantal tabletten...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.primaryTeal),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.local_bar_outlined, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Alcohol / Drugs',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: _alcoholDrugs),
              onChanged: (value) => _alcoholDrugs = value,
              decoration: InputDecoration(
                hintText: 'Gebruik vandaag...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.primaryTeal),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGebeurtenissenKaart() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_note, color: AppTheme.primaryTeal),
                const SizedBox(width: 8),
                const Text(
                  'Gebeurtenissen',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: _gebeurtenissen),
              onChanged: (value) => _gebeurtenissen = value,
              decoration: InputDecoration(
                hintText: 'Belangrijke gebeurtenissen vandaag...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.primaryTeal),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.notes, color: AppTheme.primaryTeal),
                const SizedBox(width: 8),
                const Text(
                  'Opmerkingen',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: _opmerkingen),
              onChanged: (value) => _opmerkingen = value,
              decoration: InputDecoration(
                hintText: 'Overige opmerkingen...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.primaryTeal),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
