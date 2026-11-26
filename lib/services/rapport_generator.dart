import '../service_locator.dart';
import 'rapport_strings.dart';

/// Alle databasegegevens die de rapport-secties gebruiken, plus de
///elperlogica om de periode consistent te hanteren.
class _PeriodData {
  final DateTime startDate;
  final DateTime endDate;
  final List<Map<String, dynamic>> dailyLogs;
  final List<Map<String, dynamic>> medicationConfigs;
  final Map<int, List<Map<String, dynamic>>> schedulesByMed;
  final Map<String, List<Map<String, dynamic>>> intakesByDate;

  _PeriodData({
    required this.startDate,
    required this.endDate,
    required this.dailyLogs,
    required this.medicationConfigs,
    required this.schedulesByMed,
    required this.intakesByDate,
  });

  /// Aantal kalenderdagen in de periode (start- en einddag tellen mee).
  int get days => DateTime.utc(endDate.year, endDate.month, endDate.day)
          .difference(DateTime.utc(startDate.year, startDate.month, startDate.day))
          .inDays +
      1;

  /// Alle dagen van de periode, oplopend. Ook hier via de DateTime-
  /// constructor, zodat de zomertijd-overgang de klok niet verzet.
  List<DateTime> get allDays => List<DateTime>.generate(
        days,
        (i) => DateTime(startDate.year, startDate.month, startDate.day + i),
      );

  List<Map<String, dynamic>> schedulesFor(int medId) =>
      schedulesByMed[medId] ?? const [];

  /// Staat er op [day] een dosis gepland voor dit schema?
  bool isScheduledOn(Map<String, dynamic> sched, DateTime day) {
    final days = (sched['days_of_week']?.toString() ?? '1,2,3,4,5,6,7')
        .split(',')
        .map(int.tryParse)
        .whereType<int>();
    return days.contains(day.weekday);
  }

  /// Hoe vaak is [medId] op [dateStr] ingenomen? (0 = niet ingenomen)
  int takenOn(int medId, String dateStr) {
    final rows = intakesByDate[dateStr] ?? const [];
    for (final r in rows) {
      if (_asInt(r['medication_id']) != medId) continue;
      final v = r['aantal_ingenomen'];
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
    }
    return 0;
  }

  /// Is dit middel actief (niet gestopt/verwijderd)?
  /// Uitgeschakelde middelen (deleted-vlag of een stopped_at in het verleden)
  /// horen niet thuis in het rapport als "actief schema" of in de
  /// therapietrouw-berekening: hun doses waren immers gestopt.
  static bool isActiveMedication(Map<String, dynamic> med) {
    final del = med['deleted'];
    if (del == 1 || del == '1' || del == true) return false;
    final stopped = med['stopped_at']?.toString();
    if (stopped != null && stopped.isNotEmpty) {
      final d = DateTime.tryParse(stopped);
      if (d != null && !d.isAfter(DateTime.now())) return false;
    }
    return true;
  }

  /// Sleutel voor ontdubbeling: naam + dosis + eenheid + vast/PRN + tijden.
  /// Twee precies dezelfde invoeren (bijv. na een verwijder-/herinvoer-cyclus)
  /// leveren zo één regel op in het rapport.
  String dedupKey(Map<String, dynamic> med) {
    final id = _asInt(med['id']);
    final name = (med['naam'] ?? '').toString().trim().toLowerCase();
    final dosis = (med['dosering'] ?? '').toString().trim().toLowerCase();
    final eenheid = (med['eenheid'] ?? '').toString().trim().toLowerCase();
    final times = schedulesFor(id)
        .map((s) => (s['reminder_time'] ?? '').toString())
        .toList()
      ..sort();
    final soort = times.isEmpty ? 'prn' : 'vast';
    return '$name|$dosis|$eenheid|$soort|${times.join(',')}';
  }

  /// Actieve medicatie, ontdubbeld op [dedupKey].
  List<Map<String, dynamic>> get activeMedications {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final med in medicationConfigs) {
      if (!isActiveMedication(med)) continue;
      if (seen.add(dedupKey(med))) result.add(med);
    }
    return result;
  }

  /// Groepssleutel voor hetzelfde middel over config-varianten heen
  /// (naam + dosis + eenheid, genormaliseerd). Eén middel kan meerdere
  /// configs hebben — bijv. een gestopte en later opnieuw aangemaakte —
  /// en de inname-historie kan over beide verdeeld zijn.
  static String medGroupKey(Map<String, dynamic> med) {
    final name = (med['naam'] ?? '').toString().trim().toLowerCase();
    final dosis =
        (med['dosering'] ?? '').toString().trim().toLowerCase().replaceAll(',', '.');
    final eenheid = (med['eenheid'] ?? '').toString().trim().toLowerCase();
    return '$name|$dosis|$eenheid';
  }

  Map<String, List<int>>? _groupIdsCache;

  /// Alle config-ids van hetzelfde middel (incl. gestopte varianten).
  List<int> mergedIds(int id) {
    _groupIdsCache ??= () {
      final map = <String, List<int>>{};
      for (final med in medicationConfigs) {
        map.putIfAbsent(medGroupKey(med), () => []).add(_asInt(med['id']));
      }
      return map;
    }();
    for (final entry in _groupIdsCache!.entries) {
      if (entry.value.contains(id)) return entry.value;
    }
    return [id];
  }

  /// Innames op [dateStr], onafhankelijk van aan welke config-variant ze
  /// hangen. Telt als 'ingenomen' zodra minimaal één variant een inname meldt.
  int takenOnMerged(int medId, String dateStr) {
    final rows = intakesByDate[dateStr] ?? const [];
    final ids = mergedIds(medId).toSet();
    for (final r in rows) {
      if (!ids.contains(_asInt(r['medication_id']))) continue;
      final v = r['aantal_ingenomen'];
      final n = v is int ? v : int.tryParse('$v') ?? 0;
      if (n > 0) return n;
    }
    return 0;
  }

  /// Alle config-groepen (zelfde middel), inclusief gestopte varianten.
  List<List<Map<String, dynamic>>> get medicationGroups {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final med in medicationConfigs) {
      groups.putIfAbsent(medGroupKey(med), () => []).add(med);
    }
    return groups.values.toList();
  }

  /// Eerste dag zonder inname (stopdatum), of null als het middel loopt.
  DateTime? stopDateOf(Map<String, dynamic> med) {
    final raw = med['stopped_at']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  bool _isDeleted(Map<String, dynamic> med) {
    final del = med['deleted'];
    return del == 1 || del == '1' || del == true;
  }

  /// Dosis-tijdstippen die op [day] voor deze groep gelden. Een gestopte
  /// config telt t/m de dag vóór de stopdatum; oudere stops zonder datum
  /// (legacy) tellen niet mee.
  List<String> doseTimesOn(List<Map<String, dynamic>> group, DateTime day) {
    final times = <String>{};
    for (final med in group) {
      final stop = stopDateOf(med);
      if (stop != null && !day.isBefore(stop)) continue;
      if (stop == null && _isDeleted(med)) continue;
      for (final sched in schedulesFor(_asInt(med['id']))) {
        if (!isScheduledOn(sched, day)) continue;
        final t = (sched['reminder_time'] ?? '').toString();
        if (t.isNotEmpty) times.add(t);
      }
    }
    return times.toList()..sort();
  }

  /// De dagelijkse stemming van [day], of null als die niet is vastgelegd.
  ///
  /// Dit is de ENIGE stemmingsbron voor alle rapport-secties (ook Slaap vs
  /// Stemming): `daily_logs.stemming_hoog`, gekoppeld op `yyyy-MM-dd`.
  /// Waarden buiten −5..+5 zijn geen stemming — oude ochtend-check-ins
  /// schreven daar P-score×2 (2..10) in — en gelden als ontbrekend.
  double? moodOn(DateTime day) {
    final log = dailyLogs
        .where((l) => l['date'] == _dateStr(day))
        .firstOrNull;
    if (log == null) return null;
    final v = _extractDouble(log['stemming_hoog']);
    if (v == null || v < -5 || v > 5) return null;
    return v;
  }

  /// Slaapduur van [day], of null. Alleen positieve waarden gelden als
  /// geldige slaap (0 of negatief = niet ingevuld), net als in de samenvatting.
  double? sleepOn(DateTime day) {
    final log = dailyLogs
        .where((l) => l['date'] == _dateStr(day))
        .firstOrNull;
    if (log == null) return null;
    final uren = _extractDouble(log['sleep_hours']) ??
        _extractDouble(log['uren_slaap']);
    if (uren == null || uren <= 0) return null;
    return uren;
  }
}

