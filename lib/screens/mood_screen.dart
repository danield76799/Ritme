import 'package:flutter/material.dart';
import '../database/database_helper.dart';

const Color medicalTeal = Color(0xFF4FB2C1);
const Color medicalTealDark = Color(0xFF3A9AA8);

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  final _db = DatabaseHelper.instance;
  bool _isLoading = true;
  bool _isSaving = false;

  double _moodScore = 0;
  double _sleepQuality = 5;
  double _energyLevel = 5;
  double _irritability = 5;
  final _notesController = TextEditingController();

  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    final log = await _db.getDailyLog(_todayDate);
    if (log != null && mounted) {
      setState(() {
        _moodScore = (log['mood_score'] ?? 0).toDouble();
        _sleepQuality = (log['sleep_quality'] ?? 5).toDouble();
        _energyLevel = (log['energy_level'] ?? 5).toDouble();
        _irritability = (log['irritability'] ?? 5).toDouble();
        _notesController.text = log['notes'] ?? '';
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final log = {
      'date': _todayDate,
      'mood_score': _moodScore.round(),
      'sleep_quality': _sleepQuality.round(),
      'energy_level': _energyLevel.round(),
      'irritability': _irritability.round(),
      'notes': _notesController.text.trim(),
    };

    await _db.upsertDailyLog(log);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stemming opgeslagen!'),
          backgroundColor: medicalTeal,
        ),
      );
      Navigator.pop(context);
    }
  }

  String _moodLabel(double value) {
    if (value <= -4) return 'Zeer somber';
    if (value <= -2) return 'Somber';
    if (value < 0) return 'Eneergieig';
    if (value == 0) return 'Neutraal';
    if (value <= 2) return 'Goed';
    if (value <= 4) return 'Blij';
    return 'Zeer blij';
  }

  Color _moodColor(double value) {
    if (value < -2) return Colors.redAccent;
    if (value < 0) return Colors.orangeAccent;
    if (value == 0) return Colors.grey;
    if (value <= 2) return Colors.lightGreen;
    return Colors.green;
  }

  Widget _buildSliderSection({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    String? label,
    Color? activeColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        if (label != null)
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: activeColor ?? medicalTeal,
            ),
          ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: activeColor ?? medicalTeal,
          inactiveColor: medicalTeal.withValues(alpha: 0.2),
          label: value.round().toString(),
          onChanged: onChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(min.toInt().toString(), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text(max.toInt().toString(), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: medicalTeal)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: medicalTeal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Dagelijkse Check-in',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
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
                    const Text(
                      'Hoe voel je je vandaag?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSliderSection(
                      title: 'Stemming',
                      value: _moodScore,
                      min: -5,
                      max: 5,
                      divisions: 10,
                      label: _moodLabel(_moodScore),
                      activeColor: _moodColor(_moodScore),
                      onChanged: (v) => setState(() => _moodScore = v),
                    ),
                    _buildSliderSection(
                      title: 'Slaapkwaliteit',
                      value: _sleepQuality,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '${_sleepQuality.round()}/10',
                      onChanged: (v) => setState(() => _sleepQuality = v),
                    ),
                    _buildSliderSection(
                      title: 'Energie niveau',
                      value: _energyLevel,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '${_energyLevel.round()}/10',
                      onChanged: (v) => setState(() => _energyLevel = v),
                    ),
                    _buildSliderSection(
                      title: 'Prikkelbaarheid',
                      value: _irritability,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '${_irritability.round()}/10',
                      activeColor: _irritability > 6 ? Colors.orange : medicalTeal,
                      onChanged: (v) => setState(() => _irritability = v),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Notities (optioneel)',
                        hintText: 'Iets wat je wilt onthouden...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: medicalTeal, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Opslaan...' : 'Opslaan'),
                  style: FilledButton.styleFrom(
                    backgroundColor: medicalTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}
