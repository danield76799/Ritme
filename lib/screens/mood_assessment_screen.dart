import 'package:flutter/material.dart';
import '../generated/l10n/app_localizations.dart';
import '../service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/mood_assessment_scorer.dart';
import 'mood_screen.dart';

/// 5-staps vragenlijst die een stemming-score berekent op basis van gewogen
/// antwoorden, en het MoodScreen opent met de berekende waarde als
/// voorselectie.
///
/// Vragenlijst:
///  1. Hoe is uw stemming vandaag?            (-4..+4)
///  2. Hoe is uw energie? Slider 0..100       (manisch → depressief)
///  3. Hoe is uw energie niveau?              (-3..+3)
///  4. Slaapbehoefte                          (-4..+4)
///  5. Belangrijke gebeurtenis                (-4..+4)
class MoodAssessmentScreen extends StatefulWidget {
  const MoodAssessmentScreen({super.key});

  @override
  State<MoodAssessmentScreen> createState() => _MoodAssessmentScreenState();
}

class _MoodAssessmentScreenState extends State<MoodAssessmentScreen> {
  int _step = 0; // 0..4 = vraag 1..5, 5 = resultaat
  double? _q1; // stemming -4..+4
  double _q2Slider = 50; // 0..100 (manisch=0, depressief=100)
  double? _q3; // energie detail -3..+3
  double? _q4; // slaapbehoefte -4..+4
  double? _q5; // gebeurtenis -4..+4

  String _todayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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
    final result = MoodAssessmentScorer.compute(
      q1: _q1!,
      q2Slider: _q2Slider,
      q3: _q3!,
      q4: _q4!,
      q5: _q5!,
    );
    try {
      await ensureInitialized();
      await db.upsertMoodAssessment({
        'date': _todayDate(),
        'q1_stemming': _q1,
        'q2_energie_slider': _q2Slider,
        'q3_energie_detail': _q3,
        'q4_slaapbehoefte': _q4,
        'q5_gebeurtenis': _q5,
        'berekende_score': result.ritmeScore,
      });
    } catch (e) {
      debugPrint('MoodAssessment save error: $e');
    }
    if (!mounted) return;
    setState(() => _step = 5);
  }

  void _goToMoodScreen() {
    if (!mounted) return;
    final result = MoodAssessmentScorer.compute(
      q1: _q1!,
      q2Slider: _q2Slider,
      q3: _q3!,
      q4: _q4!,
      q5: _q5!,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MoodScreen(
          prefillStemmingHoog: result.ritmeScore.toDouble(),
          prefillGesplitst: result.recommendSplit,
        ),
      ),
    );
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
            _ProgressBar(step: _step, total: 5),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _step == 5
                    ? _ResultStep(
                        onContinue: _goToMoodScreen,
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
              label: 'Positief hoog',
              value: 3,
              color: _getStemmingColor(3),
            ),
            _ChoiceOption(
              label: 'Positief matig',
              value: 2,
              color: _getStemmingColor(2),
            ),
            _ChoiceOption(
              label: 'Licht positief',
              value: 1,
              color: _getStemmingColor(1),
            ),
            _ChoiceOption(
              label: l10n.stemmingsCheckOptieNeutraal,
              value: 0,
              color: _getStemmingColor(0),
            ),
            _ChoiceOption(
              label: 'Licht negatief',
              value: -1,
              color: _getStemmingColor(-1),
            ),
            _ChoiceOption(
              label: 'Negatief matig',
              value: -2,
              color: _getStemmingColor(-2),
            ),
            _ChoiceOption(
              label: 'Negatief hoog',
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
            divisions: 100,
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
  final VoidCallback onContinue;
  const _ResultStep({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // We can't read private state directly; the parent computes via onContinue.
    // Display a generic success layout and a "continue" button.
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 96,
            color: AppTheme.primaryTeal,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.stemmingsCheckSuccesTitel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
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
