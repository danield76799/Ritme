import '../service_locator.dart';

/// Generates comprehensive reports for bipolar disorder management
/// Life Chart Method (LCM) style for healthcare providers
class RapportGenerator {
  static final RapportGenerator instance = RapportGenerator._();
  RapportGenerator._();

  /// Generate a full Life Chart Method (LCM) report as markdown
  Future<String> generateLCMReport({int days = 30}) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    final startStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';

    final buf = StringBuffer();

    buf.writeln('# Life Chart Methode — Ritme Rapport');
    buf.writeln();
    buf.writeln('**Periode:** ${_formatNL(startDate)} t/m ${_formatNL(now)}');
    buf.writeln('**Gegenereerd:** ${_formatNL(now)} ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
    buf.writeln();

    // Settings
    final settings = await db.getSettings();
    if (settings != null && settings['username'] != null) {
      buf.writeln('**Patiënt:** ${settings['username']}');
      buf.writeln();
    }

    // === 1. STEMMINGSCHECK (5 VAGEN) — COMPACTE SECTIE ===
    final assessments = await db.getMoodAssessmentRange(startStr, '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');
    if (assessments.isNotEmpty) {
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
        final raw = _extractDouble(a['gewogen_score']) ?? _extractDouble(a['berekende_score']);
        if (v1 != null) { sumQ1 += v1; nQ1++; }
        if (v2 != null) { sumQ2 += v2; nQ2++; }
        if (v3 != null) { sumQ3 += v3; nQ3++; }
        if (v4 != null) { sumQ4 += v4; nQ4++; }
        if (v5 != null) { sumQ5 += v5; nQ5++; }
        if (raw != null) { sumRaw += raw; nRaw++; }
        final flags = (a['flags_json'] as String?) ?? '';
        if (flags.isNotEmpty) {
          for (final f in flags.split(',')) {
            if (f.trim().isEmpty) continue;
            flagCounts[f] = (flagCounts[f] ?? 0) + 1;
          }
        }
      }

      buf.writeln('## 🧠 Stemmingscheck (5 vragen) — $nQ1 invulmomenten');
      buf.writeln();
      buf.writeln('| Metriek | Gemiddelde |');
      buf.writeln('|---------|-----------|');
      if (nQ1 > 0) buf.writeln('| **Stemming** (−4..+4) | ${_fmt(sumQ1 / nQ1)} |');
      if (nQ2 > 0) buf.writeln('| **Energie** (0..100; 100=manisch) | ${_fmt(sumQ2 / nQ2)} |');
      if (nQ3 > 0) buf.writeln('| **Energie-niveau** (−3..+3) | ${_fmt(sumQ3 / nQ3)} |');
      if (nQ4 > 0) buf.writeln('| **Slaapbehoefte** (−4..+4) | ${_fmt(sumQ4 / nQ4)} |');
      if (nQ5 > 0) buf.writeln('| **Belangrijke gebeurtenis** (−4..+4) | ${_fmt(sumQ5 / nQ5)} |');
      if (nRaw > 0) buf.writeln('| **Berekende stemming** (−5..+5) | ${_fmt(sumRaw / nRaw)} |');
      buf.writeln();

      // Bipolaire analyse-signalen (alleen als er signalen zijn)
      final signalLines = <String>[];
      for (final entry in flagCounts.entries) {
        final label = _flagLabel(entry.key);
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
      buf.writeln('---');
      buf.writeln();
    }

    // === 2. WEEKOVERZICHT (i.p.v. per-dag tabel) ===
    final dailyLogs = await db.getDailyLogs();
    final medicationConfigs = await db.getMedicationConfigs();

    double totalMood = 0;
    int moodCount = 0;
    double totalSleep = 0;
    int sleepCount = 0;
    double totalPScore = 0;
    int pScoreDays = 0;
    int takenCount = 0;
    int intakeCount = 0;

    buf.writeln('## 📊 Weekoverzicht');
    buf.writeln();
    buf.writeln('| Week | Gem. stemming | Gem. slaap | Gem. P-Score | Medicatie |');
    buf.writeln('|------|--------------|-----------|-------------|-----------|');

    // Loop per week (nieuwste week eerst)
    final fullWeeks = (days / 7).ceil();
    for (int w = 0; w < fullWeeks; w++) {
      final weekEnd = now.subtract(Duration(days: 7 * w));
      final weekStart = now.subtract(Duration(days: 7 * w + 6));
      double wMood = 0;
      int wMoodN = 0;
      double wSleep = 0;
      int wSleepN = 0;
      double wP = 0;
      int wPN = 0;
      int wTaken = 0;
      int wIntake = 0;

      for (int i = 0; i < 7; i++) {
        final d = weekEnd.subtract(Duration(days: i));
        if (d.isBefore(weekStart) || d.isAfter(now) || d.isAfter(weekEnd)) continue;
        final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

        var log = dailyLogs.where((l) => l['date'] == dateStr).firstOrNull;
        if (log != null) {
          final ho = _extractDouble(log['stemming_hoog']);
          if (ho != null) { wMood += ho; wMoodN++; }
          final sle = _extractDouble(log['sleep_hours']) ?? _extractDouble(log['uren_slaap']);
          if (sle != null) { wSleep += sle; wSleepN++; }
        }

        final srmActs = await db.getSrmActivities(dateStr);
        double pSum = 0;
        int pCount = 0;
        for (var a in srmActs) {
          final ps = a['p_score'];
          if (ps != null) {
            pSum += ps is int ? ps : int.tryParse('$ps') ?? 0;
            pCount++;
          }
        }
        if (pCount > 0) { wP += pSum / pCount; wPN++; }

        final intake = await db.getMedicationIntake(dateStr);
        for (var m in intake) {
          wIntake++;
          if (m['aantal_ingenomen'] == 1) wTaken++;
        }
      }

      takenCount += wTaken;
      intakeCount += wIntake;

      final weekLabel = '${weekStart.day}/${weekStart.month} – ${weekEnd.day}/${weekEnd.month}';
      final moodStr = wMoodN > 0 ? (wMood / wMoodN).toStringAsFixed(1) : '-';
      final sleepStr = wSleepN > 0 ? '${_formatUren(wSleep / wSleepN)}' : '-';
      final pStr = wPN > 0 ? (wP / wPN).toStringAsFixed(1) : '-';
      final medStr = wIntake > 0 ? '$wTaken/$wIntake' : '-';
      buf.writeln('| $weekLabel | $moodStr | $sleepStr | $pStr | $medStr |');

      // Totaal-accumulatie voor de Samenvatting-sectie
      totalMood += wMood;
      moodCount += wMoodN;
      totalSleep += wSleep;
      sleepCount += wSleepN;
      totalPScore += wP;
      pScoreDays += wPN;
    }

    buf.writeln();
    buf.writeln('---');
    buf.writeln();

    // === 2. SUMMARY STATISTICS ===
    buf.writeln('## 📈 Samenvatting');
    buf.writeln();
    buf.writeln('| Metriek | Waarde |');
    buf.writeln('|---------|--------|');
    buf.writeln('| **Dagen met data** | ${moodCount} |');
    if (moodCount > 0) buf.writeln('| **Gem. stemming** | ${(totalMood / moodCount).toStringAsFixed(1)} (-5 tot +5) |');
    if (sleepCount > 0) {
      buf.writeln('| **Gem. slaapduur** | ${_formatUren(totalSleep / sleepCount)} |');
    }
    if (pScoreDays > 0) {
      final avgP = totalPScore / pScoreDays;
      buf.writeln('| **Gem. P-Score** | ${avgP.toStringAsFixed(1)} / 5 (SRT: ${(avgP / 5 * 100).round()}%) |');
    }
    if (intakeCount > 0) {
      final pct = (takenCount * 100 / intakeCount).round();
      buf.writeln('| **Medicatie-trouw** | $takenCount/$intakeCount ingenomen ($pct%) |');
    }

    buf.writeln();

    // === 3. EPISODES ===
    final episodes = await db.getEpisodes(limit: 20);
    final periodsInReport = episodes.where((e) {
      try {
        final sd = DateTime.parse(e['start_date'] as String);
        return sd.isAfter(startDate.subtract(const Duration(days: 30)));
      } catch (_) { return false; }
    }).toList();

    if (periodsInReport.isNotEmpty) {
      buf.writeln('## 🏥 Episodes');
      buf.writeln();
      for (var ep in periodsInReport) {
        final type = _episodeLabel(ep['episode_type'] as String);
        final start = ep['start_date'];
        final end = ep['end_date'] ?? 'loopt nog';
        buf.writeln('- **$type**: ${_formatDateStr(start)} — ${_formatDateStr(end)}');
      }
      buf.writeln();
    }

    // === 4. MEDICATION ===
    if (medicationConfigs.isNotEmpty) {
      buf.writeln('## 💊 Medicatie');
      buf.writeln();
      for (var med in medicationConfigs) {
        buf.writeln('- **${med['naam']}**: ${med['dosering'] ?? '?'} ${med['eenheid'] ?? ''}');
        // Latest blood level
        final level = await db.getLatestMedicationLevel(med['id'] as int);
        if (level != null && level['bloedspiegel'] != null) {
          buf.writeln('  - Laatste bloedspiegel: ${level['bloedspiegel']} ${level['eenheid'] ?? 'mmol/L'} (${_formatDateStr(level['date'] as String)})');
        }
      }
      buf.writeln();
    }

    // === 5. PRODROMAL WARNINGS ===
    final recentWarnings = await db.getRecentProdromalTrends(days);
    if (recentWarnings.isNotEmpty) {
      final totalWarnings = recentWarnings.fold<int>(0, (sum, d) => sum + (d['warning_count'] as int? ?? 0));
      if (totalWarnings > 0) {
        buf.writeln('## ⚠️ Voortekenen');
        buf.writeln();
        buf.writeln('Totaal voortekenen in periode: **$totalWarnings**');
        buf.writeln();
        for (var day in recentWarnings) {
          final count = day['warning_count'] as int? ?? 0;
          if (count > 0) {
            buf.writeln('- ${day['date']}: $count voortekenen');
          }
        }
        buf.writeln();
      }
    }

    // === 6. CRISIS PLAN ===
    final crisisPlan = await db.getCrisisPlan();
    final filledPlans = crisisPlan.where((s) => (s['content'] as String?)?.isNotEmpty == true).toList();
    if (filledPlans.isNotEmpty) {
      buf.writeln('## 🚨 Crisisplan');
      buf.writeln();
      for (var section in filledPlans) {
        buf.writeln('### ${_sectionTitle(section['section'] as String)}');
        buf.writeln(section['content']);
        buf.writeln();
      }
    }

    buf.writeln('---');
    buf.writeln('*Rapport gegenereerd door Ritme — SRT Tracker*');

    return buf.toString();
  }

