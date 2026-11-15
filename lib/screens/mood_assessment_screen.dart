import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../generated/l10n/app_localizations.dart';
import '../service_locator.dart';
import '../utils/mood_assessment_scorer.dart';
import '../utils/bipolar_tag_l10n.dart';
import '../theme/app_theme.dart';

/// 5-staps vragenlijst die een stemming-score berekent op basis van gewogen
/// antwoorden, de stemming direct wegschrijft naar de daily log, en de
/// bipolaire analyse-tags toont.
///
/// Vragenlijst:
///  1. Hoe is uw stemming vandaag?            (-4..+4)
/// 2. Hoe is uw energie? Slider 0..100       (depressief → manisch)
///  3. Hoe is uw energie niveau?              (-3..+3)
///  4. Slaapbehoefte                          (-4..+4)
///  5. Belangrijke gebeurtenis                (-4..+4)
class MoodAssessmentScreen extends StatefulWidget {
  /// Optionele close-callback. De dashboard-tegel opent dit scherm via
  /// OpenContainer (animations-package) en geeft daar de closeContainer-
  /// action door; via gewone routes (bv. /mood, drawer) blijft dit null
  /// en wordt Navigator.pop gebruikt.
  const MoodAssessmentScreen({super.key, this.onClose});

  /// Sluit het scherm; `saved=true` als de data is opgeslagen.
  final void Function(bool saved)? onClose;

  @override
  State<MoodAssessmentScreen> createState() => _MoodAssessmentScreenState();
}

class _MoodAssessmentScreenState extends State<MoodAssessmentScreen> {
  int _step = 0; // 0..4 = vraag 1..5, 5 = resultaat
  MoodScoreResult? _result;
  double? _q1; // stemming -4..+4
  double _q2Slider = 50; // 0..100 (depressief=0, manisch=100)
  double? _q3; // energie detail -3..+3
  double? _q4; // slaapbehoefte -4..+4
  double? _q5; // gebeurtenis -4..+4

  int get _resultStep => 5;

  @override
  void initState() {
    super.initState();
    _checkAlIngevuld();
  }

