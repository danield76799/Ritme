import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../generated/l10n/app_localizations.dart';
import '../service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/mood_assessment_scorer.dart';

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
  MoodScoreResult? _result; // berekend bij _finish, getoond in resultaat-stap
  double? _q1; // stemming -4..+4
  double _q2Slider = 50; // 0..100 (depressief=0, manisch=100)
  double? _q3; // energie detail -3..+3
  double? _q4; // slaapbehoefte -4..+4
  double? _q5; // gebeurtenis -4..+4

  @override
  void initState() {
    super.initState();
    _checkAlIngevuld();
  }

  String _datumLabel(BuildContext context) {
    final now = DateTime.now();
    final d = _geselecteerdeDatum;
    final fmt = DateFormat('d MMM', 'nl');
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
    );
    if (picked == null || !mounted) return;
    setState(() => _geselecteerdeDatum = picked);
    _checkAlIngevuld();
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
      _step = 5;
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                      borderRadius: BorderRadius.circular(10),
                      onTap: _kiesDatum,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
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
                        borderRadius: BorderRadius.circular(20),
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
                child: _step == 5
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
                                if (_step == 4) {
                                  _finish();
                                } else {
                                  setState(() => _step += 1);
                                }
                              }
                            : null,
                        child: Text(
                          _step == 4
                              ? l10n.stemmingsCheckAfronden
                              : l10n.stemmingsCheckVolgende,
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
              label: l10n.stemmingsCheckOptieSlaapGeen,
              value: 4,
              color: _getStemmingColor(4),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieSlaapVerminderd,
              value: 3,
              color: _getStemmingColor(3),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieSlaap1UurKorter,
              value: 2,
              color: _getStemmingColor(2),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieSlaapTot1UurKorter,
              value: 1,
              color: _getStemmingColor(1),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieSlaapNietZoGoed,
              value: -1,
              color: _getStemmingColor(-1),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieSlaap12UurEerder,
              value: -2,
              color: _getStemmingColor(-2),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieSlaapUrenEerder,
              value: -3,
              color: _getStemmingColor(-3),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieSlaapNietTot,
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
            'Stap ${step.clamp(0, total) + (step < 5 ? 1 : 0)} / $total',
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
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? option.color.withValues(alpha: 0.15)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
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
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                leftLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                rightLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 10,
            label: value.round().toString(),
            onChanged: onChanged,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              value.round().toString(),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultStep extends StatelessWidget {
  final MoodScoreResult? result;
  final VoidCallback onContinue;
  const _ResultStep({
    super.key,
    required this.result,
    required this.onContinue,
  });

  String _tagLabel(BipolarTag tag, AppLocalizations l10n) {
    switch (tag) {
      case BipolarTag.maniaShift:
        return l10n.tagManiaShift;
      case BipolarTag.probableMania:
        return l10n.tagProbableMania;
      case BipolarTag.sleepReductionAlone:
        return l10n.tagSleepReductionAlone;
      case BipolarTag.depressionShift:
        return l10n.tagDepressionShift;
      case BipolarTag.probableDepression:
        return l10n.tagProbableDepression;
      case BipolarTag.positiveLifeEventTrigger:
        return l10n.tagPositiveLifeEventTrigger;
      case BipolarTag.negativeLifeEventTrigger:
        return l10n.tagNegativeLifeEventTrigger;
      case BipolarTag.mixedEpisode:
        return l10n.tagMixedEpisode;
      case BipolarTag.opposingSignals:
        return l10n.tagOpposingSignals;
    }
  }

  Color _tagColor(BipolarTag tag, ThemeData theme) {
    switch (tag) {
      case BipolarTag.maniaShift:
      case BipolarTag.probableMania:
      case BipolarTag.sleepReductionAlone:
      case BipolarTag.positiveLifeEventTrigger:
        return Colors.orange.shade700;
      case BipolarTag.depressionShift:
      case BipolarTag.probableDepression:
      case BipolarTag.negativeLifeEventTrigger:
        return Colors.indigo.shade400;
      case BipolarTag.mixedEpisode:
      case BipolarTag.opposingSignals:
        return Colors.deepPurple.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tags = result?.bipolarTags ?? const <BipolarTag>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Icon(
            Icons.check_circle_outline,
            size: 96,
            color: AppTheme.primaryTeal,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.stemmingsCheckSuccesTitel,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 24),

          // Bipolaire analyse-sectie
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
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
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _tagLabel(tag, l10n),
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

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onContinue,
            child: Text(l10n.stemmingsCheckSuccesDoorNaar),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.stemmingsCheckSluiten),
          ),
        ],
      ),
    );
  }
}
