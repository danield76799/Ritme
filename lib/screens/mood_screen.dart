import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../main.dart';

const Color primaryTeal = Color(0xFF4FB2C1);
const Color textCharcoal = Color(0xFF333333);
const Color backgroundColor = Color(0xFFFAFAFA);

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  double _stemmingWaarde = 0;
  bool _ontstemdeManie = false;

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
    final log = await db.getDailyLog(_todayDate);
    if (log != null && mounted) {
      setState(() {
        _stemmingWaarde = (log['stemming_avond'] ?? log['stemming_ochtend'] ?? 0).toDouble();
        _ontstemdeManie = (log['ontstemde_manie'] ?? false) == 1;
      });
    }
    setState(() => _isLoading = false);
  }

  String _haalBeschrijvingOp(double waarde) {
    int w = waarde.round();
    switch (w) {
      case 5:
        return 'In de war, psychotisch, opname noodzakelijk.';
      case 4:
        return 'Fors manisch, tegen de grens van een psychose.';
      case 3:
        return 'Druk, veel dingen tegelijk doen, veel praten, kort slapen.';
      case 2:
        return 'Gehele dag te druk, minder slaap nodig.';
      case 1:
        return 'Momenten op de dag drukker, actiever dan gewoonlijk.';
      case 0:
        return 'Stabiel.';
      case -1:
        return 'Dingen met tegenzin doen, stemming licht gedaald.';
      case -2:
        return 'Sommige dingen blijven liggen, stemming licht somber.';
      case -3:
        return 'Stemming gehele dag somber.';
      case -4:
        return 'Alles kost veel moeite, neiging om hele dag op bed te liggen.';
      case -5:
        return 'Niet in staat voor zichzelf te zorgen, opname noodzakelijk.';
      default:
        return '';
    }
  }

  Color _haalKleurOp(double waarde) {
    if (waarde > 0) return Colors.orange;
    if (waarde < 0) return Colors.blue;
    return Colors.green;
  }

  Future<void> _opslaan() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final log = {
      'date': _todayDate,
      'stemming_avond': _stemmingWaarde.round(),
      'ontstemde_manie': _ontstemdeManie ? 1 : 0,
    };

    await db.upsertDailyLog(log);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stemming opgeslagen!'),
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

    Color kleur = _haalKleurOp(_stemmingWaarde);
    String beschrijving = _haalBeschrijvingOp(_stemmingWaarde);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryTeal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Stemming',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with logo
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/logo.jpg',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Mood slider card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Hoe voel je je vandaag?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textCharcoal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      beschrijving,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Value display
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: kleur.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: kleur, width: 3),
                      ),
                      child: Center(
                        child: Text(
                          _stemmingWaarde.round().toString(),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: kleur,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mood slider
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: kleur,
                        inactiveTrackColor: kleur.withValues(alpha: 0.2),
                        thumbColor: kleur,
                        overlayColor: kleur.withValues(alpha: 0.2),
                        trackHeight: 8,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 14,
                        ),
                      ),
                      child: Slider(
                        value: _stemmingWaarde,
                        min: -5,
                        max: 5,
                        divisions: 10,
                        onChanged: (value) {
                          setState(() {
                            _stemmingWaarde = value;
                          });
                        },
                      ),
                    ),

                    // Scale labels
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Somber',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Manisch',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Ontstemde manie checkbox
                    CheckboxListTile(
                      value: _ontstemdeManie,
                      onChanged: (value) {
                        setState(() {
                          _ontstemdeManie = value ?? false;
                        });
                      },
                      title: const Text(
                        'Ontstemde manie',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: const Text(
                        'Manische episode met depressieve kenmerken',
                        style: TextStyle(fontSize: 12),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: primaryTeal,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _opslaan,
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
                    backgroundColor: primaryTeal,
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
}
