import 'package:flutter/material.dart';
import '../generated/l10n/app_localizations.dart';
import '../service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/checkin_colors.dart';
import '../widgets/overzicht_rij.dart';
import '../utils/logger.dart';

/// Ochtend check-in: 6 korte stappen die bij het opstaan horen.
///
///  1. Hoe laat stond je op?        (tijd — vult slaap + SRM "Opstaan" + P-score)
///  2. Wakker gelegen (minuten)     (samen met gisteravonds bedtijd → slaapduur)
///  3. Hoe heb je geslapen?         (kwaliteit 1..5, puur log — geen klinische score)
///  4. Slaapbehoefte                (q4 uit de stemmingscheck, -4..+4)
///  5. Eerste contact vandaag?      (tijd, optioneel — was avond-stap)
///  6. Werk/hobby begonnen?         (tijd, optioneel — was avond-stap)
///
/// Opslag:
///  - sleep log (bedtijd = gisteravond uit daily_log, wake = nu gekozen)
///  - daily_log merge-preserving: uren_slaap, awake_minutes, sleep_quality, q4
///  - SRM "Opstaan" met P-score tegen de doeltijd
class MorningCheckInScreen extends StatefulWidget {
  const MorningCheckInScreen({super.key, this.onClose, this.initialDate});

  final void Function(bool saved)? onClose;
  /// Optioneel: de datum waarvoor de check-in geldt (standaard vandaag).
  final String? initialDate;

  @override
  State<MorningCheckInScreen> createState() => _MorningCheckInScreenState();
}

class _MorningCheckInScreenState extends State<MorningCheckInScreen> {
  int _step = 0; // 0 = opstaantijd, 1 = wakker gelegen, 2 = hoe geslapen, 3 = slaapbehoefte, 4 = klaar
  TimeOfDay? _wakeTime;
  int _awakeMinutes = 0;
  int? _kwaliteit; // hoe geslapen, 1..5
  TimeOfDay? _eersteContact; // vandaag, optioneel (was avond-stap)
  TimeOfDay? _werkHobby; // vandaag, optioneel (was avond-stap)
  double? _q4; // slaapbehoefte -4..+4
  String? _bedTimeYesterday; // uit gisterens slaap-log
  bool _isSaving = false;
  bool _bekijkModus = false; // true = overzicht van opgeslagen waarden (read-only)
  TimeOfDay? _opgeslagenWakeTime;
  int _opgeslagenAwakeMinutes = 0;
  int? _opgeslagenKwaliteit;
  TimeOfDay? _opgeslagenEersteContact;
  TimeOfDay? _opgeslagenWerkHobby;
  double? _opgeslagenQ4;
  String? _opgeslagenBedTime;

  String get _formattedToday {
    if (widget.initialDate != null) return widget.initialDate!;
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadBedTimeYesterday();
    _laadBestaandeData();
  }

  /// Bestaande check-in van vandaag laden voor de inkijk-modus.
  /// Als er al data is → overzichtsscherm i.p.v. blanco invulflow.
  Future<void> _laadBestaandeData() async {
    try {
      await ensureInitialized();
      final log = await db.getDailyLog(_formattedToday);
      final assessment = await db.getMoodAssessment(_formattedToday);
      final srm = await db.getSrmActivities(_formattedToday);

      TimeOfDay? wakeTime;
      int awake = 0;
      double? q4;

      // Wake time uit SRM "Opstaan"
      for (final a in srm) {
        if (a['activity_type']?.toString() == 'Opstaan' &&
            a['actual_time']?.toString().isNotEmpty == true) {
          final parts = a['actual_time'].toString().split(':');
          wakeTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          );
          break;
        }
      }
      // Fallback: slaap-log
      if (wakeTime == null) {
        final sleep = await db.getSleepLog(_formattedToday);
        final wake = sleep?['wake_time']?.toString();
        if (wake != null && wake.contains(':')) {
          final parts = wake.split(':');
          wakeTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
        }
      }
      // Eerste contact + werk/hobby van vandaag (worden sinds kort in de
      // ochtend ingevuld; oudere dagen hebben ze via de avond-check-in).
      TimeOfDay? srmTijd(String type) {
        for (final a in srm) {
          if (a['activity_type']?.toString() == type &&
              a['actual_time']?.toString().isNotEmpty == true) {
            final parts = a['actual_time'].toString().split(':');
            return TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 0,
              minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
            );
          }
        }
        return null;
      }
      final awakeRaw = log?['awake_minutes'];
      if (awakeRaw is num) awake = awakeRaw.toInt();
      final q4Raw = assessment?['q4_slaapbehoefte'] ?? log?['q4_slaapbehoefte'];
      if (q4Raw is num) q4 = q4Raw.toDouble();
      final kwaliteitRaw = log?['sleep_quality'];
      int? kwaliteit;
      if (kwaliteitRaw is num) {
        final k = kwaliteitRaw.toInt();
        if (k >= 1 && k <= 5) kwaliteit = k;
      }