  String _datumLabel(BuildContext context) {
    final now = DateTime.now();
    final d = _geselecteerdeDatum;
    final fmt = DateFormat('d MMM', Localizations.localeOf(context).toString());
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return AppLocalizations.of(context).vandaag;
    }
    if (d.year == now.year && d.month == now.month && d.day == now.day - 1) {
      return AppLocalizations.of(context).gisteren;
    }
    return fmt.format(d);
  }

  /// Geselecteerde datum voor de vragenlijst (default: vandaag).
  DateTime _geselecteerdeDatum = DateTime.now();
  bool _isAlIngevuld = false; // bestaat er al een assessment voor _geselecteerdeDatum?

  String get _geselecteerdeDatumStr {
    final d = _geselecteerdeDatum;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Checkt of er al een assessment is voor de geselecteerde datum en
  /// werkt de "al ingevuld"-indicator bij.
  Future<void> _checkAlIngevuld() async {
    try {
      await ensureInitialized();
      final existing = await db.getMoodAssessment(_geselecteerdeDatumStr);
      if (!mounted) return;
      setState(() => _isAlIngevuld = existing != null);
    } catch (e) {
      debugPrint('MoodAssessment check error: $e');
    }
  }

  Future<void> _kiesDatum() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _geselecteerdeDatum,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
      locale: Localizations.localeOf(context).languageCode == 'nl' ? const Locale('nl', 'NL') : null,
    );
    if (picked == null || !mounted) return;
    setState(() => _geselecteerdeDatum = picked);
    _checkAlIngevuld();
    _laadBestaandeAntwoorden();
  }

  /// Laadt bestaande antwoorden voor de geselecteerde datum in het formulier,
  /// zodat de gebruiker eerder ingevulde gegevens ZIET (en kan aanpassen)
  /// i.p.v. een leeg formulier met alleen een "al ingevuld"-badge.
  Future<void> _laadBestaandeAntwoorden() async {
    try {
      await ensureInitialized();
      final existing = await db.getMoodAssessment(_geselecteerdeDatumStr);
      if (!mounted || existing == null) return;
      double? toDouble(dynamic v) =>
          v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
      final q1 = toDouble(existing['q1_stemming']);
      final q2 = toDouble(existing['q2_energie_slider']);
      final q3 = toDouble(existing['q3_energie_detail']);
      final q4 = toDouble(existing['q4_slaapbehoefte']);
      final q5 = toDouble(existing['q5_gebeurtenis']);
      if (!mounted) return;
      setState(() {
        if (q1 != null) _q1 = q1;
        if (q2 != null) _q2Slider = q2.clamp(0, 100);
        if (q3 != null) _q3 = q3;
        if (q4 != null) _q4 = q4;
        if (q5 != null) _q5 = q5;
        // Terug naar stap 1 zodat de ingevulde antwoorden zichtbaar zijn
        _step = 0;
      });
    } catch (e) {
      debugPrint('MoodAssessment load error: $e');
    }
  }

  bool _canProceed() {
    switch (_step) {
      case 0:
        return _q1 != null;
      case 1:
        return true; // slider heeft altijd een default
      case 2:
        return _q3 != null;
      case 3:
        return _q4 != null;
      case 4:
        return _q5 != null;
      default:
        return false;
    }
  }

  Future<void> _finish() async {
    if (_q1 == null || _q3 == null || _q4 == null || _q5 == null) return;
    final result = _bereken();
    // Toon de resultaat-stap DIRECT; opslaan gebeurt op de achtergrond
    // zodat een trage/geblokkeerde DB-write de UI nooit blokkeert.
    if (!mounted) return;
    setState(() {
      _step = _resultStep;
      _result = result;
    });
    // Fire-and-forget: errors worden gelogd, UI is al door.
    _opslaanMoodAssessment(result);
    _opslaanInDailyLog(result);
  }

  Future<void> _opslaanMoodAssessment(MoodScoreResult result) async {
    try {
      await ensureInitialized();
      await db.upsertMoodAssessment({
        'date': _geselecteerdeDatumStr,
        'q1_stemming': _q1,
        'q2_energie_slider': _q2Slider,
        'q3_energie_detail': _q3,
        'q4_slaapbehoefte': _q4,
        'q5_gebeurtenis': _q5,
        'berekende_score': result.ritmeScore,
        'flags_json': _encodeFlags(result.bipolarTags),
      });
    } catch (e) {
      debugPrint('MoodAssessment save error: $e');
    }
  }

  MoodScoreResult _bereken() {
    return MoodAssessmentScorer.compute(
      q1: _q1!,
      q2Slider: _q2Slider,
      q3: _q3!,
      q4: _q4!,
      q5: _q5!,
    );
  }

  String _encodeFlags(List<BipolarTag> tags) {
    return tags.map((t) => t.id).join(',');
  }

  /// Slaat de berekende stemming direct op in de daily_log (merge-preserving:
  /// bestaande velden zoals slaap/activiteit blijven staan).
  Future<void> _opslaanInDailyLog(MoodScoreResult result) async {
    final date = _geselecteerdeDatumStr;
    try {
      await ensureInitialized();
      // Bestaande log laden zodat we die niet overschrijven (upsert vervangt
      // de hele rij in Hive).
      final existing = await db.getDailyLog(date);
      final log = existing != null ? Map<String, dynamic>.from(existing) : <String, dynamic>{};
      log['date'] = date;
      log['stemming_hoog'] = result.ritmeScore;
      // Geen gesplitste stemming via de vragenlijst: laag = hoog.
      log['stemming_laag'] = result.ritmeScore;
      log['gesplitste_stemming'] = 0;
      await db.upsertDailyLog(log);
    } catch (e) {
      debugPrint('MoodAssessment daily-log save error: $e');
    }
  }

  void _sluiten() {
    if (!mounted) return;
    if (widget.onClose != null) {
      widget.onClose!(true);
    } else {
      Navigator.of(context).pop(true); // true = data is opgeslagen
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.stemmingsCheckTitel),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Datum-selector + "al ingevuld"-indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                      onTap: _kiesDatum,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 18, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              _datumLabel(context),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_isAlIngevuld) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.shade700.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_note, size: 14, color: Colors.orange.shade700),
                          const SizedBox(width: 4),
                          Text(
                            l10n.stemmingsCheckAlIngevuld,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _ProgressBar(step: _step, total: 5),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _step >= 5
                    ? _ResultStep(
                        key: const ValueKey('result'),
                        result: _result,
                        onContinue: _sluiten,
                      )
                    : _buildQuestion(l10n),
              ),
            ),
            if (_step < 5)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              setState(() => _step -= 1),
                          child: Text(l10n.stemmingsCheckVorige),
                        ),
                      ),
                    if (_step > 0) const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _canProceed()
                            ? () {
                                final lastQuestion = 4;
                                if (_step == lastQuestion) {
                                  _finish();
                                } else {
                                  setState(() => _step += 1);
                                }
                              }
                            : null,
                        child: Text(
                          _step == 4 ? l10n.stemmingsCheckAfronden : l10n.stemmingsCheckVolgende,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(AppLocalizations l10n) {
    switch (_step) {
      case 0:
        return _ChoiceQuestion(
          key: const ValueKey('q1'),
          title: l10n.stemmingsCheckVraag1Titel,
          subtitle: l10n.stemmingsCheckVraag1Ondertitel,
          options: [
            _ChoiceOption(
              label: l10n.uiterstManisch,
              value: 4,
              color: _getStemmingColor(4),
            ),
            _ChoiceOption(
              label: l10n.ernstigManisch,
              value: 3,
              color: _getStemmingColor(3),
            ),
            _ChoiceOption(
              label: l10n.drukActief,
              value: 2,
              color: _getStemmingColor(2),
            ),
            _ChoiceOption(
              label: l10n.matigManisch,
              value: 1,
              color: _getStemmingColor(1),
            ),
            _ChoiceOption(
              label: l10n.stabielNeutraal,
              value: 0,
              color: _getStemmingColor(0),
            ),
            _ChoiceOption(
              label: l10n.somber,
              value: -1,
              color: _getStemmingColor(-1),
            ),
            _ChoiceOption(
              label: l10n.lichtDepressief,
              value: -2,
              color: _getStemmingColor(-2),
            ),
            _ChoiceOption(
              label: l10n.matigDepressief,
              value: -3,
              color: _getStemmingColor(-3),
            ),
            _ChoiceOption(
              label: l10n.ernstigDepressief,
              value: -4,
              color: _getStemmingColor(-4),
            ),
          ],
          selected: _q1,
          onChanged: (v) => setState(() => _q1 = v),
        );
      case 1:
        return _SliderQuestion(
          key: const ValueKey('q2'),
          title: l10n.stemmingsCheckVraag2Titel,
          subtitle: l10n.stemmingsCheckVraag2Ondertitel,
          leftLabel: l10n.stemmingsCheckVraag2Links,
          rightLabel: l10n.stemmingsCheckVraag2Rechts,
          value: _q2Slider,
          onChanged: (v) => setState(() => _q2Slider = v),
        );
      case 2:
        return _ChoiceQuestion(
          key: const ValueKey('q3'),
          title: l10n.stemmingsCheckVraag3Titel,
          subtitle: l10n.stemmingsCheckVraag3Ondertitel,
          options: [
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieEnergieOvermatigNietKalm,
              value: 3,
              color: _getStemmingColor(3),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieEnergieOvermatigKalm,
              value: 2,
              color: _getStemmingColor(2),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieEnergieMeer,
              value: 1,
              color: _getStemmingColor(1),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieEnergieNormaal,
              value: 0,
              color: _getStemmingColor(0),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieEnergieEerderMo,
              value: -1,
              color: _getStemmingColor(-1),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieEnergieBijnaAlles,
              value: -2,
              color: _getStemmingColor(-2),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieEnergieNiets,
              value: -3,
              color: _getStemmingColor(-3),
            ),
          ],
          selected: _q3,
          onChanged: (v) => setState(() => _q3 = v),
        );
      case 3:
        return _ChoiceQuestion(
          key: const ValueKey('q4'),
          title: l10n.stemmingsCheckVraag4Titel,
          subtitle: l10n.stemmingsCheckVraag4Ondertitel,
          options: [
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieSlaapPlus4,
              value: 4,
              color: _getStemmingColor(4),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieSlaapPlus3,
              value: 3,
              color: _getStemmingColor(3),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieSlaapPlus2,
              value: 2,
              color: _getStemmingColor(2),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieSlaapPlus1,
              value: 1,
              color: _getStemmingColor(1),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieSlaapNul,
              value: 0,
              color: _getStemmingColor(0),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieSlaapMin1,
              value: -1,
              color: _getStemmingColor(-1),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieSlaapMin2,
              value: -2,
              color: _getStemmingColor(-2),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieSlaapMin3,
              value: -3,
              color: _getStemmingColor(-3),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieSlaapMin4,
              value: -4,
              color: _getStemmingColor(-4),
            ),
          ],
          selected: _q4,
          onChanged: (v) => setState(() => _q4 = v),
        );
      case 4:
        return _ChoiceQuestion(
          key: const ValueKey('q5'),
          title: l10n.stemmingsCheckVraag5Titel,
          subtitle: l10n.stemmingsCheckVraag5Ondertitel,
          options: [
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieExtreemPositief,
              value: 4,
              color: _getStemmingColor(4),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptiePositiefHoog,
              value: 3,
              color: _getStemmingColor(3),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptiePositiefMatig,
              value: 2,
              color: _getStemmingColor(2),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieLichtPositief,
              value: 1,
              color: _getStemmingColor(1),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieNeutraal,
              value: 0,
              color: _getStemmingColor(0),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieLichtNegatief,
              value: -1,
              color: _getStemmingColor(-1),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieNegatiefMatig,
              value: -2,
              color: _getStemmingColor(-2),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieNegatiefHoog,
              value: -3,
              color: _getStemmingColor(-3),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieExtreemNegatief,
              value: -4,
              color: _getStemmingColor(-4),
            ),
          ],
          selected: _q5,
          onChanged: (v) => setState(() => _q5 = v),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

Color _getStemmingColor(double v) {
  if (v <= -4) return const Color(0xFF616161);
  if (v <= -3) return const Color(0xFF424242);
  if (v <= -2) return const Color(0xFF42A5F5);
  if (v <= -1) return const Color(0xFF90CAF9);
  if (v == 0) return const Color(0xFF66BB6A);
  if (v <= 1) return const Color(0xFFFDD835);
  if (v <= 2) return const Color(0xFFFF9800);
  if (v <= 3) return const Color(0xFFF57C00);
  return const Color(0xFFE53935);
}

class _ProgressBar extends StatelessWidget {
  final int step;
  final int total;
  const _ProgressBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = (step.clamp(0, total)) / total;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).stapXvanY(
              step.clamp(0, total) + (step < 5 ? 1 : 0),
              total,
            ),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceOption {
  final String label;
  final double value;
  final Color color;
  const _ChoiceOption({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _ChoiceQuestion extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_ChoiceOption> options;
  final double? selected;
  final ValueChanged<double> onChanged;

  const _ChoiceQuestion({
    super.key,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 16),
          for (final opt in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OptionTile(
                option: opt,
                isSelected: selected == opt.value,
                onTap: () => onChanged(opt.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final _ChoiceOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.smallRadius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? option.color.withValues(alpha: 0.15)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppTheme.smallRadius),
          border: Border.all(
            color: isSelected
                ? option.color
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: option.color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              option.value > 0
                  ? '+${option.value.toInt()}'
                  : option.value.toInt().toString(),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderQuestion extends StatelessWidget {
  final String title;
  final String subtitle;
  final String leftLabel;
  final String rightLabel;
  final double value;
  final ValueChanged<double> onChanged;

  const _SliderQuestion({
    super.key,
    required this.title,
    required this.subtitle,
    required this.leftLabel,
    required this.rightLabel,
    required this.value,
    required this.onChanged,
  });

  /// Spreekt uit waar de schuif staat, in gewone mensentaal.
  static String _bandLabel(double v) {
    if (v <= 15) return 'Heel laag';
    if (v <= 35) return 'Laag';
    if (v <= 65) return 'In balans';
    if (v <= 85) return 'Hoog';
    return 'Zeer hoog';
  }

  /// Trek de accentkleur mee van koel (links) naar warm (rechts).
  static Color _bandColor(double v) {
    if (v <= 15) return const Color(0xFF3F51B5);
    if (v <= 35) return const Color(0xFF5C6BC0);
    if (v <= 65) return const Color(0xFF4DB6AC);
    if (v <= 85) return const Color(0xFFFFA726);
    return const Color(0xFFEF6C00);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final band = _bandLabel(value);
    final accent = _bandColor(value);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 28),

          // Score-uitlezing boven de slider.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  fontSize: 44,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                child: Text(value.round().toString()),
              ),
              const SizedBox(width: 10),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
                child: Text(band),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // De bipolaire slider: blauw (depressief) naar oranje (manisch).
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackShape: const _GradientTrackShape(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF3F51B5),
                    Color(0xFF5C6BC0),
                    Color(0xFF8D9BB3),
                    Color(0xFFFFB74D),
                    Color(0xFFEF6C00),
                  ],
                  stops: [0.0, 0.22, 0.5, 0.78, 1.0],
                ),
              ),
              trackHeight: 14,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 13,
                elevation: 3,
                pressedElevation: 5,
              ),
              thumbColor: Colors.white,
              overlayColor: accent.withValues(alpha: 0.18),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 100,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(height: 10),

          // Eindlabels met icoon.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.battery_0_bar,
                      size: 18, color: theme.colorScheme.outline),
                  const SizedBox(width: 6),
                  Text(
                    leftLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    rightLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.bolt, size: 18, color: theme.colorScheme.outline),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rounded gradient-track met een subtiele middenstreep voor de bipolaire
/// energieslider.
class _GradientTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  final Gradient gradient;

  const _GradientTrackShape({required this.gradient});

  @override
  bool get isRounded => true;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final canvas = context.canvas;
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.height / 2),
    );
    canvas.drawRRect(rrect, Paint()..shader = gradient.createShader(rect));
    // Middenstreep = neutraal punt (50%).
    final cx = rect.center.dx;
    canvas.drawLine(
      Offset(cx, rect.top + 3),
      Offset(cx, rect.bottom - 3),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }
}

