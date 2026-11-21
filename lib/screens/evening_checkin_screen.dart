import 'package:flutter/material.dart';
import '../utils/bipolar_tag_l10n.dart';
import '../generated/l10n/app_localizations.dart';
import '../service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/logger.dart';
import '../utils/mood_assessment_scorer.dart';
import '../utils/checkin_colors.dart';
import '../widgets/overzicht_rij.dart';
import '../services/notification_helper.dart';

/// Avond check-in: alles op één scrollbare pagina.
///
///  1. Stemming vandaag                    (q1, -4..+4)
///  2. Energie slider                      (q2, 0..100)
///  3. Energie-niveau                      (q3, -3..+3)
///  4. Belangrijke gebeurtenis + invloed   (q5, -4..+4)
///  5. Avondeten + bedtijd                 (SRM-tijden, optioneel)
///
/// Opslag: mood_assessment (q1/q2/q3/q5 merge), daily_log (stemming + bedtijd),
/// srm_activities (3 tijden + Naar bed met P-score), sleep-log (bedtijd).
class EveningCheckInScreen extends StatefulWidget {
  const EveningCheckInScreen({super.key, this.onClose, this.initialDate});

  final void Function(bool saved)? onClose;
  /// Optioneel: de datum waarvoor de check-in geldt (standaard vandaag).
  final String? initialDate;

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
  TimeOfDay? _avondeten;
  TimeOfDay? _bedTime;

  bool _isSaving = false;
  bool _toonFouten = false;
  final GlobalKey _q1Key = GlobalKey();
  final GlobalKey _q3Key = GlobalKey();
  final GlobalKey _q5Key = GlobalKey();
  bool _bekijkModus = false; // true = overzicht van opgeslagen waarden (read-only)
  bool _opslagGelukt = false; // uitslag van _opslaan; _sluiten meldt dit terug

  // Opgeslagen waarden voor het overzicht
  double? _opgeslagenQ1;
  double _opgeslagenQ2Slider = 50;
  double? _opgeslagenQ3;
  double? _opgeslagenQ5;
  TimeOfDay? _opgeslagenEersteContact;
  TimeOfDay? _opgeslagenWerkHobby;
  TimeOfDay? _opgeslagenAvondeten;
  TimeOfDay? _opgeslagenBedTime;
  int _opgeslagenScore = 0;

  static const _totaalStappen = 6;

  String get _formattedToday {
    if (widget.initialDate != null) return widget.initialDate!;
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _laadBestaandeData();
  }

  /// Bestaande avond check-in van vandaag laden voor de inkijk-modus.
  Future<void> _laadBestaandeData() async {
    try {
      await ensureInitialized();
      final assessment = await db.getMoodAssessment(_formattedToday);
      final log = await db.getDailyLog(_formattedToday);
      final srm = await db.getSrmActivities(_formattedToday);

      if (!mounted) return;
      double? toDouble(dynamic v) =>
          v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

      final q1 = toDouble(assessment?['q1_stemming']);
      final q3 = toDouble(assessment?['q3_energie_detail']);
      final q5 = toDouble(assessment?['q5_gebeurtenis']);
      final q2 = toDouble(assessment?['q2_energie_slider']);

      TimeOfDay? parseTime(String? s) {
        if (s == null || !s.contains(':')) return null;
        final p = s.split(':');
        return TimeOfDay(hour: int.tryParse(p[0]) ?? 0, minute: int.tryParse(p[1]) ?? 0);
      }
      TimeOfDay? srmTijd(String type) {
        for (final a in srm) {
          if (a['activity_type']?.toString() == type &&
              a['actual_time']?.toString().isNotEmpty == true) {
            return parseTime(a['actual_time'].toString());
          }
        }
        return null;
      }

      final heeftData = q1 != null && q3 != null;
      if (heeftData) {
        setState(() {
          _bekijkModus = true;
          _opgeslagenQ1 = q1;
          _opgeslagenQ3 = q3;
          _opgeslagenQ5 = q5;
          if (q2 != null) _opgeslagenQ2Slider = q2;
          if (assessment?['berekende_score'] is num) {
            _opgeslagenScore = (assessment!['berekende_score'] as num).toInt();
          }
          _opgeslagenEersteContact = srmTijd('Eerste contact');
          _opgeslagenWerkHobby = srmTijd('Werk / Hobby');
          _opgeslagenAvondeten = srmTijd('Avondeten');
          final bed = log?['bed_time']?.toString();
          _opgeslagenBedTime = parseTime(bed);
        });
      }
    } catch (e) {
      AppLogger.error('EveningCheckIn: bestaande data laden mislukt', error: e);
    }
  }

