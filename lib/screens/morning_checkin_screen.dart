import 'package:flutter/material.dart';
import '../generated/l10n/app_localizations.dart';
import '../service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/logger.dart';
import '../utils/mood_assessment_scorer.dart';

/// Ochtend check-in: 3 korte stappen die bij het opstaan horen.
///
///  1. Hoe laat stond je op?        (tijd — vult slaap + SRM "Opstaan" + P-score)
///  2. Wakker gelegen (minuten)     (samen met gisteravonds bedtijd → slaapduur)
///  3. Slaapbehoefte                (q4 uit de stemmingscheck, -4..+4)
///
/// Opslag:
///  - sleep log (bedtijd = gisteravond uit daily_log, wake = nu gekozen)
///  - daily_log merge-preserving: uren_slaap, awake_minutes, q4
///  - SRM "Opstaan" met P-score tegen de doeltijd
class MorningCheckInScreen extends StatefulWidget {
  const MorningCheckInScreen({super.key, this.onClose});

  final void Function(bool saved)? onClose;

  @override
  State<MorningCheckInScreen> createState() => _MorningCheckInScreenState();
}

class _MorningCheckInScreenState extends State<MorningCheckInScreen> {
  int _step = 0; // 0 = opstaantijd, 1 = wakker gelegen, 2 = slaapbehoefte, 3 = klaar
  TimeOfDay? _wakeTime;
  int _awakeMinutes = 0;
  double? _q4; // slaapbehoefte -4..+4
  String? _bedTimeYesterday; // uit gisterens slaap-log
  bool _isSaving = false;

  String get _formattedToday {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadBedTimeYesterday();
  }

  /// Bedtijd van gisteravond ophalen (uit gisterens slaap-log of daily_log),
  /// zodat de slaapduur alvast berekend kan worden.
  Future<void> _loadBedTimeYesterday() async {
    try {
      await ensureInitialized();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      final log = await db.getSleepLog(yStr);
      final bed = log?['bed_time']?.toString();
      if (mounted && bed != null && bed.isNotEmpty) {
        setState(() => _bedTimeYesterday = bed);
      }
    } catch (e) {
      AppLogger.error('MorningCheckIn: kon gisterse bedtijd niet laden', error: e);
    }
  }

