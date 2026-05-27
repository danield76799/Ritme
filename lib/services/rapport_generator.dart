import '../service_locator.dart';
import 'dart:convert';

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

    // === 1. DAILY OVERVIEW TABLE ===
    buf.writeln('## 📊 Dagelijks Overzicht');
    buf.writeln();
    buf.writeln('| Datum | Stemming (H/L) | Slaap | P-Score | Medicatie | Events |');
    buf.writeln('|-------|---------------|-------|---------|-----------|--------|');

    final dailyLogs = await db.getDailyLogs();
    final medicationConfigs = await db.getMedicationConfigs();

    double totalMood = 0;
    int moodCount = 0;
    double totalSleep = 0;
    int sleepCount = 0;
    double totalPScore = 0;
    int pScoreDays = 0;

    for (int i = 0; i < days; i++) {
      final d = now.subtract(Duration(days: i));
      final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final dateShort = '${d.day}/${d.month}';

      // Mood
      var log = dailyLogs.where((l) => l['date'] == dateStr).firstOrNull;
      String moodStr = '-';
      if (log != null) {
        final ho = _extractDouble(log['stemming_hoog']);
        final la = log['gesplitste_stemming'] == 1 ? _extractDouble(log['stemming_laag']) : null;
        if (ho != null) {
          moodStr = la != null ? '${ho.toStringAsFixed(1)}/${la.toStringAsFixed(1)}' : ho.toStringAsFixed(1);
          totalMood += ho;
          moodCount++;
        }
      }

      // Sleep
      final sle = _extractDouble(log?['sleep_hours']) ?? _extractDouble(log?['uren_slaap']);
      String sleepStr = sle != null ? '${sle.toStringAsFixed(1)}u' : '-';
      if (sle != null) { totalSleep += sle; sleepCount++; }

      // P-score
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
      String pScoreStr = pCount > 0 ? (pSum / pCount).toStringAsFixed(1) : '-';
      if (pCount > 0) { totalPScore += pSum / pCount; pScoreDays++; }

      // Medication
      final intake = await db.getMedicationIntake(dateStr);
      String medStr = intake.isEmpty ? '-' : intake.map((m) {
        final config = medicationConfigs.where((c) => c['id'] == m['medication_id']).firstOrNull;
        final name = config?['naam'] ?? '?';
        final taken = m['aantal_ingenomen'] == 1 ? '✓' : '✗';
        return '$name $taken';
      }).join(', ');
      if (medStr.length > 30) medStr = '${medStr.substring(0, 28)}...';

      // Events
      String eventStr = '-';
      if (log != null && log['life_event'] != null) {
        eventStr = log['life_event'].toString().length > 20
            ? '${log['life_event'].toString().substring(0, 18)}...'
            : log['life_event'].toString();
      }

      buf.writeln('| $dateShort | $moodStr | $sleepStr | $pScoreStr | $medStr | $eventStr |');
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
