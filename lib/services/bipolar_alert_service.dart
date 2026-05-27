import '../service_locator.dart';

/// Service for detecting patterns and generating alerts for bipolar disorder
class BipolarAlertService {
  static final BipolarAlertService instance = BipolarAlertService._();
  BipolarAlertService._();

  /// Check sleep baseline deviation — #1 warning sign for mania
  Future<SleepAlert?> checkSleepBaseline() async {
    try {
      final dailyLogs = await db.getDailyLogs();
      if (dailyLogs.length < 7) return null;

      // Calculate baseline sleep (14d average)
      final now = DateTime.now();
      double totalSleep = 0;
      int sleepDays = 0;
      double lastNightSleep = 0;
      bool hasLastNight = false;

      for (var log in dailyLogs) {
        final dateStr = log['date']?.toString();
        if (dateStr == null) continue;
        try {
          final logDate = DateTime.parse(dateStr);
          final daysAgo = now.difference(logDate).inDays;

          // Last night (today or yesterday)
          if (daysAgo <= 1 && !hasLastNight) {
            final sleep = _extractSleep(log);
            if (sleep > 0) {
              lastNightSleep = sleep;
              hasLastNight = true;
            }
          }

          // Baseline: last 14 days
          if (daysAgo <= 14) {
            final sleep = _extractSleep(log);
            if (sleep > 0) {
              totalSleep += sleep;
              sleepDays++;
            }
          }
        } catch (_) {}
      }

      if (sleepDays < 5 || !hasLastNight) return null;

      final baseline = totalSleep / sleepDays;
      final deviation = ((lastNightSleep - baseline) / baseline * 100).abs();
      final isDecrease = lastNightSleep < baseline;

      // Alert if sleep dropped >30% below baseline and below 6 hours
      if (isDecrease && lastNightSleep < 6 && deviation > 30) {
        return SleepAlert(
          type: 'slaap_afname',
          title: '⚠️ Slaapwaarschuwing',
          message: 'Je sliep ${lastNightSleep.toStringAsFixed(1)}u — dat is ${deviation.toStringAsFixed(0)}% minder dan je gemiddelde van ${baseline.toStringAsFixed(1)}u. Verminderde slaap is een belangrijk voorteken van manie.',
          severity: 'high',
        );
      }

      // Mild alert if sleep decreased >20%
      if (isDecrease && lastNightSleep < 7 && deviation > 20) {
        return SleepAlert(
          type: 'slaap_afname_mild',
          title: '💤 Minder slaap',
          message: 'Je sliep ${lastNightSleep.toStringAsFixed(1)}u, ${deviation.toStringAsFixed(0)}% onder je gemiddelde. Houd je stemming extra in de gaten vandaag.',
          severity: 'medium',
        );
      }

      // Also check for hypersomnia (depression warning)
      if (!isDecrease && lastNightSleep > baseline * 1.5 && lastNightSleep > 10) {
        return SleepAlert(
          type: 'slaap_toename',
          title: '🔵 Veel slaap',
          message: 'Je sliep ${lastNightSleep.toStringAsFixed(1)}u — veel meer dan normaal (${baseline.toStringAsFixed(1)}u). Dit kan een teken zijn van depressie.',
          severity: 'medium',
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  double _extractSleep(Map<String, dynamic> log) {
    final rawSleep = log['sleep_hours'];
    if (rawSleep != null) {
      if (rawSleep is num) return rawSleep.toDouble();
      if (rawSleep is String) return double.tryParse(rawSleep) ?? 0;
    }
    final rawUren = log['uren_slaap'];
    if (rawUren != null) {
      if (rawUren is num) return rawUren.toDouble();
      if (rawUren is String) return double.tryParse(rawUren) ?? 0;
    }
    return 0;
  }

  /// Check SRT score deviation — social rhythm disruption
  Future<SRTAlert?> checkSRTStability() async {
    try {
      final now = DateTime.now();
      double totalScore = 0;
      int activityCount = 0;
      double last7Days = 0;
      int last7Count = 0;

      for (int i = 0; i < 14; i++) {
        final checkDate = now.subtract(Duration(days: i));
        final dateStr = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
        final activities = await db.getSrmActivities(dateStr);

        double dayScore = 0;
        int dayCount = 0;
        for (var a in activities) {
          final pScore = a['p_score'];
          if (pScore != null) {
            final score = pScore is int ? pScore : int.tryParse('$pScore') ?? 0;
            dayScore += score;
            dayCount++;
          }
        }

        if (dayCount > 0) {
          final ps = dayScore / dayCount;
          if (i < 7) {
            last7Days += ps;
            last7Count += dayCount;
          }
          totalScore += ps;
          activityCount += dayCount;
        }
      }

      if (last7Count < 10) return null;

      final recentAvg = last7Days / (activityCount > 0 ? last7Count / activityCount : 1);
      final baselineAvg = totalScore / 14;

      if (baselineAvg > 0 && recentAvg < baselineAvg * 0.7) {
        return SRTAlert(
          type: 'srt_daling',
          title: '📉 Ritme verstoord',
          message: 'Je dagelijkse ritme (SRT score) is gedaald. Sociale ritme verstoring kan episodes uitlokken. Probeer je vaste tijden weer op te pakken.',
          severity: 'medium',
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check prodromal warning signs trend
  Future<ProdromalAlert?> checkProdromalTrend() async {
    try {
      final recent = await db.getRecentProdromalTrends(3);
      if (recent.length < 2) return null;

      int totalWarnings = 0;
      for (var day in recent) {
        totalWarnings += day['warning_count'] as int? ?? 0;
      }

      if (totalWarnings >= 8) {
        return ProdromalAlert(
          type: 'voortekenen_hoog',
          title: '⚠️ Veel voortekenen',
          message: 'Je hebt in 3 dagen $totalWarnings voortekenen gerapporteerd. Overweeg je crisisplan te raadplegen.',
          severity: 'high',
        );
      }

      if (totalWarnings >= 5) {
        return ProdromalAlert(
          type: 'voortekenen_matig',
          title: '📋 Voortekenen aanwezig',
          message: 'Je rapporteert $totalWarnings voortekenen in 3 dagen. Blijf monitoren.',
          severity: 'medium',
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Run all checks and return actionable alerts
  Future<List<Alert>> runAllChecks() async {
    final alerts = <Alert>[];

    final sleepAlert = await checkSleepBaseline();
    if (sleepAlert != null) alerts.add(sleepAlert);

    final srtAlert = await checkSRTStability();
    if (srtAlert != null) alerts.add(srtAlert);

    final prodAlert = await checkProdromalTrend();
    if (prodAlert != null) alerts.add(prodAlert);

    return alerts;
  }
}

abstract class Alert {
  String get type;
  String get title;
  String get message;
  String get severity;
}

class SleepAlert implements Alert {
  @override
  final String type;
  @override
  final String title;
  @override
  final String message;
  @override
  final String severity;

  SleepAlert({required this.type, required this.title, required this.message, required this.severity});
}

class SRTAlert implements Alert {
  @override
  final String type;
  @override
  final String title;
  @override
  final String message;
  @override
  final String severity;

  SRTAlert({required this.type, required this.title, required this.message, required this.severity});
}

class ProdromalAlert implements Alert {
  @override
  final String type;
  @override
  final String title;
  @override
  final String message;
  @override
  final String severity;

  ProdromalAlert({required this.type, required this.title, required this.message, required this.severity});
}