/// Totals uit het weekoverzicht, hergebruikt in de samenvatting.
/// Eén gecomprimeerd blok van aaneengesloten dagen met dezelfde dosis.
class _DoseBlock {
  _DoseBlock(this.start, this.end, this.days, this.dose);
  DateTime start;
  DateTime end;
  int days;
  final String dose;
}

class _WeeklyTotals {
  double totalMood = 0;
  int moodCount = 0;
  double totalSleep = 0;
  int sleepCount = 0;
  double totalPScore = 0;
  int pScoreDays = 0;
  int takenCount = 0;
  int intakeCount = 0;

  /// Dagen met enige gebruikersinvoer (stemming, slaap of gelogd anker).
  int activeDays = 0;
  int calendarDays = 0;

  /// Staan er vandaag nog geplande doses open (tijdstip nog niet verstreken)?
  bool todayHasOpenDoses = false;

  /// Zijn er in de periode überhaupt doses ingepland (ook zonder dat er al
  /// een aan de beurt was)? Dan tonen we 0/0 i.p.v. de regel weg te laten.
  bool hasScheduledDoses = false;

  /// Telt de medicatietelling vandaag mee (er is vandaag een dosis
  /// ingenomen) of alleen t/m gisteravond?
  bool medicationCutoffIsToday = true;

  /// Ligt de rapportperiode (deels) op of na vandaag? Alleen dan is een
  /// 't/m vandaag'- of 't/m gisteravond'-label zinvol.
  bool periodIncludesToday = true;
}

/// Generates comprehensive reports for bipolar disorder management
/// Life Chart Method (LCM) style for healthcare providers
class RapportGenerator {
  static final RapportGenerator instance = RapportGenerator._();
  RapportGenerator._();

