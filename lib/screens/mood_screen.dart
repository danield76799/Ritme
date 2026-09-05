import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../service_locator.dart';
import '../utils/bool_helper.dart';
import '../widgets/datum_navigator.dart';
import '../generated/l10n/app_localizations.dart';
import 'mood_assessment_screen.dart';

class MoodScreen extends StatefulWidget {
  /// Optionele prefill-waarde voor stemming_hoog (vanuit de
  /// vragenlijst-flow).
  final double? prefillStemmingHoog;

  /// Of de gesplitste stemming aanbevolen wordt (vanuit de vragenlijst-flow).
  final bool prefillGesplitst;

  const MoodScreen({
    super.key,
    this.prefillStemmingHoog,
    this.prefillGesplitst = false,
  });

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {

  DateTime _geselecteerdeDatum = DateTime.now();
  double _stemmingHoog = 0.0;  // Hoogste stemming niveau (-5 tot +5)
  double _stemmingLaag = 0.0;  // Laagste stemming niveau (-5 tot +5)
  bool _gesplitsteStemming = false; // Of er een gesplitste stemming is
  int _stemmingsOmslagen = 0;
  bool _ontstemdeManie = false;
  // double _urenSlaap removed - now calculated from sleep tracking
  double _gewicht = 0.0;
  bool _daglicht = false; // Buiten geweest vandaag
  int _socialeContacten = 0; // Aantal sociale contacten
  int _alcoholMiddelen = 0;  // 0=nee, 1=ja
  bool _menstruatie = false;
  bool _showMenstruatie = true;  // Uit settings
  bool _isLoading = true;

  String get _formattedDate {
    return '${_geselecteerdeDatum.year}-${_geselecteerdeDatum.month.toString().padLeft(2, '0')}-${_geselecteerdeDatum.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    // Prefill uit vragenlijst heeft voorrang boven opgeslagen data.
    if (widget.prefillStemmingHoog != null) {
      _stemmingHoog = widget.prefillStemmingHoog!.clamp(-4.0, 4.0);
      _stemmingLaag = _stemmingHoog;
      _gesplitsteStemming = widget.prefillGesplitst;
      _isLoading = false;
    } else {
      _loadData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant MoodScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload settings when widget is updated
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      await ensureInitialized();
      final settings = await db.getSettings();
      final showMenstruatie = BoolHelper.parse(settings?['show_menstruatie'], defaultValue: true);
      
      if (mounted) {
        setState(() {
          _showMenstruatie = showMenstruatie;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await ensureInitialized();
      // Load display preferences
      final settings = await db.getSettings();
      final showMenstruatie = BoolHelper.parse(settings?['show_menstruatie'], defaultValue: true);

      final log = await db.getDailyLog(_formattedDate);
      if (!mounted) return;
      if (log != null) {
        // SRM Methode: stemming -5 tot +5 (gesplitst mogelijk)
        final dynamic rawStemmingHoog = log['stemming_hoog'];
        final dynamic rawStemmingLaag = log['stemming_laag'];
        final dynamic rawGesplitst = log['gesplitste_stemming'];
        
        // Converteer oude 0-100 waarden naar nieuwe -5..+5 schaal
        // new_value = (old_value - 50) / 10
        if (rawStemmingHoog is num) {
          _stemmingHoog = rawStemmingHoog.toDouble();
          // Als waarde > 5, dan is het een oude 0-100 waarde
          if (_stemmingHoog > 5 || _stemmingHoog < -5) {
            _stemmingHoog = (_stemmingHoog - 50) / 10;
          }
        } else if (rawStemmingHoog is String) {
          _stemmingHoog = double.tryParse(rawStemmingHoog) ?? 0.0;
          if (_stemmingHoog > 5 || _stemmingHoog < -5) {
            _stemmingHoog = (_stemmingHoog - 50) / 10;
          }
        } else {
          _stemmingHoog = 0.0;
        }
        
        if (rawGesplitst == 1 || rawGesplitst == '1' || rawGesplitst == true) {
          if (rawStemmingLaag is num) {
            _stemmingLaag = rawStemmingLaag.toDouble();
            if (_stemmingLaag > 5 || _stemmingLaag < -5) {
              _stemmingLaag = (_stemmingLaag - 50) / 10;
            }
          } else if (rawStemmingLaag is String) {
            _stemmingLaag = double.tryParse(rawStemmingLaag) ?? _stemmingHoog;
            if (_stemmingLaag > 5 || _stemmingLaag < -5) {
              _stemmingLaag = (_stemmingLaag - 50) / 10;
            }
          } else {
            _stemmingLaag = _stemmingHoog;
          }
          _gesplitsteStemming = true;
        } else {
          _stemmingLaag = _stemmingHoog;
          _gesplitsteStemming = false;
        }
        
        _stemmingsOmslagen = log['stemmingsomslagen'] is int ? log['stemmingsomslagen'] : int.tryParse(log['stemmingsomslagen']?.toString() ?? '0') ?? 0;
        _ontstemdeManie = log['ontstemde_manie'] == true || log['ontstemde_manie'] == 1 || log['ontstemde_manie'] == '1';
        _daglicht = log['daglicht'] == 1 || log['daglicht'] == '1' || log['daglicht'] == true;
        _socialeContacten = log['sociale_contacten'] is int ? log['sociale_contacten'] : int.tryParse(log['sociale_contacten']?.toString() ?? '0') ?? 0;
        _alcoholMiddelen = log['alcohol_middelen'] is int ? log['alcohol_middelen'] : int.tryParse(log['alcohol_middelen']?.toString() ?? '0') ?? 0;
        _menstruatie = log['menstruatie'] == 1 || log['menstruatie'] == '1' || log['menstruatie'] == true;
        _showMenstruatie = showMenstruatie;
        // _urenSlaap removed - now calculated from sleep tracking
      } else {
        _stemmingHoog = 0.0;
        _stemmingLaag = 0.0;
        _gesplitsteStemming = false;
        _stemmingsOmslagen = 0;
        _ontstemdeManie = false;
        _daglicht = false;
        _socialeContacten = 0;
        _alcoholMiddelen = 0;
        _menstruatie = false;
        _showMenstruatie = showMenstruatie;
        // _urenSlaap removed - now calculated from sleep tracking
      }
    } catch (e, stack) {
      debugPrint('MoodScreen _loadData error: $e');
      debugPrint('Stack: $stack');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _onDatumVeranderd(DateTime nieuweDatum) {
    setState(() => _geselecteerdeDatum = nieuweDatum);
    // Use a microtask to ensure setState completes before loading
    Future.microtask(() => _loadData());
  }

  Future<void> _opslaan() async {
    try {
      await ensureInitialized();
      
      await db.upsertDailyLog({
        'date': _formattedDate,
        'stemming_hoog': _stemmingHoog,
        'stemming_laag': _gesplitsteStemming ? _stemmingLaag : _stemmingHoog,
        'gesplitste_stemming': _gesplitsteStemming,
        'stemmingsomslagen': _stemmingsOmslagen,
        'ontstemde_manie': _ontstemdeManie,
        'daglicht': _daglicht ? 1 : 0,
        'sociale_contacten': _socialeContacten,
        'alcohol_middelen': _alcoholMiddelen,
        'menstruatie': _menstruatie ? 1 : 0,
        // 'uren_slaap' removed - now calculated from sleep tracking
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).opgeslagen),
            backgroundColor: Theme.of(context).colorScheme.primary,
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
            content: Text(AppLocalizations.of(context).foutOpslaan2(e)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  String _getStemmingLabel(BuildContext context, double waarde) {
    final l10n = AppLocalizations.of(context);
    if (waarde <= -5) return l10n.uiterstDepressief;
    if (waarde <= -4) return l10n.ernstigDepressief;
    if (waarde <= -3) return l10n.matigDepressief;
    if (waarde <= -2) return l10n.lichtDepressief;
    if (waarde <= -1) return l10n.somber;
    if (waarde == 0) return l10n.stabielNeutraal;
    if (waarde <= 1) return l10n.lichtManisch;
    if (waarde <= 2) return l10n.matigManisch;
    if (waarde <= 3) return l10n.drukActief;
    if (waarde <= 4) return l10n.ernstigManisch;
    return l10n.uiterstManisch;
  }

  Color _getStemmingKleur(double waarde) {
    if (waarde <= -4) return const Color(0xFF616161);   // Uiterst depressief
    if (waarde <= -3) return const Color(0xFF424242);   // Ernstig depressief
    if (waarde <= -2) return const Color(0xFF42A5F5);   // Matig depressief
    if (waarde <= -1) return const Color(0xFF90CAF9);   // Licht depressief
    if (waarde == 0) return const Color(0xFF66BB6A);    // Neutraal
    if (waarde <= 1) return const Color(0xFFFDD835);    // Licht manisch
    if (waarde <= 2) return const Color(0xFFFF9800);    // Matig manisch
    if (waarde <= 3) return const Color(0xFFF57C00);    // Druk / Actief
    if (waarde <= 4) return const Color(0xFFEF5350);    // Ernstig manisch
    return const Color(0xFFE53935);                       // Uiterst manisch
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
        appBar: AppBar(title: Text(AppLocalizations.of(context).stemmingFout)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 64),
              SizedBox(height: 16),
              Text(AppLocalizations.of(context).fout(e), style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildMoodScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).lifeChart,
          style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onPrimary),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context).stemmingsCheckOpenKnop,
            icon: const Icon(Icons.quiz_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MoodAssessmentScreen(),
                ),
              );
            },
          ),
          TextButton(
            onPressed: _opslaan,
            child: Text(AppLocalizations.of(context).opslaan, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : Column(
              children: [
                Container(color: Theme.of(context).cardColor, child: DatumNavigator(geselecteerdeDatum: _geselecteerdeDatum, onDatumVeranderd: _onDatumVeranderd)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hoogste stemming (-5 tot +5)
                        _buildStemmingCard(
                          title: AppLocalizations.of(context).hoogsteStemmingVandaag,
                          value: _stemmingHoog,
                          onChanged: (value) => setState(() => _stemmingHoog = value),
                          color: _getStemmingKleur(_stemmingHoog),
                        ),
                        SizedBox(height: 12),
                        
                        // Gesplitste stemming toggle
                        if (_gesplitsteStemming)
                          _buildStemmingCard(
                            title: AppLocalizations.of(context).laagsteStemmingVandaag,
                            value: _stemmingLaag,
                            onChanged: (value) => setState(() => _stemmingLaag = value),
                            color: _getStemmingKleur(_stemmingLaag),
                          ),
                        
                        // Toggle gesplitste stemming
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context).stemmingVeranderdeVandaag,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal),
                                ),
                              ),
                              Switch(
                                value: _gesplitsteStemming,
                                onChanged: (value) => setState(() => _gesplitsteStemming = value),
                                activeColor: Colors.blue,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        
                        // Ontstemde manie
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.warning_amber, color: Colors.blue, size: 20),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLocalizations.of(context).ontstemdeManie,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'Manisch maar ongelukkig/irritant',
                                      style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
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
                        SizedBox(height: 12),
                        
                        // Stemmingsomslagen
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.swap_vert, color: Colors.blue, size: 20),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLocalizations.of(context).stemmingsomslagen,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal),
                                    ),
                                    Text(
                                      'Aantal plotselinge grote veranderingen (30+ punten)',
                                      style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildCounterBtn(Icons.remove, _stemmingsOmslagen > 0 ? () => _veranderOmslagen(-1) : null),
                                  Container(width: 36, alignment: Alignment.center, child: Text(_stemmingsOmslagen.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal))),
                                  _buildCounterBtn(Icons.add, () => _veranderOmslagen(1), isPrimary: true),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        
                        // Daglicht
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.wb_sunny, color: Colors.amber, size: 20),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLocalizations.of(context).daglicht,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      AppLocalizations.of(context).vandaagBuitenGeweest,
                                      style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.black),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _daglicht,
                                onChanged: (value) => setState(() => _daglicht = value),
                                activeColor: AppTheme.primaryTeal,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        
                        // Sociale contacten
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.people, color: Colors.blue, size: 20),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLocalizations.of(context).socialeContacten,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal),
                                    ),
                                    Text(
                                      AppLocalizations.of(context).aantalSocialeInteractiesVandaag,
                                      style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildCounterBtn(Icons.remove, _socialeContacten > 0 ? () => setState(() => _socialeContacten--) : null),
                                  Container(width: 36, alignment: Alignment.center, child: Text(_socialeContacten.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal))),
                                  _buildCounterBtn(Icons.add, () => setState(() => _socialeContacten++), isPrimary: true),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),

                        // Alcohol / middelen
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _alcoholMiddelen == 1 ? Colors.red.shade50 : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _alcoholMiddelen == 1 ? Colors.red.shade300 : Theme.of(context).dividerColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.wine_bar, color: Colors.red, size: 20),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Alcohol / middelen',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal),
                                ),
                              ),
                              Switch(
                                value: _alcoholMiddelen == 1,
                                onChanged: (value) => setState(() => _alcoholMiddelen = value ? 1 : 0),
                                activeColor: Colors.red,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),

                        // Menstruatie
                        if (_showMenstruatie)
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _menstruatie ? Colors.pink.shade50 : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _menstruatie ? Colors.pink.shade300 : Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.pink.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.bloodtype_outlined, color: Colors.pink, size: 20),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context).menstruatie,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal),
                                ),
                              ),
                              Switch(
                                value: _menstruatie,
                                onChanged: (value) => setState(() => _menstruatie = value),
                                activeColor: Colors.pink,
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal),
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
                  _getStemmingLabel(context, value),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: Theme.of(context).dividerColor,
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.2),
              trackHeight: 6,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value,
              min: -5,
              max: 5,
              divisions: 10,
              onChanged: onChanged,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.of(context).schaalMin5, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal)),
                Text(AppLocalizations.of(context).schaalNul, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal)),
                Text(AppLocalizations.of(context).schaalPlus5, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal)),
              ],
            ),
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
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
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
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal),
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
            color: isPrimary ? AppTheme.primaryTeal : Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: isPrimary ? Colors.white : AppTheme.textCharcoal),
        ),
      ),
    );
  }
}

