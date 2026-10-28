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
  int get days => endDate.difference(startDate).inDays + 1;

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

  /// De dagelijkse stemming van [day], of null als die niet is vastgelegd.
  double? moodOn(DateTime day) {
    final log = dailyLogs
        .where((l) => l['date'] == _dateStr(day))
        .firstOrNull;
    if (log == null) return null;
    return _extractDouble(log['stemming_hoog']);
  }

  /// Slaapduur van [day], of null.
  double? sleepOn(DateTime day) {
    final log = dailyLogs
        .where((l) => l['date'] == _dateStr(day))
        .firstOrNull;
    if (log == null) return null;
    return _extractDouble(log['sleep_hours']) ??
        _extractDouble(log['uren_slaap']);
  }
}

/// Totals uit het weekoverzicht, hergebruikt in de samenvatting.
class _WeeklyTotals {
  double totalMood = 0;
  int moodCount = 0;
  double totalSleep = 0;
  int sleepCount = 0;
  double totalPScore = 0;
  int pScoreDays = 0;
  int takenCount = 0;
  int intakeCount = 0;
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
  Future<String> generateLCMReport({int days = 30, String? localeCode}) async {
    final s = localeCode != null
        ? RapportStrings.withLocale(localeCode)
        : RapportStrings();
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month, now.day);
    final startDate = periodStart(endDate, days);
    final startStr = _dateStr(startDate);
    final endStr = _dateStr(endDate);

    final buf = StringBuffer();
    await _buildHeader(buf, s, startDate, endDate, now);
    await _buildMoodCheck(buf, s, startStr, endStr);

    final period = await _loadPeriodData(startDate, endDate);
    final totals = await _buildWeeklyOverview(buf, s, period);
    _buildCorrelation(buf, s, period, now);
    _buildSummary(buf, s, period, totals);
    await _buildDagboek(buf, s, startStr, endStr);
    await _buildMedicationSection(buf, s, period);
    await _buildEpisodes(buf, s, period);
    await _buildMedicationSchema(buf, s, period);
    await _buildProdromalWarnings(buf, s, days);
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
        '${s.generated} ${_formatNL(now)} ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
    buf.writeln();