  /// Weergavenaam van een middel: trailing spaces weg en de eerste letter
  /// automatisch een hoofdletter. Zonder dit levert gebruikersinvoer
  /// ("Lurasidon ", "lithium ") kapotte Markdown en inconsistente
  /// hoofdletters op.
  static String formatMedName(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return '';
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  /// Start van de rapportperiode: exact [days] kalenderdagen, met de
  /// einddag als laatste dag. `days - 1` omdat zowel de eerste als de
  /// laatste dag meetellen — 14 dagen betekent 13 dagen terug, niet 14.
  ///
  /// De verschuiving gaat bewust via de DateTime-constructor en niet via
  /// `Duration(days: ...)`: over de zomertijd-overgang heen duurt een dag
  /// 23 of 25 uur, waardoor `subtract` de klok een uur verzet en de
  /// datumdatum `01:00` in plaats van `00:00` wordt.
  static DateTime periodStart(DateTime end, int days) {
    return DateTime(end.year, end.month, end.day - (days - 1));
  }

  /// De weken van de periode, nieuwste week eerst. Elke week loopt van
  /// maandag tot zondag en wordt afgeknipt op de periodegrenzen, zodat het
  /// weekoverzicht exact dezelfde dagen bestrijkt als de header.
  static List<List<DateTime>> periodWeeks(DateTime start, DateTime end) {
    final days = end.difference(start).inDays + 1;
    final weeks = <List<DateTime>>[];
    for (int w = 0; w * 7 < days; w++) {
      final weekEnd = DateTime(end.year, end.month, end.day - (7 * w));
      final weekStart =
          DateTime(weekEnd.year, weekEnd.month, weekEnd.day - 6);
      final from = weekStart.isBefore(start) ? start : weekStart;
      final to = weekEnd.isAfter(end) ? end : weekEnd;
      final week = <DateTime>[];
      for (int i = 6; i >= 0; i--) {
        final d = DateTime(weekEnd.year, weekEnd.month, weekEnd.day - i);
        if (d.isBefore(from) || d.isAfter(to)) continue;
        week.add(d);
      }
      if (week.isNotEmpty) weeks.add(week);
    }
    return weeks;
  }

  /// Generate a full Life Chart Method (LCM) report as markdown
  /// Bouwt het LCM-rapport.
  ///
  /// [now], [startDate] en [endDate] zijn optioneel en alleen bedoeld voor
  /// tests: standaard worden de werkelijke datum en een periode van [days]
  /// dagen gebruikt.
  Future<String> generateLCMReport({
    int days = 30,
    String? localeCode,
    DateTime? now,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final s = localeCode != null
        ? RapportStrings.withLocale(localeCode)
        : RapportStrings();
    final generatedAt = now ?? DateTime.now();
    final eind = endDate ?? DateTime(generatedAt.year, generatedAt.month, generatedAt.day);
    final start = startDate ?? periodStart(eind, days);
    // Kalenderdagen via UTC-datums: over de zomertijdovergang heen is het
    // verschil anders 23 uur en zou .inDays één dag tekort tellen.
    final periodeDagen = DateTime.utc(eind.year, eind.month, eind.day)
            .difference(DateTime.utc(start.year, start.month, start.day))
            .inDays +
        1;
    final startStr = _dateStr(start);
    final endStr = _dateStr(eind);

    final buf = StringBuffer();
    await _buildHeader(buf, s, start, eind, generatedAt);

    final period = await _loadPeriodData(start, eind);

    // Medicatie-cutoff. Vandaag telt alleen mee als er vandaag al een dosis
    // is ingenomen; anders rekenen we — net als het label 't/m gisteravond'
    // — tot en met gisteren. Zo tellen samenvatting, weekoverzicht en het
    // medicatieverloop exact dezelfde doses.
    final vandaag = DateTime(generatedAt.year, generatedAt.month, generatedAt.day);
    final periodeBevatVandaag = !eind.isBefore(vandaag);
    // Alleen vaste (geplande) middelen bepalen de cutoff: een PRN-inname
    // vandaag mag de telling van de vaste doses niet naar 't/m vandaag'
    // verschuiven.
    final vandaagGenomen = period.medicationGroups.any((groep) {
      final heeftSchema = groep.any((m) =>
          period.schedulesFor(_asInt(m['id'])).isNotEmpty);
      if (!heeftSchema) return false;
      return period.takenOnMerged(_asInt(groep.first['id']), _dateStr(vandaag)) > 0;
    });
    final cutoffIsToday = !periodeBevatVandaag || vandaagGenomen;
    final medNow = cutoffIsToday
        ? generatedAt
        : DateTime(generatedAt.year, generatedAt.month, generatedAt.day - 1, 23, 59);

    final srmRange = await db.getSrmActivitiesRange(startStr, endStr);
    final srmByDate = <String, List<Map<String, dynamic>>>{};
    for (final a in srmRange) {
      final d = a['date']?.toString() ?? '';
      srmByDate.putIfAbsent(d, () => []).add(a);
    }
    final pScores = _dailyPScores(srmByDate);
    final totals = _computeTotals(
      period,
      pScores,
      medNow,
      periodeDagen,
      cutoffIsToday: cutoffIsToday,
      periodIncludesToday: periodeBevatVandaag,
    );
    _buildSummary(buf, s, totals);                     // 2. Samenvatting
    await _buildWeeklyOverview(buf, s, period, pScores, medNow); // 3. Weekoverzicht
    await _buildMedicationSection(buf, s, period, medNow); // 4. Medicatie
    await _buildMedicationSchema(buf, s, period);      // 5. Mediciatieschema
    await _buildDagboek(buf, s, startStr, endStr);     // 6. Dagboek
    _buildCorrelation(buf, s, period, medNow);         // 7. Correlatie: medicatie-trouw
    _buildSleepMoodCorrelation(buf, s, period);        // 7. Correlatie: slaap vs stemming
    await _buildMoodCheck(buf, s, startStr, endStr);   // 8. Stemmingscheck (alleen bij data)
    await _buildEpisodes(buf, s, period);
    await _buildProdromalWarnings(buf, s, periodeDagen);
    await _buildCrisisPlan(buf, s);

    buf.writeln('---');
    buf.writeln(s.footer);

    return buf.toString();
  }

  // === HEADER ===

  Future<void> _buildHeader(
    StringBuffer buf,
    RapportStrings s,
    DateTime startDate,
    DateTime endDate,
    DateTime now,
  ) async {
    buf.writeln(s.lifeChartTitle);
    buf.writeln();
    buf.writeln(s.disclaimer);
    buf.writeln();
    buf.writeln(
        '${s.period} ${_formatNL(startDate)} ${s.to} ${_formatNL(endDate)}');
    buf.writeln(
        '${s.generated} ${_formatNL(now)} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');
    buf.writeln();

    // Settings
    final settings = await db.getSettings();
    if (settings != null && settings['username'] != null) {
      buf.writeln('**${s.patientLabel}:** ${settings['username']}');
      buf.writeln();
    }
  }

  // === 1. STEMMINGSCHECK (5 VAGEN) — COMPACTE SECTIE ===

  Future<void> _buildMoodCheck(
    StringBuffer buf,
    RapportStrings s,
    String startStr,
    String endStr,
  ) async {
    final assessments = await db.getMoodAssessmentRange(startStr, endStr);
    if (assessments.isEmpty) return;

    // Gemiddelden per vraag
    double sumQ1 = 0, sumQ3 = 0, sumQ4 = 0, sumQ5 = 0;
    double sumRaw = 0;
    int nQ1 = 0, nQ3 = 0, nQ4 = 0, nQ5 = 0, nRaw = 0;
    final flagCounts = <String, int>{};
    for (final a in assessments) {
      final v1 = _extractDouble(a['q1_stemming']);
      final v3 = _extractDouble(a['q3_energie_detail']);
      final v4 = _extractDouble(a['q4_slaapbehoefte']);
      final v5 = _extractDouble(a['q5_gebeurtenis']);
      final raw =
          _extractDouble(a['gewogen_score']) ?? _extractDouble(a['berekende_score']);
      if (v1 != null) {
        sumQ1 += v1;
        nQ1++;
      }
      if (v3 != null) {
        sumQ3 += v3;
        nQ3++;
      }
      if (v4 != null) {
        sumQ4 += v4;
        nQ4++;
      }
      if (v5 != null) {
        sumQ5 += v5;
        nQ5++;
      }
      if (raw != null) {
        sumRaw += raw;
        nRaw++;
      }
      final flags = (a['flags_json'] as String?) ?? '';
      if (flags.isNotEmpty) {
        for (final f in flags.split(',')) {
          if (f.trim().isEmpty) continue;
          flagCounts[f] = (flagCounts[f] ?? 0) + 1;
        }
      }
    }

    buf.writeln('## ${s.moodCheckTitle} — $nQ1 ${s.intakeMoments(nQ1)}');
    buf.writeln();
    buf.writeln('| ${s.metric} | ${s.average} |');
    buf.writeln('|---------|-----------|');
    if (nQ1 > 0) buf.writeln('| **${s.mood}** (−4 ${s.to} +4) | ${_fmt(sumQ1 / nQ1)} |');
    if (nQ3 > 0) {
      buf.writeln('| **${s.energyLevel}** (−3 ${s.to} +3) | ${_fmt(sumQ3 / nQ3)} |');
    }
    if (nQ4 > 0) {
      buf.writeln('| **${s.sleepNeed}** (−4 ${s.to} +4) | ${_fmt(sumQ4 / nQ4)} |');
    }
    if (nQ5 > 0) {
      buf.writeln('| **${s.importantEvent}** (−4 ${s.to} +4) | ${_fmt(sumQ5 / nQ5)} |');
    }
    if (nRaw > 0) {
      buf.writeln(
          '| **${s.calculatedMood}** (−5 ${s.to} +5) | ${_fmt(sumRaw / nRaw)} |');
    }
    buf.writeln();

    // Bipolaire analyse-signalen (alleen als er signalen zijn)
    final signalLines = <String>[];
    for (final entry in flagCounts.entries) {
      final label = s.flagLabel(entry.key);
      if (label == null) continue;
      final pct = (entry.value * 100 / assessments.length).round();
      signalLines.add('- **$label**: ${entry.value}× ($pct%)');
    }
    if (signalLines.isNotEmpty) {
      buf.writeln('**${s.analysisSignalsTitle}:**');
      buf.writeln();
      buf.writeln(signalLines.join('\n'));
      buf.writeln();
    }
    // Losstaande meting: de 5-vragen stemmingcheck is een apart
    // instrument van de dagelijkse stemming die in het
    // weekoverzicht staat — de twee zijn niet rechtstreeks
    // vergelijkbaar.
    buf.writeln(s.moodCheckNote);
    buf.writeln();
  }

  /// Is deze dosis op [date] om [scheduledTime] ("HH:mm") al aan de beurt
  /// ten opzichte van [now]?
  /// - vorige dagen: altijd true
  /// - toekomstige dagen: altijd false
  /// - vandaag: alleen als het tijdstip is verstreken
  static bool isDoseDue({
    required DateTime date,
    required String? scheduledTime,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    if (target.isBefore(today)) return true;
    if (target.isAfter(today)) return false;
    final parts = (scheduledTime ?? '').split(':');
    final hour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 23) : 23;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 59) : 59;
    final due = DateTime(date.year, date.month, date.day, hour, minute);
    return now.isAfter(due);
  }

  ({int expected, int taken}) _countGroupDoses(
    _PeriodData period,
    DateTime day,
    List<Map<String, dynamic>> group,
    DateTime now,
  ) {
    final anyId = _asInt(group.first['id']);
    final takenToday = period.takenOnMerged(anyId, _dateStr(day)) > 0;
    final times = period.doseTimesOn(group, day);
    var expected = 0, taken = 0;
    for (final t in times) {
      if (takenToday) {
        expected++;
        taken++;
      } else if (isDoseDue(date: day, scheduledTime: t, now: now)) {
        expected++;
      }
    }
    return (expected: expected, taken: taken);
  }

  // === PERIOEDATA ===

  Future<_PeriodData> _loadPeriodData(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startStr = _dateStr(startDate);
    final endStr = _dateStr(endDate);

    final dailyLogs = await db.getDailyLogs();
    final medicationConfigs = await db.getMedicationConfigsAll();
    final medicationSchedules = await db.getMedicationSchedules();
    final intakeRange = await db.getMedicationIntakeRange(startStr, endStr);

    // Per dag een map medicatie_id -> intake-rijen, voor een kalender-gebaseerde
    // adherence-berekening (ook niet-gelogde dagen tellen mee).
    final intakesByDate = <String, List<Map<String, dynamic>>>{};
    for (final r in intakeRange) {
      final d = r['date']?.toString() ?? '';
      intakesByDate.putIfAbsent(d, () => []).add(r);
    }

    final schedulesByMed = <int, List<Map<String, dynamic>>>{};
    for (final med in medicationConfigs) {
      final id = _asInt(med['id']);
      schedulesByMed[id] = medicationSchedules
          .where((s) => _asInt(s['medication_id']) == id)
          .toList();
    }

    return _PeriodData(
      startDate: startDate,
      endDate: endDate,
      dailyLogs: dailyLogs,
      medicationConfigs: medicationConfigs,
      schedulesByMed: schedulesByMed,
      intakesByDate: intakesByDate,
    );
  }

  /// P-scores per dag (gemiddelde van de P-scores van die dag).
  /// Muteert niets; bedoeld voor aggregatie.
  /// Alleen ankers die daadwerkelijk zijn vastgelegd tellen mee: een
  /// P-score zonder `actual_time` is een gepland/leeg anker en vertegen-
  /// woordigt geen waargenomen dag. De huidige dag telt dus alleen mee als
  /// er vandaag al een anker is gelogd.
  Map<String, double> _dailyPScores(Map<String, List<Map<String, dynamic>>> srmByDate) {
    final result = <String, double>{};
    srmByDate.forEach((date, acts) {
      double sum = 0;
      int n = 0;
      for (final a in acts) {
        final ps = a['p_score'];
        if (ps == null) continue;
        final tijd = (a['actual_time'] ?? '').toString().trim();
        if (tijd.isEmpty) continue; // niet gelogd anker
        sum += ps is int ? ps.toDouble() : double.tryParse('$ps') ?? 0;
        n++;
      }
      if (n > 0) result[date] = sum / n;
    });
    return result;
  }

  /// Aggregeert de totaalcijfers voor de samenvattingstabel. Aparte pass
  /// zodat de samenvatting bovenaan het rapport kan staan.
  _WeeklyTotals _computeTotals(
    _PeriodData period,
    Map<String, double> pScores,
    DateTime now,
    int periodeDagen, {
    bool cutoffIsToday = true,
    bool periodIncludesToday = true,
  }) {
    final totals = _WeeklyTotals();
    totals.calendarDays = periodeDagen;
    totals.medicationCutoffIsToday = cutoffIsToday;
    totals.periodIncludesToday = periodIncludesToday;
    for (final d in period.allDays) {
      final dateStr = _dateStr(d);

      final mood = period.moodOn(d);
      if (mood != null) {
        totals.totalMood += mood;
        totals.moodCount++;
      }
      final sleep = period.sleepOn(d);
      if (sleep != null) {
        totals.totalSleep += sleep;
        totals.sleepCount++;
      }
      final pScore = pScores[dateStr];
      if (pScore != null) {
        totals.totalPScore += pScore;
        totals.pScoreDays++;
      }
      // Actieve dag: enige invoer (stemming, slaap of gelogd anker). Een
      // lege kalenderdag — inclusief een nog niet ingevulde vandaag —
      // telt niet mee in de gemiddelden.
      if (mood != null || sleep != null || pScore != null) {
        totals.activeDays++;
      }
      for (final group in period.medicationGroups) {
        final tijden = period.doseTimesOn(group, d);
        if (tijden.isNotEmpty) totals.hasScheduledDoses = true;
        final dose = _countGroupDoses(period, d, group, now);
        totals.intakeCount += dose.expected;
        totals.takenCount += dose.taken;
      }
    }
    // Zijn er vandaag nog doses waarvan de tijd nog niet verstreken is?
    final vandaag = DateTime(now.year, now.month, now.day);
    for (final group in period.medicationGroups) {
      for (final t in period.doseTimesOn(group, vandaag)) {
        if (!isDoseDue(date: vandaag, scheduledTime: t, now: now)) {
          totals.todayHasOpenDoses = true;
          break;
        }
      }
      if (totals.todayHasOpenDoses) break;
    }
    return totals;
  }

  // === 2. WEEKOVERZICHT ===

  Future<void> _buildWeeklyOverview(
    StringBuffer buf,
    RapportStrings s,
    _PeriodData period,
    Map<String, double> pScores,
    DateTime now,
  ) async {
    // Dagboek-entries per dag, voor de "Notities / Ankers"-kolom
    final dagboek = await db.getDagboekRange(
      _dateStr(period.startDate),
      _dateStr(period.endDate),
    );
    final dagboekByDate = <String, List<Map<String, dynamic>>>{};
    for (final e in dagboek) {
      final d = e['date']?.toString() ?? '';
      if (d.isEmpty) continue;
      dagboekByDate.putIfAbsent(d, () => []).add(e);
    }

    buf.writeln('## ${s.weeklyOverview}');
    buf.writeln();
    buf.writeln(
        '| ${s.week} | ${s.avgMood} | ${s.avgSleep} | ${s.avgPScore} | ${s.medication} | ${s.weekAnchors} |');
    buf.writeln('|------|--------------|-----------|-------------|-----------|---------------|');

    // Loop per week (nieuwste week eerst). De weken bestrijken exact de
    // rapportperiode: dezelfde grenzen als de header en de samenvatting.
    for (final week in periodWeeks(period.startDate, period.endDate)) {
      double wMood = 0;
      int wMoodN = 0;
      double wSleep = 0;
      int wSleepN = 0;
      double wP = 0;
      int wPN = 0;
      int wTaken = 0;
      int wIntake = 0;

      for (final d in week) {
        final dateStr = _dateStr(d);

        final mood = period.moodOn(d);
        if (mood != null) {
          wMood += mood;
          wMoodN++;
        }
        final sleep = period.sleepOn(d);
        if (sleep != null) {
          wSleep += sleep;
          wSleepN++;
        }

        // Zelfde P-score-bron en -regels als de samenvatting.
        final pScore = pScores[dateStr];
        if (pScore != null) {
          wP += pScore;
          wPN++;
        }

        // Medicatie: verwachte doses (alleen verstreken óf al ingenomen).
        for (final group in period.medicationGroups) {
          final dose = _countGroupDoses(period, d, group, now);
          wIntake += dose.expected;
          wTaken += dose.taken;
        }
      }

      final weekStart = week.first;
      final weekEnd = week.last;
      final weekLabel =
          '${RapportStrings.fmtDatumKort(weekStart)} ${s.dateRangeJoiner} ${RapportStrings.fmtDatumKort(weekEnd)}';
      final moodStr = wMoodN > 0 ? RapportStrings.fmt1(wMood / wMoodN) : '-';
      final sleepStr = wSleepN > 0 ? s.formatHours(wSleep / wSleepN) : '-';
      final pStr = wPN > 0 ? RapportStrings.fmt1(wP / wPN) : '-';
      final medStr = wIntake > 0 ? '$wTaken/$wIntake' : '-';

      // Notities/ankers: aantal entries, gemiddelde score, en de dagen
      // met een lage score (<= 2) als expliciete ankerpunten.
      final anchorEntries = <Map<String, dynamic>>[];
      for (final d in week) {
        anchorEntries.addAll(dagboekByDate[_dateStr(d)] ?? const []);
      }
      String anchorStr = '–';
      if (anchorEntries.isNotEmpty) {
        double scoreSum = 0;
        int scoreN = 0;
        final lageDagen = <String>{};
        for (final e in anchorEntries) {
          final sc = _extractDouble(e['score']);
          if (sc != null) {
            scoreSum += sc;
            scoreN++;
            if (sc <= 2) {
              final dStr = e['date']?.toString() ?? '';
              if (dStr.length >= 10) {
                lageDagen.add(RapportStrings.fmtDatumKortStr(dStr));
              }
            }
          }
        }
        anchorStr = scoreN > 0
            ? '${s.notitieCount(anchorEntries.length)} (gem ${RapportStrings.fmt1(scoreSum / scoreN)})'
            : s.notitieCount(anchorEntries.length);
        if (lageDagen.isNotEmpty) {
          anchorStr += ' · ⚠ ${lageDagen.join(', ')}';
        }
      }
      buf.writeln('| $weekLabel | $moodStr | $sleepStr | $pStr | $medStr | $anchorStr |');
    }

    buf.writeln();
    buf.writeln('---');
    buf.writeln();
  }

  // === CORRELATIE ANALYSE (Medication vs Mood) ===

  void _buildCorrelation(
    StringBuffer buf,
    RapportStrings s,
    _PeriodData period,
    DateTime now,
  ) {
    double highAdhMood = 0, lowAdhMood = 0;
    int highAdhCount = 0, lowAdhCount = 0;

    for (final d in period.allDays.reversed) {
      // Zelfde bron en datum-sleutel als Slaap vs Stemming: moodOn() leest
      // daily_logs.stemming_hoog op yyyy-MM-dd. Dagen zonder (geldige)
      // stemming tellen niet mee in n.
      final mood = period.moodOn(d);
      if (mood == null) continue;

      // Adherence for this day (due-aware; lege dagen tellen niet mee).
      int dTaken = 0, dExpected = 0;
      for (final group in period.medicationGroups) {
        final dose = _countGroupDoses(period, d, group, now);
        dTaken += dose.taken;
        dExpected += dose.expected;
      }
      if (dExpected == 0) continue;

      final pct = dTaken * 100 / dExpected;
      if (pct >= 90) {
        highAdhMood += mood;
        highAdhCount++;
      } else if (pct < 70) {
        lowAdhMood += mood;
        lowAdhCount++;
      }
    }

    buf.writeln('## ${s.correlationsTitle}');
    buf.writeln();
    buf.writeln('### ${s.correlationTitle}');
    buf.writeln();
    if (highAdhCount > 0 && lowAdhCount > 0) {
      buf.writeln(s.correlationHighAdherence(highAdhMood / highAdhCount, highAdhCount));
      buf.writeln(s.correlationLowAdherence(lowAdhMood / lowAdhCount, lowAdhCount));
      final diff =
          (highAdhMood / highAdhCount) - (lowAdhMood / lowAdhCount);
      buf.writeln();
      buf.writeln(s.correlationDiff(diff));
    } else if (highAdhCount > 0) {
      buf.writeln(s.correlationHighOnly(highAdhMood / highAdhCount, highAdhCount));
    } else if (lowAdhCount > 0) {
      buf.writeln(s.correlationLowOnly(lowAdhMood / lowAdhCount, lowAdhCount));
    } else {
      buf.writeln(s.correlationNoHighData);
      buf.writeln(s.correlationNoLowData);
    }
    buf.writeln();
  }

  /// Slaap vs stemming: vergelijkt de gemiddelde stemming op dagen met
  /// korte slaap (<6 uur) met dagen met voldoende slaap (>=6 uur).
  void _buildSleepMoodCorrelation(
    StringBuffer buf,
    RapportStrings s,
    _PeriodData period,
  ) {
    double shortSum = 0, longSum = 0;
    int shortCount = 0, longCount = 0;
    int activeDays = 0;

    // Alleen dagen met zowel geldige stemming als geldige slaap (> 0) doen
    // mee. Elke dag valt in precies één bucket (< 6 uur of >= 6 uur), dus
    // shortCount + longCount == het aantal gepaarde dagen.
    for (final d in period.allDays) {
      final mood = period.moodOn(d);
      final sleep = period.sleepOn(d);
      if (mood != null || sleep != null) activeDays++;
      if (mood == null) continue;
      if (sleep == null) continue;
      if (sleep < 6.0) {
        shortSum += mood;
        shortCount++;
      } else {
        longSum += mood;
        longCount++;
      }
    }
    final pairedCount = shortCount + longCount;

    buf.writeln('### ${s.sleepMoodTitle}');
    buf.writeln();
    if (shortCount > 0) {
      buf.writeln(s.sleepMoodShortSleep(shortSum / shortCount, shortCount));
    } else {
      buf.writeln(s.sleepMoodShortNoData);
    }
    if (longCount > 0) {
      buf.writeln(s.sleepMoodLongSleep(longSum / longCount, longCount));
    } else {
      buf.writeln(s.sleepMoodLongNoData);
    }
    if (shortCount > 0 && longCount > 0) {
      buf.writeln();
      buf.writeln(s.correlationDiff((longSum / longCount) - (shortSum / shortCount)));
    }
    if (pairedCount > 0) {
      buf.writeln();
      buf.writeln(s.sleepMoodPaired(pairedCount, activeDays));
    }
    buf.writeln();
  }

  // === 3. SAMENVATTING ===

  void _buildSummary(
    StringBuffer buf,
    RapportStrings s,
    _WeeklyTotals totals,
  ) {
    buf.writeln('## ${s.summaryTitle}');
    buf.writeln();
    buf.writeln('| ${s.summaryMetric} | ${s.summaryValue} |');
    buf.writeln('|---------|--------|');
    buf.writeln(
        '| **${s.daysWithData}** | ${s.dagenVanKalender(totals.activeDays, totals.calendarDays)} |');
    if (totals.moodCount > 0) {
      buf.writeln(
          '| **${s.avgMoodLong}** | ${RapportStrings.fmt1(totals.totalMood / totals.moodCount)} (-5 ${s.to} +5, n=${totals.moodCount}) |');
    }
    if (totals.sleepCount > 0) {
      buf.writeln(
          '| **${s.avgSleepDuration}** | ${s.formatHours(totals.totalSleep / totals.sleepCount)} (n=${totals.sleepCount}) |');
    }
    if (totals.pScoreDays > 0) {
      final avgP = totals.totalPScore / totals.pScoreDays;
      buf.writeln(
          '| **${s.avgPScore}** | ${RapportStrings.fmt1(avgP)} / 5 (SRT: ${(avgP / 5 * 100).round()}%, n=${totals.pScoreDays}) |');
    }
    if (totals.intakeCount > 0) {
      final pct = (totals.takenCount * 100 / totals.intakeCount).round();
      final suffix = (totals.periodIncludesToday && totals.calendarDays > 1)
          ? ', ${totals.medicationCutoffIsToday ? s.dosesUntilToday : s.dosesUntilYesterday}'
          : '';
      buf.writeln(
          '| **${s.medicationAdherence}** | ${totals.takenCount}/${totals.intakeCount} ${s.taken} ($pct%$suffix) |');
    } else if (totals.hasScheduledDoses) {
      // Nog geen enkele dosis aan de beurt (bijv. rapport vóór de eerste
      // innametijd): toon 0/0 zonder percentage (geen deling door nul).
      final suffix = (totals.periodIncludesToday && totals.calendarDays > 1)
          ? ' (${totals.medicationCutoffIsToday ? s.dosesUntilToday : s.dosesUntilYesterday})'
          : '';
      buf.writeln(
          '| **${s.medicationAdherence}** | 0/0 ${s.taken}$suffix |');
    }

    buf.writeln();
    buf.writeln(s.legendaLine);
    buf.writeln();
  }

  // === 3. DAGBOEK ===

  Future<void> _buildDagboek(
    StringBuffer buf,
    RapportStrings s,
    String startStr,
    String endStr,
  ) async {
    final dagboekEntries = await db.getDagboekRange(startStr, endStr);
    if (dagboekEntries.isEmpty) return;

    double totalScore = 0;
    int scoreCount = 0;
    final scoreCounts = <int, int>{};
    for (final entry in dagboekEntries) {
      final sc = _extractDouble(entry['score']);
      if (sc != null) {
        totalScore += sc;
        scoreCount++;
        scoreCounts[sc.toInt()] = (scoreCounts[sc.toInt()] ?? 0) + 1;
      }
    }
    buf.writeln('## ${s.dagboekTitle}');
    buf.writeln();
    if (scoreCount > 0) {
      final breakdown = (scoreCounts.keys.toList()..sort((a, b) => b.compareTo(a)))
          .map((score) => '${scoreCounts[score]}×$score')
          .join(', ');
      buf.writeln(
          '> **${s.dagboekGemiddeldeLabel}:** ${RapportStrings.fmt1(totalScore / scoreCount)} ($breakdown) · **${s.dagboekAantalLabel}:** ${dagboekEntries.length}');
      buf.writeln();
    }
    for (final entry in dagboekEntries.reversed) {
      final dateStr = RapportStrings.fmtDatumStr(entry['date']?.toString() ?? '?');
      final tekst = entry['tekst']?.toString() ?? '';
      final score = _extractDouble(entry['score']);
      if (tekst.isNotEmpty) {
        buf.writeln('- **${s.dagboekEntryLabel(dateStr, score)}**');
        buf.writeln('  > ${tekst.trim()}');
      }
    }
    buf.writeln();
  }

  // === 4. MEDICATIE — OVERZICHT & VERLOOP ===

  Future<void> _buildMedicationSection(
    StringBuffer buf,
    RapportStrings s,
    _PeriodData period,
    DateTime now,
  ) async {
    if (period.medicationConfigs.isEmpty) return;

    // Groepeer over ALLE configs (ook gestopte) op naam+dosis+eenheid:
    // inname-historie van een gestopte variant telt mee voor het middel.
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final med in period.medicationConfigs) {
      groups.putIfAbsent(_PeriodData.medGroupKey(med), () => []).add(med);
    }

    buf.writeln('## ${s.medOverviewTitle}');
    buf.writeln();

    final startStr = _dateStr(period.startDate);
    final endStr = _dateStr(period.endDate);

    final uitvoer = <({DateTime? laatste, List<String> regels})>[];

    for (final group in groups.values) {
      final actives = group.where(_PeriodData.isActiveMedication).toList();
      final ids = group.map((m) => _asInt(m['id'])).toList();

      // Innames van alle varianten samenvoegen per datum.
      final byDate = <String, Map<String, dynamic>>{};
      for (final id in ids) {
        final rows = await db.getMedicationIntakeForMedication(id);
        for (final r in rows) {
          final d = r['date']?.toString() ?? '';
          if (d.isEmpty) continue;
          if (d.compareTo(startStr) < 0 || d.compareTo(endStr) > 0) continue;
          final current = byDate[d];
          // Bij dubbele rijen wint de variant met de hoogste inname.
          if (current == null) {
            byDate[d] = r;
            continue;
          }
          final cur = _isTaken(current) ? 1 : 0;
          final neu = _isTaken(r) ? 1 : 0;
          if (neu > cur) byDate[d] = r;
        }
      }

      final dosis = RapportStrings.fmtDose(group.first['dosering']?.toString() ?? '');
      final eenheid = (group.first['eenheid']?.toString() ?? '').trim();
      final dosisLabel = [dosis, eenheid].where((x) => x.isNotEmpty).join(' ');
      final takenCount = byDate.values.where(_isTaken).length;

      final name = formatMedName(
          (actives.isNotEmpty ? actives.first : group.first)['naam']?.toString() ?? '');
      if (name.isEmpty) continue;

      // Schema's van álle varianten (gestopt of niet).
      final scheds = <Map<String, dynamic>>[];
      for (final m in group) {
        scheds.addAll(period.schedulesFor(_asInt(m['id'])));
      }

      final regels = <String>[];
      DateTime? laatste;

      // --- PRN (zo nodig): geen schema, dus geen verwachtingen ----------
      if (scheds.isEmpty) {
        final suffix = dosisLabel.isEmpty ? '' : ', $dosisLabel';
        if (actives.isNotEmpty) {
          final takenDates = byDate.entries
              .where((e) => _isTaken(e.value))
              .map((e) => e.key)
              .toList()
            ..sort();
          if (takenDates.isEmpty) {
            regels.add('- **$name** (PRN$suffix) — ${s.prnZeroTaken}');
          } else {
            laatste = DateTime.tryParse(takenDates.last);
            final data = takenDates.reversed.map(_shortDateStr).join(', ');
            regels.add(
                '- **$name** (PRN$suffix) — ${s.prnTakenOn(takenDates.length)} $data');
          }
        } else if (takenCount > 0) {
          final takenDays = byDate.entries
              .where((e) => _isTaken(e.value))
              .map((e) => e.key)
              .toList()
            ..sort();
          laatste = DateTime.tryParse(takenDays.last);
          regels.add(
              '- **$name** (${s.stoppedTag}) — $takenCount× ingenomen op: ${takenDays.reversed.map(_shortDateStr).join(', ')}');
        }
        if (regels.isNotEmpty) uitvoer.add((laatste: laatste, regels: regels));
        continue;
      }

      // --- Stopdatum: laatste dag vóór de stop telt nog mee --------------
      DateTime? stopDate;
      if (actives.isEmpty) {
        for (final m in group) {
          final d = period.stopDateOf(m);
          if (d != null && (stopDate == null || d.isAfter(stopDate))) stopDate = d;
        }
      }

      // --- Vast schema: telling per dosis, alleen verstreken/ingenomen ----
      final takenByDate = <DateTime, String>{};
      final missed = <DateTime>[];
      var expectedDoses = 0, takenDoses = 0;
      for (final d in period.allDays) {
        final row = byDate[_dateStr(d)];
        final takenToday = row != null && _isTaken(row);
        if (takenToday) {
          final raw = row['dosering']?.toString().trim() ?? '';
          takenByDate[d] =
              RapportStrings.fmtDose(raw.isNotEmpty ? raw : (dosis.isNotEmpty ? dosis : '?'));
        }
        for (final t in period.doseTimesOn(group, d)) {
          if (takenToday) {
            expectedDoses++;
            takenDoses++;
            continue;
          }
          if (isDoseDue(date: d, scheduledTime: t, now: now)) {
            expectedDoses++;
            if (!missed.contains(d)) missed.add(d);
          }
        }
      }

      if (expectedDoses == 0) {
        // (Vrijwel) geen verwachte doses in de periode: alleen innames tonen.
        if (takenCount == 0) continue;
        final takenDays = byDate.entries
            .where((e) => _isTaken(e.value))
            .map((e) => e.key)
            .toList()
          ..sort();
        laatste = DateTime.tryParse(takenDays.last);
        regels.add(
            '- **$name** (${s.stoppedTag}) — $takenCount× ingenomen op: ${takenDays.reversed.map(_shortDateStr).join(', ')}');
        uitvoer.add((laatste: laatste, regels: regels));
        continue;
      }

      final pct = (takenDoses * 100 / expectedDoses).round();
      final stopSuffix =
          stopDate == null ? '' : ' · ${s.stoppedOn(_shortDate(stopDate))}';
      regels.add(
          '- **$name** — $takenDoses/$expectedDoses ${s.medDoseCount(expectedDoses)} ($pct%)$stopSuffix');

      // Aaneengesloten dagen met dezelfde ingenomen dosering: één blok.
      final blokken = <_DoseBlock>[];
      for (final d in takenByDate.keys.toList()..sort()) {
        final dose = takenByDate[d];
        if (dose == null) continue; // gemiste dagen worden hieronder vermeld
        if (blokken.isNotEmpty) {
          final vorige = blokken.last;
          if (d.difference(vorige.end).inDays == 1 && vorige.dose == dose) {
            vorige.end = d;
            vorige.days++;
            continue;
          }
        }
        blokken.add(_DoseBlock(d, d, 1, dose));
      }

      // Alternerende reeksen (min. 4 dagen, strikt twee doses om-en-om)
      // samenvatten tot één regel.
      final weergave = <_DoseBlock>[];
      var i = 0;
      while (i < blokken.length) {
        final b = blokken[i];
        if (b.days != 1) {
          weergave.add(b);
          i++;
          continue;
        }
        final reeks = <_DoseBlock>[b];
        var j = i + 1;
        while (j < blokken.length) {
          final vorige = reeks.last;
          final volgende = blokken[j];
          if (volgende.days != 1) break;
          if (volgende.start.difference(vorige.end).inDays != 1) break;
          if (volgende.dose == vorige.dose) break;
          if (reeks.length >= 2 && volgende.dose != reeks[reeks.length - 2].dose) {
            break;
          }
          reeks.add(volgende);
          j++;
        }
        final uniekeDoses = reeks.map((x) => x.dose).toSet();
        if (reeks.length >= 4 && uniekeDoses.length == 2) {
          final twee = reeks.take(2).map((x) => x.dose).join(' / ');
          weergave.add(
              _DoseBlock(reeks.first.start, reeks.last.end, reeks.length, twee));
          i = j;
        } else {
          weergave.add(b);
          i++;
        }
      }

      // Nieuwste eerst, zodat de huidige dosering bovenaan staat.
      for (final b in weergave.reversed) {
        final isAfwisselend = b.dose.contains(' / ');
        final range = b.days == 1
            ? _shortDate(b.start)
            : '${_shortDate(b.start)} ${s.dateRangeJoiner} ${_shortDate(b.end)}';
        final unit = eenheid.isNotEmpty ? ' $eenheid' : '';
        final label = isAfwisselend
            ? '${b.dose}$unit ${s.alternatingWord}'
            : '${b.dose}$unit';
        regels.add('  - $range: $label (${b.days}/${b.days} ${s.takenWord})');
      }
      if (missed.isNotEmpty) {
        final aflopend = (missed.toList()..sort()).reversed;
        regels.add('  - ${s.missedOnLabel} ${aflopend.map(_shortDate).join(', ')}');
      }

      for (final k in byDate.keys) {
        final d = DateTime.tryParse(k);
        if (d != null && (laatste == null || d.isAfter(laatste))) laatste = d;
      }
      uitvoer.add((laatste: laatste, regels: regels));
    }

    // Middelen met de meest recente inname bovenaan.
    uitvoer.sort((a, b) {
      final da = a.laatste;
      final db = b.laatste;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    for (final e in uitvoer) {
      for (final r in e.regels) {
        buf.writeln(r);
      }
    }
    buf.writeln();
  }

  String _shortDate(DateTime d) => RapportStrings.fmtDatumKort(d);

  String _shortDateStr(String iso) => RapportStrings.fmtDatumKortStr(iso);

  bool _isTaken(Map<String, dynamic> row) {
    final v = row['aantal_ingenomen'];
    if (v is int) return v > 0;
    if (v is String) return (int.tryParse(v) ?? 0) > 0;
    return false;
  }

  // === 6. EPISODES ===

  Future<void> _buildEpisodes(
    StringBuffer buf,
    RapportStrings s,
    _PeriodData period,
  ) async {
    final episodes = await db.getEpisodes(limit: 20);
    final periodsInReport = episodes.where((e) {
      try {
        final sd = DateTime.parse(e['start_date'] as String);
        return sd.isAfter(
            period.startDate.subtract(const Duration(days: 30)));
      } catch (_) {
        return false;
      }
    }).toList();

    if (periodsInReport.isEmpty) return;

    buf.writeln('## ${s.episodesTitle}');
    buf.writeln();
    for (var ep in periodsInReport) {
      final type = s.episodeLabel(ep['episode_type'] as String);
      final start = ep['start_date'];
      final end = ep['end_date'] ?? s.ongoing;
      buf.writeln('- **$type**: ${_formatDateStr(start)} — ${_formatDateStr(end)}');
    }
    buf.writeln();
  }

  // === 7. ACTIEF MEDICATIESCHEMA ===

  Future<void> _buildMedicationSchema(
    StringBuffer buf,
    RapportStrings s,
    _PeriodData period,
  ) async {
    if (period.activeMedications.isEmpty) return;

    buf.writeln('## ${s.medSchema}');
    buf.writeln();
    for (final med in period.activeMedications) {
      final id = _asInt(med['id']);
      final name = formatMedName(med['naam']?.toString() ?? '');
      if (name.isEmpty) continue;
      final dosis = RapportStrings.fmtDose(med['dosering']?.toString() ?? '?');
      final eenheid = med['eenheid']?.toString() ?? '';
      final scheds = period.schedulesFor(id);
      final times = scheds
          .map((sched) => sched['reminder_time']?.toString() ?? '')
          .where((t) => t.isNotEmpty)
          .toSet()
          .join(', ');
      final soort = scheds.isEmpty ? s.medAsNeeded : s.medFixed;
      final tijden = times.isEmpty ? '' : ' — $times';
      buf.writeln('- **$name**: $dosis $eenheid — $soort$tijden');
      // Latest blood level
      final level = await db.getLatestMedicationLevel(id);
      if (level != null && level['bloedspiegel'] != null) {
        buf.writeln('  - ${s.lastBloodLevel}: ${level['bloedspiegel']} ${level['eenheid'] ?? 'mmol/L'} (${_formatDateStr(level['date'] as String)})');
      }
    }
    buf.writeln();
  }

  // === 8. PRODROMAL WARNINGS ===

  Future<void> _buildProdromalWarnings(
    StringBuffer buf,
    RapportStrings s,
    int days,
  ) async {
    final recentWarnings = await db.getRecentProdromalTrends(days);
    if (recentWarnings.isEmpty) return;
    final totalWarnings = recentWarnings.fold<int>(
        0, (sum, d) => sum + (d['warning_count'] as int? ?? 0));
    if (totalWarnings <= 0) return;

    buf.writeln('## ${s.warnings}');
    buf.writeln();
    buf.writeln(s.totalWarnings(totalWarnings));
    buf.writeln();
    for (var day in recentWarnings) {
      final count = day['warning_count'] as int? ?? 0;
      if (count > 0) {
        buf.writeln(
            '- ${RapportStrings.fmtDatumStr(day['date']?.toString() ?? '')}: ${s.warningsCount(count)}');
      }
    }
    buf.writeln();
  }

  // === 9. CRISIS PLAN ===

  Future<void> _buildCrisisPlan(StringBuffer buf, RapportStrings s) async {
    final crisisPlan = await db.getCrisisPlan();
    final filledPlans =
        crisisPlan.where((s) => (s['content'] as String?)?.isNotEmpty == true).toList();
    if (filledPlans.isEmpty) return;

    buf.writeln('## ${s.crisisPlan}');
    buf.writeln();
    for (final section in filledPlans) {
      buf.writeln('### ${s.sectionTitle(section['section'] as String)}');
      buf.writeln(section['content']);
      buf.writeln();
    }
  }

  /// Generate a compact JSON report for data sharing
  Future<Map<String, dynamic>> generateJSONReport({int days = 30}) async {
    final now = DateTime.now();
    final startDate = periodStart(now, days);
    final startStr = _dateStr(startDate);

    final report = <String, dynamic>{
      'report_type': 'ritme_lcm_report',
      'generated_at': now.toIso8601String(),
      'period_days': days,
    };

    // Settings (anonymized - only target times)
    final settings = await db.getSettings();
    if (settings != null) {
      report['target_times'] = {
        'opstaan': settings['target_opstaan'],
        'slapen': settings['target_slapen'],
        'contact': settings['target_contact'],
        'werk': settings['target_werk'],
        'eten': settings['target_eten'],
      };
    }

    // Daily logs
    final dailyLogs = await db.getDailyLogs();
    final filteredLogs = dailyLogs.where((l) {
      final d = l['date']?.toString() ?? '';
      return d.compareTo(startStr) >= 0;
    }).map((l) => {
      'date': l['date'],
      'stemming_hoog': l['stemming_hoog'],
      'stemming_laag': l['stemming_laag'],
      'gesplitste_stemming': l['gesplitste_stemming'],
      'sleep_hours': l['sleep_hours'],
      'life_event': l['life_event'],
      'alcohol_middelen': l['alcohol_middelen'],
    }).toList();
    report['daily_logs'] = filteredLogs;

    // Episodes
    final episodes = await db.getEpisodes(limit: 50);
    report['episodes'] = episodes;

    // Medication
    report['medication_configs'] = await db.getMedicationConfigsAll();

    return report;
  }

  /// Genereer een compacte CSV-export van de dagelijkse data. Handig voor
  /// Excel of andere analyse-tools; waarnemingen die niet ingevuld zijn
  /// blijven leeg (geen `0`), zodat lege-velden onderscheiden blijven.
  Future<String> generateCsvReport({int days = 30}) async {
    final now = DateTime.now();
    final startDate = periodStart(now, days);
    final startStr = _dateStr(startDate);

    final dailyLogs = await db.getDailyLogs();
    final rows = dailyLogs.where((l) {
      final d = l['date']?.toString() ?? '';
      return d.compareTo(startStr) >= 0;
    }).toList()
      ..sort((a, b) =>
          (a['date'] as String).compareTo(b['date'] as String));

    final buf = StringBuffer();
    buf.writeln('date,mood_high,split_mood,sleep_hours,life_event');

    for (final l in rows) {
      final date = l['date']?.toString() ?? '';
      final ho = _extractDouble(l['stemming_hoog']);
      final split = _extractDouble(l['gesplitste_stemming']);
      final sleep = _extractDouble(l['sleep_hours']) ??
          _extractDouble(l['uren_slaap']);
      final event = (l['life_event']?.toString() ?? '')
          .replaceAll('"', '""');
      buf.writeln([
        date,
        ho == null ? '' : _fmt(ho),
        split == null ? '' : _fmt(split),
        sleep == null ? '' : _fmt(sleep),
        '"$event"',
      ].join(','));
    }

    return buf.toString();
  }

  String _formatNL(DateTime d) => RapportStrings.fmtDatum(d);

  String _formatDateStr(String? dateStr) =>
      dateStr == null ? '...' : RapportStrings.fmtDatumStr(dateStr);

}

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int _asInt(dynamic val) {
  if (val is int) return val;
  if (val == null) return 0;
  return int.tryParse('$val') ?? 0;
}

double? _extractDouble(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val);
  return null;
}

String _fmt(double v) => RapportStrings.fmt1(v);

