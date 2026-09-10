import 'package:flutter/material.dart';
import '../generated/l10n/app_localizations.dart';
import '../service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/logger.dart';
import '../utils/mood_assessment_scorer.dart';
import 'morning_checkin_screen.dart' show MoodAssessmentScorerColors;

/// Avond check-in: de terugblik op de dag, vlak voordat je gaat slapen.
///
///  1. Stemming vandaag                    (q1, -4..+4)
///  2. Energie slider                      (q2, 0..100)
///  3. Energie-niveau                      (q3, -3..+3)
///  4. Belangrijke gebeurtenis + invloed   (q5, -4..+4)
///  5. Je dag: Eerste contact / Werk-Hobby / Avondeten (SRM-tijden)
///  6. Naar bed                            (tijd → slaap start, SRM "Naar bed")
///
/// Opslag: mood_assessment (q1/q2/q3/q5 merge), daily_log (stemming + bedtijd),
/// srm_activities (3 tijden + Naar bed met P-score), sleep-log (bedtijd).
class EveningCheckInScreen extends StatefulWidget {
  const EveningCheckInScreen({super.key, this.onClose});

  final void Function(bool saved)? onClose;

  @override
  State<EveningCheckInScreen> createState() => _EveningCheckInScreenState();
}

class _EveningCheckInScreenState extends State<EveningCheckInScreen> {
  int _step = 0; // 0..3 stemming, 4..6 SRM tijden, 7 = bedtijd, 8 = klaar
  MoodScoreResult? _result;
  double? _q1;
  double _q2Slider = 50;
  double? _q3;
  double? _q5;

  // SRM-tijden
  TimeOfDay? _eersteContact;
  TimeOfDay? _werkHobby;
  TimeOfDay? _avondeten;
  TimeOfDay? _bedTime;

  bool _isSaving = false;

  static const _totaalStappen = 8;

  String get _formattedToday {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _laadSettings();
  }

  Future<void> _laadSettings() async {
    // Menstruatie-vraag is verwijderd — geen instellingen meer nodig.
  }

  String _formatTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<TimeOfDay?> _pickTime(TimeOfDay? current) async {
    return showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
  }

  Future<void> _finish() async {
    if (_q1 == null || _q3 == null || _q5 == null || _isSaving) return;
    setState(() => _isSaving = true);

    // Score berekenen — q4 komt uit de ochtendcheck-in (of null → 0 fallback
    // in de scorer is niet aanwezig; we lezen hem uit het assessment).
    double q4 = 0;
    try {
      final existing = await db.getMoodAssessment(_formattedToday);
      if (existing != null) {
        final raw = existing['q4_slaapbehoefte'];
        q4 = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '') ?? 0;
      }
    } catch (_) {}

    final result = MoodAssessmentScorer.compute(
      q1: _q1!,
      q2Slider: _q2Slider,
      q3: _q3!,
      q4: q4,
      q5: _q5!,
    );

    if (mounted) {
      setState(() {
        _step = _totaalStappen;
        _result = result;
      });
    }