    // Settings
    final settings = await db.getSettings();
    if (settings != null && settings['username'] != null) {
      buf.writeln('**Patiënt:** ${settings['username']}');
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
    double sumQ1 = 0, sumQ2 = 0, sumQ3 = 0, sumQ4 = 0, sumQ5 = 0;
    double sumRaw = 0;
    int nQ1 = 0, nQ2 = 0, nQ3 = 0, nQ4 = 0, nQ5 = 0, nRaw = 0;
    final flagCounts = <String, int>{};
    for (final a in assessments) {
      final v1 = _extractDouble(a['q1_stemming']);
      final v2 = _extractDouble(a['q2_energie_slider']);
      final v3 = _extractDouble(a['q3_energie_detail']);
      final v4 = _extractDouble(a['q4_slaapbehoefte']);
      final v5 = _extractDouble(a['q5_gebeurtenis']);
      final raw =
          _extractDouble(a['gewogen_score']) ?? _extractDouble(a['berekende_score']);
      if (v1 != null) {
        sumQ1 += v1;
        nQ1++;
      }
      if (v2 != null) {
        sumQ2 += v2;
        nQ2++;
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

    buf.writeln('## ${s.moodCheckTitle} — $nQ1 ${s.intakeMoments}');
    buf.writeln();
    buf.writeln('| ${s.metric} | ${s.average} |');
    buf.writeln('|---------|-----------|');
    if (nQ1 > 0) buf.writeln('| **${s.mood}** (−4..+4) | ${_fmt(sumQ1 / nQ1)} |');
    if (nQ2 > 0) buf.writeln('| **${s.energy}** (0..100) | ${_fmt(sumQ2 / nQ2)} |');
    if (nQ3 > 0) {
      buf.writeln('| **${s.energyLevel}** (−3..+3) | ${_fmt(sumQ3 / nQ3)} |');
    }
    if (nQ4 > 0) {
      buf.writeln('| **${s.sleepNeed}** (−4..+4) | ${_fmt(sumQ4 / nQ4)} |');
    }
    if (nQ5 > 0) {
      buf.writeln('| **${s.importantEvent}** (−4..+4) | ${_fmt(sumQ5 / nQ5)} |');
    }
    if (nRaw > 0) {
      buf.writeln(
          '| **${s.calculatedMood}** (−5..+5) | ${_fmt(sumRaw / nRaw)} |');
    }
    buf.writeln();

    // Bipolaire analyse-signalen (alleen als er signalen zijn)
    final signalLines = <String>[];
    for (final entry in flagCounts.entries) {
      final label = s.flagLabel(entry.key);
      if (label == null) continue;
      final pct = (entry.value * 100 / assessments.length).round();
      signalLines.add('- **$label**: ${entry.value}× (${pct}%)');
    }
    if (signalLines.isNotEmpty) {
      buf.writeln('**Bipolaire analyse-signalen:**');
      buf.writeln();
      buf.writeln(signalLines.join('\n'));
      buf.writeln();
    }
    // Losstaande meting: de 5-vragen stemmingcheck is een apart
    // instrument van de dagelijkse stemming die in het
    // weekoverzicht staat — de twee zijn niet rechtstreeks
    // vergelijkbaar.
    buf.writeln(
        '_Opmerking: dit is de 5-vragen stemmingcheck, een apart instrument van de dagelijkse stemming-tracking (weekoverzicht)._');
    buf.writeln();
    buf.writeln('---');
    buf.writeln();
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

  // === 2. WEEKOVERZICHT ===

  Future<_WeeklyTotals> _buildWeeklyOverview(
    StringBuffer buf,
    RapportStrings s,
    _PeriodData period,
  ) async {
    final totals = _WeeklyTotals();

    // SRM activiteiten in bulk ophalen om N+1 queries te voorkomen
    final srmRange = await db.getSrmActivitiesRange(
      _dateStr(period.startDate),
      _dateStr(period.endDate),
    );
    final srmByDate = <String, List<Map<String, dynamic>>>{};
    for (final a in srmRange) {
      final d = a['date']?.toString() ?? '';
      srmByDate.putIfAbsent(d, () => []).add(a);
    }

    buf.writeln('## ${s.weeklyOverview}');
    buf.writeln();
    buf.writeln(
        '| ${s.week} | ${s.avgMood} | ${s.avgSleep} | ${s.avgPScore} | ${s.medication} |');
    buf.writeln('|------|--------------|-----------|-------------|-----------|');

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

        final srmActs = srmByDate[dateStr] ?? [];
        double pSum = 0;
        int pCount = 0;
        for (var a in srmActs) {
          final ps = a['p_score'];
          if (ps != null) {
            pSum += ps is int ? ps : int.tryParse('$ps') ?? 0;
            pCount++;
          }
        }
        if (pCount > 0) {
          wP += pSum / pCount;
          wPN++;
        }

        // Medicatie: per gepland schema één verwachte dosis.
        for (final med in period.medicationConfigs) {
          final id = _asInt(med['id']);
          final scheds = period.schedulesFor(id);
          if (scheds.isEmpty) continue;
          for (final sched in scheds) {
            if (!period.isScheduledOn(sched, d)) continue;
            wIntake++;
            if (period.takenOn(id, dateStr) > 0) wTaken++;
          }
        }
      }

      totals.takenCount += wTaken;
      totals.intakeCount += wIntake;

      final weekStart = week.first;
      final weekEnd = week.last;
      final weekLabel =
          '${weekStart.day}/${weekStart.month} – ${weekEnd.day}/${weekEnd.month}';
      final moodStr = wMoodN > 0 ? (wMood / wMoodN).toStringAsFixed(1) : '-';
      final sleepStr = wSleepN > 0 ? '${s.formatHours(wSleep / wSleepN)}' : '-';
      final pStr = wPN > 0 ? (wP / wPN).toStringAsFixed(1) : '-';
      final medStr = wIntake > 0 ? '$wTaken/$wIntake' : '-';
      buf.writeln('| $weekLabel | $moodStr | $sleepStr | $pStr | $medStr |');

      // Totaal-accumulatie voor de Samenvatting-sectie
      totals.totalMood += wMood;
      totals.moodCount += wMoodN;
      totals.totalSleep += wSleep;
      totals.sleepCount += wSleepN;
      totals.totalPScore += wP;
      totals.pScoreDays += wPN;
    }

    buf.writeln();
    buf.writeln('---');
    buf.writeln();

    return totals;
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
      final dateStr = _dateStr(d);

      // Mood for this day
      final mood = period.moodOn(d);
      if (mood == null) continue;

      // Adherence for this day
      int dTaken = 0, dExpected = 0;
      for (final med in period.medicationConfigs) {
        final id = _asInt(med['id']);
        for (final sched in period.schedulesFor(id)) {
          if (!period.isScheduledOn(sched, d)) continue;
          dExpected++;
          if (period.takenOn(id, dateStr) > 0) dTaken++;
        }
      }
      if (dExpected == 0) continue;

      // De huidige dag telt niet mee als de dag nog open staat: het
      // avondmedicijn is dan nog niet afgevinkt, dus de dag zou anders
      // ten onrechte als lage trouw (<70%) in de correlatie landen.
      if (_isSameDay(d, now) && _dayIsStillOpen(period, d, now)) continue;

      final pct = dTaken * 100 / dExpected;
      if (pct >= 90) {
        highAdhMood += mood;
        highAdhCount++;
      } else if (pct < 70) {
        lowAdhMood += mood;
        lowAdhCount++;
      }
    }

    buf.writeln('## ${s.correlationTitle}');
    buf.writeln();
    if (highAdhCount > 0 || lowAdhCount > 0) {
      if (highAdhCount > 0) {
        buf.writeln(s.correlationHighAdherence(highAdhMood / highAdhCount));
      }
      if (lowAdhCount > 0) {
        buf.writeln(s.correlationLowAdherence(lowAdhMood / lowAdhCount));
      }
      if (highAdhCount > 0 && lowAdhCount > 0) {
        final diff =
            (highAdhMood / highAdhCount) - (lowAdhMood / lowAdhCount);
        buf.writeln();
        buf.writeln(s.correlationDiff(diff));
      }
    } else {
      buf.writeln(s.correlationNoData);
    }
    buf.writeln();
  }