  /// Start de invulflow pre-filled met de opgeslagen waarden.
  void _startAanpassen() {
    setState(() {
      _bekijkModus = false;
      _q1 = _opgeslagenQ1;
      _q2Slider = _opgeslagenQ2Slider;
      _q3 = _opgeslagenQ3;
      _q5 = _opgeslagenQ5;
      _avondeten = _opgeslagenAvondeten;
      _bedTime = _opgeslagenBedTime;
      _step = 0;
    });
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

    // Opslaan wachten tot compleet (voor _sluiten → _loadData).
    // Het resultaat telt: bij een fout blijft de gebruiker op het
    // resultaatscherm maar met een foutmelding, en _sluiten meldt
    // "niet bewaard" zodat het dashboard niet ten onrechte groen kleurt.
    _opslagGelukt = await _opslaan(result, q4);
    if (!_opslagGelukt && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).fout('')),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<bool> _opslaan(MoodScoreResult result, double q4) async {
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
        'Avondeten': settings?['target_eten']?.toString(),
        'Naar bed': settings?['target_slapen']?.toString(),
      };
      final tijden = {
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
      // Vandaag is de avond check-in ingevuld — geen herinnering meer vandaag.
      try {
        await NotificationHelper.instance.rescheduleCheckinReminders();
      } catch (e) {
        AppLogger.error('Herplannen check-in herinnering mislukt', error: e);
      }
      return true;
    } catch (e) {
      AppLogger.error('EveningCheckIn: opslaan mislukt', error: e);
      return false;
    }
  }

  void _sluiten() {
    if (!mounted) return;
    if (widget.onClose != null) {
      widget.onClose!(_opslagGelukt);
    } else {
      Navigator.of(context).pop(_opslagGelukt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.avondCheckIn),
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SafeArea(
        child: _bekijkModus
            ? _buildOverzicht(context)
            : _step >= _totaalStappen
                ? _buildKlaar(context)
                : _buildForm(context),
      ),
    );
  }

  /// Overzichtsscherm: opgeslagen waarden van vandaag, read-only.
  Widget _buildOverzicht(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.nights_stay, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              l10n.avondCheckIn,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            Text(
              l10n.alIngevuldVandaag,
              style: TextStyle(fontSize: 13, color: AppTheme.success, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            if (_opgeslagenScore != 0) ...[
              const SizedBox(height: 8),
              Text(
                '${l10n.stemming}: $_opgeslagenScore',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _opgeslagenScore > 0 ? Colors.orange.shade700 : Colors.blue.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            if (_opgeslagenQ1 != null)
              OverzichtRij(
                icon: Icons.mood,
                label: l10n.stemmingsCheckVraag1Titel,
                value: _q1Label(l10n, _opgeslagenQ1!),
              ),
            OverzichtRij(
              icon: Icons.speed,
              label: l10n.stemmingsCheckVraag2Titel,
              value: '${_opgeslagenQ2Slider.round()}',
            ),
            if (_opgeslagenQ3 != null)
              OverzichtRij(
                icon: Icons.bolt,
                label: l10n.stemmingsCheckVraag3Titel,
                value: _q3Label(l10n, _opgeslagenQ3!),
              ),
            if (_opgeslagenQ5 != null)
              OverzichtRij(
                icon: Icons.event,
                label: l10n.stemmingsCheckVraag5Titel,
                value: _q5Label(l10n, _opgeslagenQ5!),
              ),
            if (_opgeslagenEersteContact != null)
              OverzichtRij(
                icon: Icons.people,
                label: l10n.avondEersteContact,
                value: _formatTimeOfDay(_opgeslagenEersteContact!),
              ),
            if (_opgeslagenWerkHobby != null)
              OverzichtRij(
                icon: Icons.work,
                label: l10n.avondWerkHobby,
                value: _formatTimeOfDay(_opgeslagenWerkHobby!),
              ),
            if (_opgeslagenAvondeten != null)
              OverzichtRij(
                icon: Icons.restaurant,
                label: l10n.avondAvondeten,
                value: _formatTimeOfDay(_opgeslagenAvondeten!),
              ),
            if (_opgeslagenBedTime != null)
              OverzichtRij(
                icon: Icons.bedtime,
                label: l10n.avondNaarBed,
                value: _formatTimeOfDay(_opgeslagenBedTime!),
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

  String _q1Label(AppLocalizations l10n, double v) {
    switch (v.toInt()) {
      case 4: return l10n.uiterstManisch;
      case 3: return l10n.ernstigManisch;
      case 2: return l10n.drukActief;
      case 1: return l10n.matigManisch;
      case 0: return l10n.stabielNeutraal;
      case -1: return l10n.somber;
      case -2: return l10n.lichtDepressief;
      case -3: return l10n.matigDepressief;
      case -4: return l10n.ernstigDepressief;
      default: return v.toString();
    }
  }

  String _q3Label(AppLocalizations l10n, double v) {
    switch (v.toInt()) {
      case 3: return l10n.stemmingsCheckOptieEnergieOvermatigNietKalm;
      case 2: return l10n.stemmingsCheckOptieEnergieOvermatigKalm;
      case 1: return l10n.stemmingsCheckOptieEnergieMeer;
      case 0: return l10n.stemmingsCheckOptieEnergieNormaal;
      case -1: return l10n.stemmingsCheckOptieEnergieEerderMo;
      case -2: return l10n.stemmingsCheckOptieEnergieBijnaAlles;
      case -3: return l10n.stemmingsCheckOptieEnergieNiets;
      default: return v.toString();
    }
  }

  String _q5Label(AppLocalizations l10n, double v) {
    switch (v.toInt()) {
      case 4: return l10n.stemmingsCheckOptieExtreemPositief;
      case 3: return l10n.stemmingsCheckOptiePositiefHoog;
      case 2: return l10n.stemmingsCheckOptiePositiefMatig;
      case 1: return l10n.stemmingsCheckOptieLichtPositief;
      case 0: return l10n.stemmingsCheckOptieNeutraal;
      case -1: return l10n.stemmingsCheckOptieLichtNegatief;
      case -2: return l10n.stemmingsCheckOptieNegatiefMatig;
      case -3: return l10n.stemmingsCheckOptieNegatiefHoog;
      case -4: return l10n.stemmingsCheckOptieExtreemNegatief;
      default: return v.toString();
    }
  }

  /// Sectie-kaart: icoon + titel (+ optionele subtitel) met de inhoud eronder.
  Widget _sectie({
    Key? key,
    required IconData icon,
    required String titel,
    String? subtitel,
    bool optioneel = false,
    bool fout = false,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final accent = theme.colorScheme.primary;
    return Container(
      key: key,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.largeRadius - 8),
        border: Border.all(
          color: fout ? AppTheme.danger(context) : AppTheme.cardBorderColor(context),
          width: fout ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titel,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (optioneel)
                Text(l10n.optioneelLabel,
                    style: TextStyle(fontSize: 12, color: AppTheme.secondaryText(context)))
              else if (fout)
                Text(l10n.veldVerplicht,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.danger(context))),
            ],
          ),
          if (subtitel != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitel,
              style: TextStyle(fontSize: 12, height: 1.35, color: AppTheme.secondaryText(context)),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  /// Tijd-invoer voor de optionele SRM-vragen, met wis-knop.
  Widget _tijdVeld({
    required TimeOfDay? tijd,
    required Future<void> Function() onPick,
    required VoidCallback onClear,
  }) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.access_time),
            label: Text(
              tijd != null ? _formatTimeOfDay(tijd) : l10n.tikOmTijdInTeStellen,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        if (tijd != null) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: l10n.wissen,
            onPressed: onClear,
          ),
        ],
      ],
    );
  }

  void _scrollNaarFout(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 350), alignment: 0.05);
    }
  }

  void _toonFoutSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).vulVerplichteVeldenIn)),
    );
  }

  /// Controleert de verplichte vragen en scrolt naar de eerste fout.
  Future<void> _pogingAfronden() async {
    setState(() => _toonFouten = true);
    if (_q1 == null) {
      _scrollNaarFout(_q1Key);
      _toonFoutSnack();
      return;
    }
    if (_q3 == null) {
      _scrollNaarFout(_q3Key);
      _toonFoutSnack();
      return;
    }
    if (_q5 == null) {
      _scrollNaarFout(_q5Key);
      _toonFoutSnack();
      return;
    }
    await _finish();
  }

  /// Eén doorlopende check-in-pagina met alle vragen onder elkaar.
  Widget _buildForm(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppTheme.screenPadding, 16, AppTheme.screenPadding, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectie(
                  key: _q1Key,
                  icon: Icons.sentiment_satisfied_alt,
                  titel: l10n.stemmingsCheckVraag1Titel,
                  fout: _toonFouten && _q1 == null,
                  child: _optieLijst(
                    options: _stemmingOpties(),
                    selected: _q1,
                    onChanged: (v) => setState(() => _q1 = v),
                  ),
                ),
                const SizedBox(height: 14),
                _sectie(
                  icon: Icons.bolt,
                  titel: l10n.stemmingsCheckVraag2Titel,
                  subtitel: l10n.stemmingsCheckVraag2Ondertitel,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.stemmingsCheckVraag2Links,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(l10n.stemmingsCheckVraag2Rechts,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
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
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectie(
                  key: _q3Key,
                  icon: Icons.bolt_outlined,
                  titel: l10n.stemmingsCheckVraag3Titel,
                  fout: _toonFouten && _q3 == null,
                  child: _optieLijst(
                    options: _energieOpties(),
                    selected: _q3,
                    onChanged: (v) => setState(() => _q3 = v),
                  ),
                ),
                const SizedBox(height: 14),
                _sectie(
                  key: _q5Key,
                  icon: Icons.event,
                  titel: l10n.stemmingsCheckVraag5Titel,
                  subtitel: l10n.stemmingsCheckVraag5Ondertitel,
                  fout: _toonFouten && _q5 == null,
                  child: _optieLijst(
                    options: _gebeurtenisOpties(),
                    selected: _q5,
                    onChanged: (v) => setState(() => _q5 = v),
                  ),
                ),
                const SizedBox(height: 14),
                _sectie(
                  icon: Icons.restaurant_outlined,
                  titel: l10n.avondAvondeten,
                  optioneel: true,
                  child: _tijdVeld(
                    tijd: _avondeten,
                    onPick: () async {
                      final picked = await _pickTime(_avondeten);
                      if (picked != null && mounted) setState(() => _avondeten = picked);
                    },
                    onClear: () => setState(() => _avondeten = null),
                  ),
                ),
                const SizedBox(height: 14),
                _sectie(
                  icon: Icons.bedtime,
                  titel: l10n.avondNaarBed,
                  optioneel: true,
                  child: _tijdVeld(
                    tijd: _bedTime,
                    onPick: () async {
                      final picked = await _pickTime(_bedTime);
                      if (picked != null && mounted) setState(() => _bedTime = picked);
                    },
                    onClear: () => setState(() => _bedTime = null),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding, 10, AppTheme.screenPadding, 10),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(color: AppTheme.cardBorderColor(context)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _pogingAfronden,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: theme.colorScheme.onPrimary),
                    )
                  : Text(
                      l10n.stemmingsCheckAfronden,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _optieLijst({
    required List<({String label, double value, Color color})> options,
    required double? selected,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      children: [
        for (final o in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptieTile(
              label: o.label,
              value: o.value,
              color: o.color,
              selected: selected == o.value,
              onTap: () => onChanged(o.value),
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
            Icon(Icons.nights_stay, size: 64, color: Theme.of(context).colorScheme.primary),
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
                      tag.localizedLabel(l10n),
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
      borderRadius: BorderRadius.circular(AppTheme.smallRadius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppTheme.smallRadius),
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