  /// Generate a compact JSON report for data sharing
  Future<Map<String, dynamic>> generateJSONReport({int days = 30}) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    final startStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';

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
      'menstruatie': l['menstruatie'],
    }).toList();
    report['daily_logs'] = filteredLogs;

    // Episodes
    final episodes = await db.getEpisodes(limit: 50);
    report['episodes'] = episodes;

    // Medication
    report['medication_configs'] = await db.getMedicationConfigs();

    return report;
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

  String _formatUren(double uren) {
    final min = (uren * 60).round();
    final h = min ~/ 60;
    final m = min % 60;
    if (m == 0) return '${h}u';
    return '${h}u ${m}m';
  }

  double? _extractDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  String _episodeLabel(String type) {
    switch (type) {
      case 'hypomanie': return 'Hypomanie';
      case 'manie': return 'Manie';
      case 'depressie': return 'Depressie';
      case 'gemengd': return 'Gemengd';
      case 'euthym': return 'Stabiel';
      default: return type;
    }
  }

  String _fmt(double v) => v.toStringAsFixed(1);

  /// NL-labels voor de bipolaire analyse-flags (zelfde namen als de
  /// BipolarTag-enum in mood_assessment_scorer.dart).
  String? _flagLabel(String id) {
    switch (id) {
      case 'maniaShift': return 'Mogelijke manische shift';
      case 'probableMania': return 'Waarschijnlijke manie (triade)';
      case 'sleepReductionAlone': return 'Verminderde slaapbehoefte (vroeg manie-signaal)';
      case 'depressionShift': return 'Mogelijke depressieve shift';
      case 'probableDepression': return 'Waarschijnlijke depressie (triade)';
      case 'positiveLifeEventTrigger': return 'Positieve gebeurtenis als manie-trigger';
      case 'negativeLifeEventTrigger': return 'Negatieve gebeurtenis als depressie-trigger';
      case 'mixedEpisode': return 'Mogelijke gemengde episode';
      case 'opposingSignals': return 'Tegenstrijdige signalen';
      default: return null; // onbekende flag overslaan
    }
  }

  String _sectionTitle(String section) {
    switch (section) {
      case 'manie_vroeg': return 'Bij eerste tekenen van manie';
      case 'manie_ernstig': return 'Bij ernstige manie';
      case 'depressie_vroeg': return 'Bij eerste tekenen van depressie';
      case 'depressie_ernstig': return 'Bij ernstige depressie';
      case 'gemengd': return 'Bij gemengde episode';
      case 'contacten': return 'Belangrijke contacten';
      case 'medicatie_nood': return 'Medicatie noodplan';
      case 'wat_helpt': return 'Wat helpt mij';
      default: return section;
    }
  }
}