      final heeftData = wakeTime != null && q4 != null;
      if (mounted && heeftData) {
        setState(() {
          _bekijkModus = true;
          _opgeslagenWakeTime = wakeTime;
          _opgeslagenAwakeMinutes = awake;
          _opgeslagenKwaliteit = kwaliteit;
          _opgeslagenEersteContact = srmTijd('Eerste contact');
          _opgeslagenWerkHobby = srmTijd('Werk / Hobby');
          _opgeslagenQ4 = q4;
          _opgeslagenBedTime = _bedTimeYesterday;
        });
      }
    } catch (e) {
      AppLogger.error('MorningCheckIn: bestaande data laden mislukt', error: e);
    }
  }

  /// Start de invulflow pre-filled met de opgeslagen waarden.
  void _startAanpassen() {
    setState(() {
      _bekijkModus = false;
      _wakeTime = _opgeslagenWakeTime;
      _awakeMinutes = _opgeslagenAwakeMinutes;
      _kwaliteit = _opgeslagenKwaliteit;
      _eersteContact = _opgeslagenEersteContact;
      _werkHobby = _opgeslagenWerkHobby;
      _q4 = _opgeslagenQ4;
      _step = 0;
    });
  }

  /// Bedtijd van gisteravond ophalen (uit gisterens slaap-log of daily_log),
  /// zodat de slaapduur alvast berekend kan worden.
  Future<void> _loadBedTimeYesterday() async {
    try {
      await ensureInitialized();
      // Bedtijd vóór de GEKOZEN datum (initialDate), niet vóór 'nu'.
      // Anders wordt bij het aanpassen van een eerdere dag de
      // bedtijd van gisteren (nu-1) gebruikt en ontbreekt uren_slaap.
      final refDate = widget.initialDate != null
          ? DateTime.tryParse(widget.initialDate!) ?? DateTime.now()
          : DateTime.now();
      final yesterday = refDate.subtract(const Duration(days: 1));
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

  /// Generieke tijdkeuze voor de SRM-stappen (eerste contact, werk/hobby).
  Future<void> _pickTijd(TimeOfDay? huidige, ValueChanged<TimeOfDay> onPick) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: huidige ?? TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) onPick(picked);
  }

  /// Na een tijdkeuze (OK in de kiezer) meteen een stap verder, behalve op de
  /// laatste stap. Zo hoeft een tijdstip niet twee keer bevestigd te worden
  /// (OK én Volgende).
  void _gaVerder() {
    if (!mounted || _step >= 5) return;
    setState(() => _step += 1);
  }

  /// Eén tijdstip-stap: grote klokknop, geen eigen Volgende (zie _gaVerder).
  Widget _tijdStap(
    BuildContext context, {
    required IconData icon,
    required String titel,
    required TimeOfDay? tijd,
    required ValueChanged<TimeOfDay> onPick,
  }) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          titel,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => _pickTijd(tijd, onPick),
            icon: const Icon(Icons.access_time),
            label: Text(
              tijd != null ? _formatTimeOfDay(tijd) : l10n.tikOmTijdInTeStellen,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  /// P-score van een SRM-tijd tegen de doeltijd (zelfde staffel als overal).
  int _pScoreVoor(TimeOfDay tijd, String? targetStr) {
    if (targetStr == null || targetStr.isEmpty || targetStr == '--:--') return 1;
    final tParts = targetStr.split(':');
    final targetMinutes = (int.tryParse(tParts[0]) ?? 0) * 60 + (int.tryParse(tParts[1]) ?? 0);
    final diff = ((tijd.hour * 60) + tijd.minute - targetMinutes).abs();
    return diff <= 15 ? 5 : diff <= 30 ? 4 : diff <= 45 ? 3 : diff <= 60 ? 2 : 1;
  }

  Future<void> _finish() async {
    if (_wakeTime == null || _kwaliteit == null || _q4 == null || _isSaving) return;

    final wakeStr = _formatTimeOfDay(_wakeTime!);
    final sleepHours = _calculateSleepHours();

    if (mounted) {
      setState(() => _isSaving = true);
    }

    // Alleen bij ECHT gelukte opslag naar de klaar-stap. Eerst stond
    // `_step = 3` ook in het foutpad, waardoor een mislukte save toch een
    // vinkje toonde en de gebruiker dacht dat alles bewaard was.
    bool opgeslagen = false;
    Object? fout;
    try {
      await ensureInitialized();

      // Bereken P-score (voor stemming_hoog in daily_log)
      final settings = await db.getSettings();
      final targetStr = settings?['target_opstaan']?.toString();
      final pScore = _pScoreVoor(_wakeTime!, targetStr);

      // 1. Slaap-log vullen/actualiseren: bedtijd van gisteren behouden,
      //    opstaantijd + wakker-minuten van nu. Merge-preserving!
      if (_bedTimeYesterday != null) {
        await db.insertSleepLog(_formattedToday, _bedTimeYesterday!, wakeStr, _awakeMinutes);
      }

      // 2. daily_log merge-preserving bijwerken (q4 + slaap + stemming)
      final existing = await db.getDailyLog(_formattedToday);
      final log = existing != null ? Map<String, dynamic>.from(existing) : <String, dynamic>{};
      log['date'] = _formattedToday;
      if (sleepHours != null) log['uren_slaap'] = sleepHours;
      log['awake_minutes'] = _awakeMinutes;
      log['sleep_quality'] = _kwaliteit;
      log['q4_slaapbehoefte'] = _q4;
      // stemming_hoog: P-score (1-5) geschaald naar 0-10,
      // zodat de dagstatus-kaarten het groene vinkje tonen.
      log['stemming_hoog'] = pScore * 2;
      await db.upsertDailyLog(log);

      // 3. SRM "Opstaan" met P-score tegen de doeltijd
      await db.insertSrmActivity(_formattedToday, 'Opstaan', wakeStr, pScore, null,
          targetTime: (targetStr != null && targetStr != '--:--') ? targetStr : null);

      // 3b. Eerste contact + werk/hobby van VANDAAG (was avond-stap, nu hier
      //     optioneel). Alleen bij ingevulde tijd, met P-score tegen doeltijd.
      final targetContact = settings?['target_contact']?.toString();
      if (_eersteContact != null) {
        await db.insertSrmActivity(_formattedToday, 'Eerste contact',
            _formatTimeOfDay(_eersteContact!), _pScoreVoor(_eersteContact!, targetContact), null,
            targetTime: (targetContact != null && targetContact != '--:--') ? targetContact : null);
      }
      final targetWerk = settings?['target_werk']?.toString();
      if (_werkHobby != null) {
        await db.insertSrmActivity(_formattedToday, 'Werk / Hobby',
            _formatTimeOfDay(_werkHobby!), _pScoreVoor(_werkHobby!, targetWerk), null,
            targetTime: (targetWerk != null && targetWerk != '--:--') ? targetWerk : null);
      }

      // 4. mood_assessment updaten (merge: alleen q4 behouden)
      final existingAssessment = await db.getMoodAssessment(_formattedToday);
      final assessment = existingAssessment != null
          ? Map<String, dynamic>.from(existingAssessment)
          : <String, dynamic>{};
      assessment['date'] = _formattedToday;
      assessment['q4_slaapbehoefte'] = _q4;
      await db.upsertMoodAssessment(assessment);
      opgeslagen = true;
    } catch (e) {
      fout = e;
      AppLogger.error('MorningCheckIn: opslaan mislukt', error: e);
    }

    // Blijf bij een fout op het formulier met een melding, in plaats van
    // stil naar de klaar-stap te gaan (geen race meer, geen vals vinkje).
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (opgeslagen) {
      setState(() => _step = 6);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).fout(fout ?? '')),
          backgroundColor: AppTheme.error,
        ),
      );
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
    // Naadloos doorlopende donkere kop: geen gekleurd contrastvlak meer.
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
        titleSpacing: AppTheme.screenPadding,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.ochtendCheckIn,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!_bekijkModus && _step < 6)
              Text(
                l10n.ochtendStapVan(_step + 1, 6),
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondaryText(context),
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: _bekijkModus
            ? _buildOverzicht(context)
            : _step >= 6
                ? _buildKlaar(context)
                : _buildVraag(context),
      ),
    );
  }

  /// Overzichtsscherm: opgeslagen waarden van vandaag, read-only,
  /// met knop om alsnog aan te passen.
  Widget _buildOverzicht(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sleepHours = _calculateSleepHoursSaved();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.wb_sunny, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              l10n.ochtendCheckIn,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            Text(
              l10n.alIngevuldVandaag,
              style: TextStyle(fontSize: 13, color: AppTheme.success, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OverzichtRij(
              icon: Icons.access_time,
              label: l10n.ochtendHoeLaatOpgestaan,
              value: _opgeslagenWakeTime != null ? _formatTimeOfDay(_opgeslagenWakeTime!) : '-',
            ),
            if (_opgeslagenBedTime != null)
              OverzichtRij(
                icon: Icons.bedtime,
                label: l10n.bedtijdVorigeNacht,
                value: _opgeslagenBedTime!,
              ),
            OverzichtRij(
              icon: Icons.snooze,
              label: l10n.wakkerGelegen,
              value: '$_opgeslagenAwakeMinutes ${l10n.minuten}',
            ),
            if (_opgeslagenKwaliteit != null)
              OverzichtRij(
                icon: Icons.star_rounded,
                label: l10n.ochtendHoeGeslapen,
                value: _kwaliteitLabel(l10n, _opgeslagenKwaliteit!),
                accent: kwaliteitKleur(_opgeslagenKwaliteit!),
              ),
            if (_opgeslagenQ4 != null)
              OverzichtRij(
                icon: Icons.nights_stay,
                label: l10n.stemmingsCheckVraag4Titel,
                value: _q4Label(l10n, _opgeslagenQ4!),
                accent: MoodAssessmentScorerColors.slaapbehoefteColor(_opgeslagenQ4!),
              ),
            if (_opgeslagenEersteContact != null)
              OverzichtRij(
                icon: Icons.person_outline,
                label: l10n.avondEersteContact,
                value: _formatTimeOfDay(_opgeslagenEersteContact!),
              ),
            if (_opgeslagenWerkHobby != null)
              OverzichtRij(
                icon: Icons.work_outline,
                label: l10n.avondWerkHobby,
                value: _formatTimeOfDay(_opgeslagenWerkHobby!),
              ),
            if (sleepHours != null)
              OverzichtRij(
                icon: Icons.hotel,
                label: l10n.slaapduur,
                value: '${sleepHours.floor()}u ${((sleepHours - sleepHours.floor()) * 60).round()}m',
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _startAanpassen,
              icon: const Icon(Icons.edit),
              label: Text(l10n.aanpassen),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Slaapduur op basis van opgeslagen waarden (voor het overzicht).
  double? _calculateSleepHoursSaved() {
    if (_opgeslagenBedTime == null || _opgeslagenWakeTime == null) return null;
    try {
      final bedParts = _opgeslagenBedTime!.split(':');
      final bedMinutes = (int.parse(bedParts[0]) * 60) + int.parse(bedParts[1]);
      final wakeMinutes = (_opgeslagenWakeTime!.hour * 60) + _opgeslagenWakeTime!.minute;
      var total = wakeMinutes - bedMinutes - _opgeslagenAwakeMinutes;
      if (total <= 0) total += 24 * 60;
      return total / 60.0;
    } catch (_) {
      return null;
    }
  }

  String _q4Label(AppLocalizations l10n, double v) {
    switch (v.toInt()) {
      case 4: return l10n.stemmingsCheckOptieSlaapGeen;
      case 3: return l10n.stemmingsCheckOptieSlaapVerminderd;
      case 2: return l10n.stemmingsCheckOptieSlaap1UurKorter;
      case 1: return l10n.stemmingsCheckOptieSlaapTot1UurKorter;
      case 0: return l10n.stemmingsCheckOptieNeutraal;
      case -1: return l10n.stemmingsCheckOptieSlaapNietZoGoed;
      case -2: return l10n.stemmingsCheckOptieSlaap12UurEerder;
      case -3: return l10n.stemmingsCheckOptieSlaapUrenEerder;
      case -4: return l10n.stemmingsCheckOptieSlaapNietTot;
      default: return v.toString();
    }
  }

  /// Label bij een kwaliteitsscore (1..5).
  String _kwaliteitLabel(AppLocalizations l10n, int v) {
    switch (v) {
      case 1: return l10n.ochtendKwaliteit1;
      case 2: return l10n.ochtendKwaliteit2;
      case 3: return l10n.ochtendKwaliteit3;
      case 4: return l10n.ochtendKwaliteit4;
      case 5: return l10n.ochtendKwaliteit5;
      default: return v.toString();
    }
  }

  Widget _buildVraag(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      children: [
        LinearProgressIndicator(
          value: (_step + 1) / 6,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          valueColor: const AlwaysStoppedAnimation<Color>(CheckinAccent.teal),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppTheme.screenPadding, 20, AppTheme.screenPadding, 20),
            child: _stepContent(context),
          ),
        ),
        // Vaste onderbalk: knoppen blijven altijd binnen bereik.
        Container(
          padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding, 12, AppTheme.screenPadding, 12),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(color: CheckinAccent.unselectedBorder(theme.brightness)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                if (_step > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _step -= 1),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface,
                        side: BorderSide(
                            color: CheckinAccent.unselectedBorder(theme.brightness)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(l10n.stemmingsCheckVorige),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: _step > 0 ? 1 : 1,
                  child: ElevatedButton(
                    onPressed: _canProceed() && !_isSaving
                        ? () {
                            if (_step == 5) {
                              _finish();
                            } else {
                              setState(() => _step += 1);
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CheckinAccent.teal,
                      // Donkere tekst op het accent: wit haalt maar 1.79:1.
                      foregroundColor: CheckinAccent.onAccent,
                      disabledBackgroundColor:
                          CheckinAccent.teal.withValues(alpha: 0.30),
                      disabledForegroundColor:
                          CheckinAccent.onAccent.withValues(alpha: 0.60),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _step == 5 ? l10n.stemmingsCheckAfronden : l10n.stemmingsCheckVolgende,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
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
        return _kwaliteit != null;
      case 3:
        return _q4 != null;
      case 4:
        return true; // eerste contact optioneel
      case 5:
        return true; // werk/hobby optioneel
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
            Icon(Icons.wb_sunny, size: 56, color: Theme.of(context).colorScheme.primary),
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
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
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
            Icon(Icons.bedtime, size: 56, color: Theme.of(context).colorScheme.primary),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.star_rounded,
                      size: 18, color: Color(0xFFFFB300)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.ochtendHoeGeslapen,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _KwaliteitOpties(
              selected: _kwaliteit,
              onChanged: (v) => setState(() => _kwaliteit = v),
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compacte kop: maan-icoon naast de vraag i.p.v. een groot icoon
            // dat de kaarten naar beneden duwt.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CheckinAccent.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.nightlight_round,
                      size: 18, color: CheckinAccent.teal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.stemmingsCheckVraag4Titel,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.stemmingsCheckVraag4Ondertitel,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: AppTheme.secondaryText(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SlaapbehoefteOpties(
              selected: _q4,
              onChanged: (v) => setState(() => _q4 = v),
            ),
          ],
        );
      case 4:
        return _tijdStap(
          context,
          icon: Icons.person_outline,
          titel: l10n.avondEersteContact,
          tijd: _eersteContact,
          // Na OK meteen door: anders moet elk tijdstip twee keer
          // bevestigd worden (OK én Volgende).
          onPick: (t) {
            setState(() => _eersteContact = t);
            _gaVerder();
          },
        );
      case 5:
        return _tijdStap(
          context,
          icon: Icons.work_outline,
          titel: l10n.avondWerkHobby,
          tijd: _werkHobby,
          onPick: (t) => setState(() => _werkHobby = t),
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
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _sluiten,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: Text(l10n.stemmingsCheckSuccesDoorNaar),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kleur bij een slaapkwaliteitsscore (1..5): van rood via geel naar groen.
///
/// Puur presentatie — anders dan q4 stuurt deze score geen klinische drempels
/// aan. Top-level zodat tests de mapping kunnen bewaken.
Color kwaliteitKleur(int v) {
  switch (v) {
    case 1:
      return const Color(0xFFE53935);
    case 2:
      return const Color(0xFFFF9800);
    case 3:
      return const Color(0xFFFDD835);
    case 4:
      return const Color(0xFF66BB6A);
    case 5:
      return const Color(0xFF2E7D32);
    default:
      return Colors.grey;
  }
}

/// Keuze-opties voor slaapbehoefte (q4) — zelfde schaal als de stemmingscheck.
///
/// De schaal loopt -4..+4 en is klinisch betekenisvol: de scorer gebruikt
/// drempels op >=2 / >=3 (manie-signaal) en <=-2 (depressie-signaal). De waarden
/// en hun volgorde mogen dus NIET veranderen — alleen de presentatie.
class _SlaapbehoefteOpties extends StatelessWidget {
  final double? selected;
  final ValueChanged<double> onChanged;

  const _SlaapbehoefteOpties({required this.selected, required this.onChanged});

  /// Bouw het datamodel: score + korte categorienaam + volledige toelichting.
  List<SleepOption> _opties(AppLocalizations l10n) => [
        SleepOption(
          score: 4,
          label: l10n.ochtendSlaapKortPlus4,
          description: l10n.ochtendSlaapOptiePlus4,
        ),
        SleepOption(
          score: 3,
          label: l10n.ochtendSlaapKortPlus3,
          description: l10n.ochtendSlaapOptiePlus3,
        ),
        SleepOption(
          score: 2,
          label: l10n.ochtendSlaapKortPlus2,
          description: l10n.ochtendSlaapOptiePlus2,
        ),
        SleepOption(
          score: 1,
          label: l10n.ochtendSlaapKortPlus1,
          description: l10n.ochtendSlaapOptiePlus1,
        ),
        SleepOption(
          score: 0,
          label: l10n.stemmingsCheckOptieNeutraal,
          description: l10n.stemmingsCheckOptieNeutraal,
        ),
        SleepOption(
          score: -1,
          label: l10n.ochtendSlaapKortMin1,
          description: l10n.ochtendSlaapOptieMin1,
        ),
        SleepOption(
          score: -2,
          label: l10n.ochtendSlaapKortMin2,
          description: l10n.ochtendSlaapOptieMin2,
        ),
        SleepOption(
          score: -3,
          label: l10n.ochtendSlaapKortMin3,
          description: l10n.ochtendSlaapOptieMin3,
        ),
        SleepOption(
          score: -4,
          label: l10n.ochtendSlaapKortMin4,
          description: l10n.ochtendSlaapOptieMin4,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: _opties(l10n)
          .map((optie) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SleepOptionCard(
                  option: optie,
                  selected: selected == optie.score,
                  onTap: () => onChanged(optie.score.toDouble()),
                ),
              ))
          .toList(),
    );
  }
}

/// Keuze-opties voor "Hoe heb je geslapen" (1..5).
///
/// Zelfde kaartentaal als de slaapbehoefte, maar met een eigen meetschaal:
/// de badge toont het cijfer met een ster, in de kleur van het niveau.
class _KwaliteitOpties extends StatelessWidget {
  final int? selected;
  final ValueChanged<int> onChanged;

  const _KwaliteitOpties({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final labels = [
      l10n.ochtendKwaliteit1,
      l10n.ochtendKwaliteit2,
      l10n.ochtendKwaliteit3,
      l10n.ochtendKwaliteit4,
      l10n.ochtendKwaliteit5,
    ];
    final toelichting = [
      l10n.ochtendKwaliteitOmschrijving1,
      l10n.ochtendKwaliteitOmschrijving2,
      l10n.ochtendKwaliteitOmschrijving3,
      l10n.ochtendKwaliteitOmschrijving4,
      l10n.ochtendKwaliteitOmschrijving5,
    ];
    return Column(
      children: List.generate(5, (i) {
        final score = i + 1;
        final isGekozen = selected == score;
        final kleur = kwaliteitKleur(score);
        final vulling = MoodAssessmentScorerColors.badgeVulling(kleur);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            onTap: () => onChanged(score),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: isGekozen
                    ? kleur.withValues(alpha: 0.14)
                    : (brightness == Brightness.dark
                        ? CheckinAccent.unselectedDark
                        : Theme.of(context).cardColor),
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                border: Border.all(
                  color: isGekozen
                      ? kleur
                      : CheckinAccent.unselectedBorder(brightness),
                  width: isGekozen ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isGekozen ? vulling : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isGekozen
                            ? vulling
                            : kleur.withValues(alpha: 0.55),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: isGekozen
                              ? MoodAssessmentScorerColors.tekstOp(vulling)
                              : kleur,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$score',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isGekozen
                                ? MoodAssessmentScorerColors.tekstOp(vulling)
                                : (brightness == Brightness.dark
                                    ? Colors.white70
                                    : AppTheme.textMedium),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isGekozen ? FontWeight.w700 : FontWeight.w600,
                            color: brightness == Brightness.dark
                                ? Colors.white
                                : AppTheme.textCharcoal,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          toelichting[i],
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            color: brightness == Brightness.dark
                                ? Colors.white70
                                : AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Datamodel voor één optie in de slaapbehoefte-check-in.
///
/// [score] is de klinische waarde die naar de database gaat (q4_slaapbehoefte).
/// [label] is de korte categorienaam boven de toelichting.
/// [description] is de volledige uitleg zoals eerder in de lange ARB-string zat.
class SleepOption {
  final int score;
  final String label;
  final String description;

  const SleepOption({
    required this.score,
    required this.label,
    required this.description,
  });
}

/// Interactieve keuzekaart voor de slaapbehoefte.
///
/// Elke score toont zijn eigen kleur gedempt (badge-ring + tint; gevuld bij
/// selectie), zodat elk antwoord herkenbaar is. Knoppen en voortgang blijven
/// bij het ene rustige accent (teal): kleur = betekenis, teal = actie.
/// De geselecteerde kaart krijgt een score-tint, een 1.5px rand in de
/// scorekleur en een gevulde badge; de niet-geselecteerde een rustige kaart
/// met een score-getinte badge-ring.
class SleepOptionCard extends StatelessWidget {
  final SleepOption option;
  final bool selected;
  final VoidCallback onTap;

  const SleepOptionCard({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scoreKleur =
        MoodAssessmentScorerColors.slaapbehoefteColor(option.score.toDouble());
    final scoreText = MoodAssessmentScorerColors.scoreLabel(option.score.toDouble());

    return Semantics(
      button: true,
      selected: selected,
      label: '$scoreText, ${option.label}',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            // Geselecteerd: subtiele score-tint. Anders: rustige kaart.
            color: selected
                ? scoreKleur.withValues(alpha: 0.12)
                : (brightness == Brightness.dark
                    ? CheckinAccent.unselectedDark
                    : Theme.of(context).cardColor),
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            border: Border.all(
              color: selected
                  ? scoreKleur
                  : CheckinAccent.unselectedBorder(brightness),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScoreBadge(text: scoreText, selected: selected, kleur: scoreKleur),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: brightness == Brightness.dark
                            ? Colors.white
                            : AppTheme.textCharcoal,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      option.description,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: brightness == Brightness.dark
                            ? Colors.white70
                            : AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Score-badge links op de kaart. Ring altijd in de scorekleur, gevuld in de
/// scorekleur zodra de optie geselecteerd is, anders een rustige omtrek.
class _ScoreBadge extends StatelessWidget {
  final String text;
  final bool selected;
  final Color kleur;

  const _ScoreBadge({required this.text, required this.selected, required this.kleur});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final vulling = MoodAssessmentScorerColors.badgeVulling(kleur);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      constraints: const BoxConstraints(minWidth: 40),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? vulling : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? vulling : kleur.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: selected
              ? MoodAssessmentScorerColors.tekstOp(vulling)
              : (brightness == Brightness.dark
                  ? Colors.white70
                  : AppTheme.textMedium),
        ),
      ),
    );
  }
}