  String _formatTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Slaapduur in uren: bedtijd gisteren → opstaantijd vandaag − wakker-gelegen.
  double? _calculateSleepHours() {
    if (_bedTimeYesterday == null || _wakeTime == null) return null;
    try {
      final bedParts = _bedTimeYesterday!.split(':');
      final bedMinutes = (int.parse(bedParts[0]) * 60) + int.parse(bedParts[1]);
      final wakeMinutes = (_wakeTime!.hour * 60) + _wakeTime!.minute;
      var total = wakeMinutes - bedMinutes - _awakeMinutes;
      if (total <= 0) total += 24 * 60; // over middernacht
      return total / 60.0;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickWakeTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _wakeTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _wakeTime = picked);
    }
  }

  Future<void> _finish() async {
    if (_wakeTime == null || _q4 == null || _isSaving) return;
    setState(() => _isSaving = true);

    final wakeStr = _formatTimeOfDay(_wakeTime!);
    final sleepHours = _calculateSleepHours();

    // UI direct door naar klaar-stap; opslag fire-and-forget.
    if (mounted) {
      setState(() => _step = 3);
    }

    try {
      await ensureInitialized();

      // 1. Slaap-log vullen/actualiseren: bedtijd van gisteren behouden,
      //    opstaantijd + wakker-minuten van nu. Merge-preserving!
      if (_bedTimeYesterday != null) {
        await db.insertSleepLog(_formattedToday, _bedTimeYesterday!, wakeStr, _awakeMinutes);
      }

      // 2. daily_log merge-preserving bijwerken (q4 + slaap)
      final existing = await db.getDailyLog(_formattedToday);
      final log = existing != null ? Map<String, dynamic>.from(existing) : <String, dynamic>{};
      log['date'] = _formattedToday;
      if (sleepHours != null) log['uren_slaap'] = sleepHours;
      log['awake_minutes'] = _awakeMinutes;
      log['q4_slaapbehoefte'] = _q4;
      await db.upsertDailyLog(log);

      // 3. SRM "Opstaan" met P-score tegen de doeltijd
      final settings = await db.getSettings();
      final targetStr = settings?['target_opstaan']?.toString();
      int pScore = 1;
      if (targetStr != null && targetStr.isNotEmpty && targetStr != '--:--') {
        final tParts = targetStr.split(':');
        final targetMinutes = (int.tryParse(tParts[0]) ?? 0) * 60 + (int.tryParse(tParts[1]) ?? 0);
        final wakeMinutes = (_wakeTime!.hour * 60) + _wakeTime!.minute;
        final diff = (wakeMinutes - targetMinutes).abs();
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
      await db.insertSrmActivity(_formattedToday, 'Opstaan', wakeStr, pScore, null,
          targetTime: (targetStr != null && targetStr != '--:--') ? targetStr : null);

      // 4. mood_assessment updaten (merge: alleen q4 behouden)
      final existingAssessment = await db.getMoodAssessment(_formattedToday);
      final assessment = existingAssessment != null
          ? Map<String, dynamic>.from(existingAssessment)
          : <String, dynamic>{};
      assessment['date'] = _formattedToday;
      assessment['q4_slaapbehoefte'] = _q4;
      await db.upsertMoodAssessment(assessment);
    } catch (e) {
      AppLogger.error('MorningCheckIn: opslaan mislukt', error: e);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ochtendCheckIn),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SafeArea(
        child: _step >= 3 ? _buildKlaar(context) : _buildVraag(context),
      ),
    );
  }

  Widget _buildVraag(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        LinearProgressIndicator(
          value: (_step + 1) / 3,
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
                          if (_step == 2) {
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
                    _step == 2 ? l10n.stemmingsCheckAfronden : l10n.stemmingsCheckVolgende,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _canProceed() {
    switch (_step) {
      case 0:
        return _wakeTime != null;
      case 1:
        return true; // wakker-gelegen heeft default 0
      case 2:
        return _q4 != null;
      default:
        return false;
    }
  }

  Widget _stepContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (_step) {
      case 0:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.wb_sunny, size: 56, color: AppTheme.primaryTeal),
            const SizedBox(height: 16),
            Text(
              l10n.ochtendHoeLaatOpgestaan,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (_bedTimeYesterday != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.ochtendBedtijdGisteren(_bedTimeYesterday!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
            const SizedBox(height: 24),
            Center(
              child: OutlinedButton.icon(
                onPressed: _pickWakeTime,
                icon: const Icon(Icons.access_time),
                label: Text(
                  _wakeTime != null ? _formatTimeOfDay(_wakeTime!) : l10n.tikOmTijdInTeStellen,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ),
          ],
        );
      case 1:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.bedtime, size: 56, color: AppTheme.primaryTeal),
            const SizedBox(height: 16),
            Text(
              l10n.wakkerGelegen,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Text(
                    '$_awakeMinutes',
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700),
                  ),
                  Text(l10n.minuten, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [0, 5, 10, 15, 30, 45, 60, 90]
                        .map((m) => ChoiceChip(
                              label: Text('${m}m'),
                              selected: _awakeMinutes == m,
                              onSelected: (_) => setState(() => _awakeMinutes = m),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.nights_stay, size: 56, color: AppTheme.primaryTeal),
            const SizedBox(height: 16),
            Text(
              l10n.stemmingsCheckVraag4Titel,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _SlaapbehoefteOpties(
              selected: _q4,
              onChanged: (v) => setState(() => _q4 = v),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildKlaar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sleepHours = _calculateSleepHours();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: AppTheme.success),
            const SizedBox(height: 16),
            Text(
              l10n.ochtendCheckInKlaar,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (sleepHours != null) ...[
              Text(
                l10n.ochtendGeslapenUren(
                  sleepHours.floor(),
                  ((sleepHours - sleepHours.floor()) * 60).round(),
                ),
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.primaryTeal,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
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

/// Keuze-opties voor slaapbehoefte (q4) — zelfde schaal als de stemmingscheck.
class _SlaapbehoefteOpties extends StatelessWidget {
  final double? selected;
  final ValueChanged<double> onChanged;

  const _SlaapbehoefteOpties({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = <double>[-4, -3, -2, -1, 0, 1, 2, 3, 4];
    final labels = <double, String>{
      4: l10n.stemmingsCheckOptieSlaapGeen,
      3: l10n.stemmingsCheckOptieSlaapVerminderd,
      2: l10n.stemmingsCheckOptieSlaap1UurKorter,
      1: l10n.stemmingsCheckOptieSlaapTot1UurKorter,
      0: l10n.stemmingsCheckOptieNeutraal,
      -1: l10n.stemmingsCheckOptieSlaapNietZoGoed,
      -2: l10n.stemmingsCheckOptieSlaap12UurEerder,
      -3: l10n.stemmingsCheckOptieSlaapUrenEerder,
      -4: l10n.stemmingsCheckOptieSlaapNietTot,
    };
    return Column(
      children: options
          .map((v) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _OptieTile(
                  label: labels[v] ?? v.toString(),
                  value: v,
                  selected: selected == v,
                  onTap: () => onChanged(v),
                ),
              ))
          .toList(),
    );
  }
}

class _OptieTile extends StatelessWidget {
  final String label;
  final double value;
  final bool selected;
  final VoidCallback onTap;

  const _OptieTile({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = MoodAssessmentScorerColors.slaapbehoefteColor(value);
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

/// Kleuren voor de slaapbehoefte-schaal (zelfde logica als de stemmingscheck).
class MoodAssessmentScorerColors {
  static Color slaapbehoefteColor(double v) {
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
}