    // Fire-and-forget opslag
    _opslaan(result, q4);
  }

  Future<void> _opslaan(MoodScoreResult result, double q4) async {
    final today = _formattedToday;
    try {
      await ensureInitialized();

      // 1. mood_assessment merge (q1/q2/q3/q5/score/flags; q4 uit ochtend behouden)
      final existingAssessment = await db.getMoodAssessment(today);
      final assessment = existingAssessment != null
          ? Map<String, dynamic>.from(existingAssessment)
          : <String, dynamic>{};
      assessment['date'] = today;
      assessment['q1_stemming'] = _q1;
      assessment['q2_energie_slider'] = _q2Slider;
      assessment['q3_energie_detail'] = _q3;
      assessment['q5_gebeurtenis'] = _q5;
      assessment['menstruatie'] = _showMenstruatieVraag && _menstruatie ? 1 : 0;
      assessment['berekende_score'] = result.ritmeScore;
      assessment['flags_json'] = result.bipolarTags.map((t) => t.id).join(',');
      await db.upsertMoodAssessment(assessment);

      // 2. daily_log merge-preserving
      final existingLog = await db.getDailyLog(today);
      final log = existingLog != null ? Map<String, dynamic>.from(existingLog) : <String, dynamic>{};
      log['date'] = today;
      log['stemming_hoog'] = result.ritmeScore;
      log['stemming_laag'] = result.ritmeScore;
      log['gesplitste_stemming'] = 0;
      if (_bedTime != null) log['bed_time'] = _formatTimeOfDay(_bedTime!);
      await db.upsertDailyLog(log);

      // 3. SRM-activiteiten met P-score tegen doeltijden
      final settings = await db.getSettings();
      final targets = {
        'Eerste contact': settings?['target_contact']?.toString(),
        'Werk / Hobby': settings?['target_werk']?.toString(),
        'Avondeten': settings?['target_eten']?.toString(),
        'Naar bed': settings?['target_slapen']?.toString(),
      };
      final tijden = {
        'Eerste contact': _eersteContact,
        'Werk / Hobby': _werkHobby,
        'Avondeten': _avondeten,
        'Naar bed': _bedTime,
      };
      for (final entry in tijden.entries) {
        final tijd = entry.value;
        if (tijd == null) continue;
        final timeStr = _formatTimeOfDay(tijd);
        final targetStr = targets[entry.key];
        int pScore = 3;
        if (targetStr != null && targetStr.isNotEmpty && targetStr != '--:--') {
          final tParts = targetStr.split(':');
          final tMinutes = (int.tryParse(tParts[0]) ?? 0) * 60 + (int.tryParse(tParts[1]) ?? 0);
          final aMinutes = (tijd.hour * 60) + tijd.minute;
          final diff = (aMinutes - tMinutes).abs();
          pScore = diff <= 15
              ? 5
              : diff <= 30
                  ? 4
                  : diff <= 45
                      ? 3
                      : diff <= 60
                          ? 2
                          : 1;
        }
        await db.insertSrmActivity(today, entry.key, timeStr, pScore, null,
            targetTime: (targetStr != null && targetStr != '--:--') ? targetStr : null);
      }
    } catch (e) {
      AppLogger.error('EveningCheckIn: opslaan mislukt', error: e);
    }
  }

  void _sluiten() {
    if (!mounted) return;
    if (widget.onClose != null) {
      widget.onClose!(true);
    } else {
      Navigator.of(context).pop(true);
    }
  }

  bool _canProceed() {
    switch (_step) {
      case 0:
        return _q1 != null;
      case 1:
        return true;
      case 2:
        return _q3 != null;
      case 3:
        return _q5 != null;
      case 4:
        return true; // SRM-tijden zijn optioneel
      case 5:
        return true;
      case 6:
        return true;
      case 7:
        return true; // bedtijd optioneel (kan later via ochtendcheck-in)
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.avondCheckIn),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SafeArea(
        child: _step >= _totaalStappen ? _buildKlaar(context) : _buildVraag(context),
      ),
    );
  }

  Widget _buildVraag(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        LinearProgressIndicator(
          value: (_step + 1) / _totaalStappen,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _stepContent(context),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_step > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _step -= 1),
                    child: Text(l10n.stemmingsCheckVorige),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _canProceed()
                      ? () {
                          if (_step == 7) {
                            _finish();
                          } else {
                            setState(() => _step += 1);
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _step == 7 ? l10n.stemmingsCheckAfronden : l10n.stemmingsCheckVolgende,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (_step) {
      case 0:
        return _keuzeVraag(
          icon: Icons.sentiment_satisfied_alt,
          titel: l10n.stemmingsCheckVraag1Titel,
          options: _stemmingOpties(),
          selected: _q1,
          onChanged: (v) => setState(() => _q1 = v),
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.bolt, size: 56, color: AppTheme.primaryTeal),
            const SizedBox(height: 16),
            Text(l10n.stemmingsCheckVraag2Titel,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              l10n.stemmingsCheckVraag2Ondertitel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.stemmingsCheckVraag2Links, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(l10n.stemmingsCheckVraag2Rechts, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            Slider(
              value: _q2Slider,
              min: 0,
              max: 100,
              divisions: 10,
              label: _q2Slider.round().toString(),
              onChanged: (v) => setState(() => _q2Slider = v),
            ),
            Center(
              child: Text(
                _q2Slider.round().toString(),
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      case 2:
        return _keuzeVraag(
          icon: Icons.bolt_outlined,
          titel: l10n.stemmingsCheckVraag3Titel,
          options: _energieOpties(),
          selected: _q3,
          onChanged: (v) => setState(() => _q3 = v),
        );
      case 3:
        return _keuzeVraag(
          icon: Icons.event,
          titel: l10n.stemmingsCheckVraag5Titel,
          ondertitel: l10n.stemmingsCheckVraag5Ondertitel,
          options: _gebeurtenisOpties(),
          selected: _q5,
          onChanged: (v) => setState(() => _q5 = v),
        );
      case 4:
        return _srmTijdVraag(
          icon: Icons.person_outline,
          titel: l10n.avondEersteContact,
          tijd: _eersteContact,
          onPick: (t) => setState(() => _eersteContact = t),
        );
      case 5:
        return _srmTijdVraag(
          icon: Icons.work_outline,
          titel: l10n.avondWerkHobby,
          tijd: _werkHobby,
          onPick: (t) => setState(() => _werkHobby = t),
        );
      case 6:
        return _srmTijdVraag(
          icon: Icons.restaurant_outlined,
          titel: l10n.avondAvondeten,
          tijd: _avondeten,
          onPick: (t) => setState(() => _avondeten = t),
        );
      case 7:
        return _srmTijdVraag(
          icon: Icons.bedtime,
          titel: l10n.avondNaarBed,
          tijd: _bedTime,
          onPick: (t) => setState(() => _bedTime = t),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _keuzeVraag({
    required IconData icon,
    required String titel,
    String? ondertitel,
    required List<({String label, double value, Color color})> options,
    required double? selected,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 56, color: AppTheme.primaryTeal),
        const SizedBox(height: 16),
        Text(
          titel,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (ondertitel != null) ...[
          const SizedBox(height: 4),
          Text(
            ondertitel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
        const SizedBox(height: 16),
        ...options.map(
          (o) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptieTile(
              label: o.label,
              value: o.value,
              color: o.color,
              selected: selected == o.value,
              onTap: () => onChanged(o.value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _srmTijdVraag({
    required IconData icon,
    required String titel,
    required TimeOfDay? tijd,
    required ValueChanged<TimeOfDay> onPick,
  }) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 56, color: AppTheme.primaryTeal),
        const SizedBox(height: 16),
        Text(
          titel,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        Center(
          child: OutlinedButton.icon(
            onPressed: () async {
              final picked = await _pickTime(tijd);
              if (picked != null) onPick(picked);
            },
            icon: const Icon(Icons.access_time),
            label: Text(
              tijd != null ? _formatTimeOfDay(tijd) : l10n.tikOmTijdInTeStellen,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  List<({String label, double value, Color color})> _stemmingOpties() {
    final l10n = AppLocalizations.of(context);
    Color c(double v) => MoodAssessmentScorerColors.slaapbehoefteColor(v);
    return [
      (label: l10n.uiterstManisch, value: 4, color: c(4)),
      (label: l10n.ernstigManisch, value: 3, color: c(3)),
      (label: l10n.drukActief, value: 2, color: c(2)),
      (label: l10n.matigManisch, value: 1, color: c(1)),
      (label: l10n.stabielNeutraal, value: 0, color: c(0)),
      (label: l10n.somber, value: -1, color: c(-1)),
      (label: l10n.lichtDepressief, value: -2, color: c(-2)),
      (label: l10n.matigDepressief, value: -3, color: c(-3)),
      (label: l10n.ernstigDepressief, value: -4, color: c(-4)),
    ];
  }

  List<({String label, double value, Color color})> _energieOpties() {
    final l10n = AppLocalizations.of(context);
    Color c(double v) => MoodAssessmentScorerColors.slaapbehoefteColor(v);
    return [
      (label: l10n.stemmingsCheckOptieEnergieOvermatigNietKalm, value: 3, color: c(3)),
      (label: l10n.stemmingsCheckOptieEnergieOvermatigKalm, value: 2, color: c(2)),
      (label: l10n.stemmingsCheckOptieEnergieMeer, value: 1, color: c(1)),
      (label: l10n.stemmingsCheckOptieEnergieNormaal, value: 0, color: c(0)),
      (label: l10n.stemmingsCheckOptieEnergieEerderMo, value: -1, color: c(-1)),
      (label: l10n.stemmingsCheckOptieEnergieBijnaAlles, value: -2, color: c(-2)),
      (label: l10n.stemmingsCheckOptieEnergieNiets, value: -3, color: c(-3)),
    ];
  }

  List<({String label, double value, Color color})> _gebeurtenisOpties() {
    final l10n = AppLocalizations.of(context);
    Color c(double v) => MoodAssessmentScorerColors.slaapbehoefteColor(v);
    return [
      (label: l10n.stemmingsCheckOptieExtreemPositief, value: 4, color: c(4)),
      (label: l10n.stemmingsCheckOptiePositiefHoog, value: 3, color: c(3)),
      (label: l10n.stemmingsCheckOptiePositiefMatig, value: 2, color: c(2)),
      (label: l10n.stemmingsCheckOptieLichtPositief, value: 1, color: c(1)),
      (label: l10n.stemmingsCheckOptieNeutraal, value: 0, color: c(0)),
      (label: l10n.stemmingsCheckOptieLichtNegatief, value: -1, color: c(-1)),
      (label: l10n.stemmingsCheckOptieNegatiefMatig, value: -2, color: c(-2)),
      (label: l10n.stemmingsCheckOptieNegatiefHoog, value: -3, color: c(-3)),
      (label: l10n.stemmingsCheckOptieExtreemNegatief, value: -4, color: c(-4)),
    ];
  }

  Widget _buildKlaar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.nights_stay, size: 64, color: AppTheme.primaryTeal),
            const SizedBox(height: 16),
            Text(
              l10n.avondCheckInKlaar,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (_result != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.stemmingsCheckSuccesTitel,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ..._result!.bipolarTags.map(
                (tag) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Chip(
                    label: Text(
                      tag.label,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: MoodAssessmentScorerColors.slaapbehoefteColor(0).withValues(alpha: 0.1),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _sluiten,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.stemmingsCheckSuccesDoorNaar),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptieTile extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _OptieTile({
    required this.label,
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}