class _ResultStep extends StatefulWidget {
  final MoodScoreResult? result;
  final VoidCallback onContinue;
  const _ResultStep({
    super.key,
    required this.result,
    required this.onContinue,
  });

  @override
  State<_ResultStep> createState() => _ResultStepState();
}

class _ResultStepState extends State<_ResultStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _gauge;
  late final Animation<double> _fade1;
  late final Animation<double> _fade2;
  late final Animation<double> _fade3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _gauge = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
    );
    _fade1 = _fade(0.0);
    _fade2 = _fade(0.30);
    _fade3 = _fade(0.55);
  }

  Animation<double> _fade(double begin) => CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, begin + 0.45, curve: Curves.easeOutCubic),
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _scoreColor(double t) {
    const c0 = Color(0xFF3F51B5); // diep blauw (laag)
    const c1 = Color(0xFF26A69A); // teal (neutraal)
    const c2 = Color(0xFFF9A825); // amber (hoog)
    const c3 = Color(0xFFE53935); // rood (zeer hoog)
    if (t < 0.38) return Color.lerp(c0, c1, t / 0.38)!;
    if (t < 0.62) return c1;
    if (t < 0.85) return Color.lerp(c1, c2, (t - 0.62) / 0.23)!;
    return Color.lerp(c2, c3, (t - 0.85) / 0.15)!;
  }

  String _moodLabel(BuildContext context, int score) {
    final l10n = AppLocalizations.of(context);
    switch (score) {
      case 4:
        return l10n.stemmingsCheckOptieExtreemPositief;
      case 3:
        return l10n.stemmingsCheckOptiePositiefHoog;
      case 2:
        return l10n.stemmingsCheckOptiePositiefMatig;
      case 1:
        return l10n.stemmingsCheckOptieLichtPositief;
      case 0:
        return l10n.stemmingsCheckOptieNeutraal;
      case -1:
        return l10n.stemmingsCheckOptieLichtNegatief;
      case -2:
        return l10n.stemmingsCheckOptieNegatiefMatig;
      case -3:
        return l10n.stemmingsCheckOptieNegatiefHoog;
      default:
        return l10n.stemmingsCheckOptieExtreemNegatief;
    }
  }

  Color _tagColor(BipolarTag tag, ThemeData theme) {
    switch (tag) {
      case BipolarTag.maniaShift:
      case BipolarTag.probableMania:
      case BipolarTag.sleepReductionAlone:
      case BipolarTag.positiveLifeEventTrigger:
        return const Color(0xFFB45309); // amber-700, leesbaar op beide
      case BipolarTag.depressionShift:
      case BipolarTag.probableDepression:
      case BipolarTag.negativeLifeEventTrigger:
        return const Color(0xFF3949AB); // indigo-600
      case BipolarTag.mixedEpisode:
      case BipolarTag.opposingSignals:
        return const Color(0xFF6A3FB5); // paars
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tags = widget.result?.bipolarTags ?? const <BipolarTag>[];
    final score = widget.result?.ritmeScore ?? 0;
    final frac = ((score + 4) / 8.0).clamp(0.0, 1.0);
    final accent = _scoreColor(frac);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero: gauge met score ───────────────────────────────
          FadeTransition(
            opacity: _fade1,
            child: _StaggeredSlide(
              animation: _fade1,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.largeRadius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.30),
                      accent.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 18, color: accent),
                        const SizedBox(width: 8),
                        Text(
                          l10n.stemmingsCheckSuccesTitel,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 100,
                      child: AnimatedBuilder(
                        animation: _gauge,
                        builder: (context, _) => CustomPaint(
                          size: Size.infinite,
                          painter: _MoodGaugePainter(
                            progress: _gauge.value * frac,
                            trackColor: theme.colorScheme.outline.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _gauge,
                      builder: (context, _) {
                        final shown = (_gauge.value * score).round();
                        return Text(
                          shown >= 0 ? '+$shown' : '$shown',
                          style: TextStyle(
                            fontSize: 44,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: accent,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _moodLabel(context, score),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Analyse / tags ───────────────────────────────────────
          FadeTransition(
            opacity: _fade2,
            child: _StaggeredSlide(
              animation: _fade2,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.stemmingsCheckAnalyseTitel,
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (tags.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          l10n.stemmingsCheckAnalyseGeen,
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tags.map((tag) {
                          final color = _tagColor(tag, theme);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              border: Border.all(
                                color: color.withValues(alpha: 0.6),
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 14,
                                  color: color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tag.localizedLabel(l10n),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.stemmingsCheckAnalyseTip,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Knoppen ──────────────────────────────────────────────
          FadeTransition(
            opacity: _fade3,
            child: _StaggeredSlide(
              animation: _fade3,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.stemmingsCheckSluiten),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.onContinue,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(l10n.stemmingsCheckSuccesDoorNaar),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
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
}

/// Fade + slide omhoog voor staggered entrance.
class _StaggeredSlide extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _StaggeredSlide({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// 270°-boog die het stemmingsresultaat toont (blauw → teal → amber → rood).
class _MoodGaugePainter extends CustomPainter {
  final double progress; // 0..1
  final Color trackColor;

  const _MoodGaugePainter({required this.progress, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.86);
    final radius = size.height * 0.78;
    final strokeWidth = size.height * 0.16;
    const startAngle = math.pi * 0.75;
    const sweep = math.pi * 1.5;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawArc(rect, startAngle, sweep, false, track);

    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweep,
        colors: const [
          Color(0xFF3F51B5),
          Color(0xFF26A69A),
          Color(0xFFF9A825),
          Color(0xFFE53935),
        ],
        stops: const [0.0, 0.38, 0.66, 1.0],
      ).createShader(rect);
    canvas.drawArc(rect, startAngle, sweep * progress, false, arc);

    // Knopje op het einde van de gevulde boog.
    final endAngle = startAngle + sweep * progress;
    final knob = Offset(
      center.dx + radius * math.cos(endAngle),
      center.dy + radius * math.sin(endAngle),
    );
    canvas.drawCircle(
      knob,
      strokeWidth * 0.42,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      knob,
      strokeWidth * 0.42,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF263238).withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(covariant _MoodGaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.trackColor != trackColor;
}