  /// Staat de dag [day] nog open? Dat is zo als er voor vandaag een dosis
  /// gepland staat waarvan het tijdstip nog niet verstreken is en die nog
  /// niet is afgevinkt.
  bool _dayIsStillOpen(_PeriodData period, DateTime day, DateTime now) {
    final dateStr = _dateStr(day);
    for (final med in period.medicationConfigs) {
      final id = _asInt(med['id']);
      for (final sched in period.schedulesFor(id)) {
        if (!period.isScheduledOn(sched, day)) continue;
        if (period.takenOn(id, dateStr) > 0) continue;
        final time = _parseTime(sched['reminder_time']?.toString());
        if (time == null) continue;
        final planned =
            DateTime(day.year, day.month, day.day, time.hour, time.minute);
        if (planned.isAfter(now)) return true;
      }
    }
    return false;
  }

  // === 3. SAMENVATTING ===

  void _buildSummary(
    StringBuffer buf,
    RapportStrings s,
    _PeriodData period,
    _WeeklyTotals totals,
  ) {
    buf.writeln('## 📈 Samenvatting');
    buf.writeln();
    buf.writeln('| Metriek | Waarde |');
    buf.writeln('|---------|--------|');
    buf.writeln('| **${s.daysWithData}** | ${totals.moodCount} |');
    if (totals.moodCount > 0) {
      buf.writeln(
          '| **${s.avgMoodLong}** | ${(totals.totalMood / totals.moodCount).toStringAsFixed(1)} (-5 ${s.to} +5) |');
    }
    if (totals.sleepCount > 0) {
      buf.writeln(
          '| **${s.avgSleepDuration}** | ${s.formatHours(totals.totalSleep / totals.sleepCount)} |');
    }
    if (totals.pScoreDays > 0) {
      final avgP = totals.totalPScore / totals.pScoreDays;
      buf.writeln(
          '| **${s.avgPScore}** | ${avgP.toStringAsFixed(1)} / 5 (SRT: ${(avgP / 5 * 100).round()}%) |');
    }
    if (totals.intakeCount > 0) {
      final pct = (totals.takenCount * 100 / totals.intakeCount).round();
      buf.writeln(
          '| **${s.medicationAdherence}** | ${totals.takenCount}/${totals.intakeCount} ${s.taken} ($pct%) |');
    }

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
      final distribution =
          scoreCounts.entries.map((e) => '${e.key}×${e.value}').join(', ');
      buf.writeln('| ${s.dagboekScore} | ${s.dagboekEntries} |');
      buf.writeln('|---------|--------|');
      buf.writeln(
          '| **${(totalScore / scoreCount).toStringAsFixed(1)}** ($distribution) | ${dagboekEntries.length} |');
      buf.writeln();
    }
    for (final entry in dagboekEntries.reversed) {
      final dateStr = entry['date']?.toString() ?? '?';
      final tekst = entry['tekst']?.toString() ?? '';
      final score = _extractDouble(entry['score']);
      if (tekst.isNotEmpty) {
        buf.writeln('- **${s.dagboekEntryLabel(dateStr, score)}**');
        buf.writeln('  > ${tekst.trim()}');
      }
    }
    buf.writeln();
  }

  // === 5. MEDICATIE — ingenomen dagen ===

  Future<void> _buildMedicationSection(
    StringBuffer buf,
    RapportStrings s,
    _PeriodData period,
  ) async {
    if (period.medicationConfigs.isEmpty) return;

    buf.writeln('## ${s.medTakenDays}');
    buf.writeln();

    for (final med in period.medicationConfigs) {
      final id = _asInt(med['id']);
      final name = formatMedName(med['naam']?.toString() ?? '');
      if (name.isEmpty) continue;
      final dosis = med['dosering']?.toString() ?? '?';
      final eenheid = med['eenheid']?.toString() ?? '';

      final intakes = (await db.getMedicationIntakeForMedication(id))
          .where((r) {
            final d = r['date']?.toString() ?? '';
            return d.compareTo(_dateStr(period.startDate)) >= 0 &&
                d.compareTo(_dateStr(period.endDate)) <= 0;
          })
          .toList();
      if (intakes.isEmpty) continue;

      final scheds = period.schedulesFor(id);

      if (scheds.isEmpty) {
        // Geen dagelijks schema: 'zo nodig'-medicatie. Er is geen
        // verwachte dosis, dus een percentage zou misleidend zijn.
        final takenDates = intakes.where((r) => _isTaken(r)).toList()
          ..sort((a, b) =>
              (a['date'] as String).compareTo(b['date'] as String));
        if (takenDates.isEmpty) continue;
        buf.writeln(
            '- **$name** $dosis $eenheid: ${s.takenAsNeededInPeriod(takenDates.length)}');
        buf.writeln(takenDates.map((r) {
          final dateStr = r['date']?.toString() ?? '?';
          final doseringLabel = _dailyDoseringLabel(r, eenheid);
          return '  ✅ $dateStr$doseringLabel';
        }).join('\n'));
        continue;
      }

      // Vaste medicatie: de noemer is het aantal dagen in de rapportperiode
      // waarop een dosis verwacht wordt — hetzelfde als in het
      // weekoverzicht en de samenvatting.
      final expectedDays = <DateTime>[];
      for (final d in period.allDays) {
        for (final sched in scheds) {
          if (period.isScheduledOn(sched, d)) expectedDays.add(d);
        }
      }
      if (expectedDays.isEmpty) continue;

      final takenDays =
          expectedDays.where((d) => period.takenOn(id, _dateStr(d)) > 0).length;
      final pct = (takenDays * 100 / expectedDays.length).round();
      buf.writeln(
          '- **$name** $dosis $eenheid: $takenDays/${expectedDays.length} ($pct%)');

      final byDate = <String, Map<String, dynamic>>{};
      for (final r in intakes) {
        byDate[r['date']?.toString() ?? ''] = r;
      }
      buf.writeln(expectedDays.map((d) {
        final dateStr = _dateStr(d);
        final row = byDate[dateStr];
        final ingenomen = row != null && _isTaken(row);
        final doseringLabel =
            row == null ? '' : _dailyDoseringLabel(row, eenheid);
        return '  ${ingenomen ? '✅' : '❌'} $dateStr$doseringLabel';
      }).join('\n'));
    }
    buf.writeln();
  }

  String _dailyDoseringLabel(Map<String, dynamic> row, String eenheid) {
    final dagDosering = row['dosering']?.toString() ?? '';
    if (dagDosering.isEmpty) return '';
    return ' — $dagDosering$eenheid';
  }

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
      final end = ep['end_date'] ?? 'loopt nog';
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
    if (period.medicationConfigs.isEmpty) return;

    buf.writeln('## ${s.medSchema}');
    buf.writeln();
    for (final med in period.medicationConfigs) {
      final id = _asInt(med['id']);
      final name = formatMedName(med['naam']?.toString() ?? '');
      if (name.isEmpty) continue;
      final dosis = med['dosering']?.toString() ?? '?';
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
        buf.writeln('- ${day['date']}: ${s.warningsCount(count)}');
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
        ho == null ? '' : ho.toStringAsFixed(1),
        split == null ? '' : split.toStringAsFixed(1),
        sleep == null ? '' : sleep.toStringAsFixed(1),
        '"$event"',
      ].join(','));
    }

    return buf.toString();
  }

  String _formatNL(DateTime d) {
    return '${d.day}-${d.month}-${d.year}';
  }

  String _formatDateStr(String? dateStr) {
    if (dateStr == null) return '...';
    try {
      final d = DateTime.parse(dateStr);
      return '${d.day}-${d.month}-${d.year}';
    } catch (_) {
      return dateStr;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
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

String _fmt(double v) => v.toStringAsFixed(1);

/// Ontleedt "HH:MM" uit een herinneringstijd.
({int hour, int minute})? _parseTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0].trim());
  final minute = int.tryParse(parts[1].trim());
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return (hour: hour, minute: minute);
}
