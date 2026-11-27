// Consistentie van het rapport:
//  (a) Slaap vs Stemming: buckets tellen op tot exact het aantal gepaarde dagen
//  (b) P-Score telt alleen werkelijk gelogde ankers; een lege huidige dag telt niet
//  (c) Dagboek toont een blockquote-samenvatting i.p.v. een 1-regelige tabel

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/service_locator.dart';
import 'package:ritme/services/rapport_generator.dart';

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class ConsistentieDb implements DatabaseRepository {
  ConsistentieDb(this.today, {this.srm = const {}, this.dagboek = const []});
  final DateTime today;
  final Map<String, List<Map<String, dynamic>>> srm;
  final List<Map<String, dynamic>> dagboek;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  @override
  Future<Map<String, dynamic>?> getSettings() async => {'username': 'Test'};

  @override
  Future<List<Map<String, dynamic>>> getDailyLogs() async {
    final rows = <Map<String, dynamic>>[];
    for (int i = 0; i < 14; i++) {
      final d = DateTime(today.year, today.month, today.day - (13 - i));
      // 6 korte nachten (5u, stemming +1), 6 lange (7u, stemming −1),
      // 1 dag met slaap 0 (ongeldig) en 1 dag zonder stemming.
      if (i < 6) {
        rows.add({'date': _dateStr(d), 'stemming_hoog': 1, 'sleep_hours': 5.0});
      } else if (i < 12) {
        rows.add({'date': _dateStr(d), 'stemming_hoog': -1, 'sleep_hours': 7.0});
      } else if (i == 12) {
        rows.add({'date': _dateStr(d), 'stemming_hoog': 1, 'sleep_hours': 0});
      } else {
        rows.add({'date': _dateStr(d), 'sleep_hours': 7.0});
      }
    }
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationConfigsAll() async => [];

  @override
  Future<List<Map<String, dynamic>>> getMedicationSchedules() async => [];

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakeRange(
          String startDate, String endDate) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakeForMedication(
          int medicationId) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> getSrmActivitiesRange(
          String startDate, String endDate) async {
    final rows = <Map<String, dynamic>>[];
    srm.forEach((date, acts) {
      for (final a in acts) {
        rows.add({'date': date, ...a});
      }
    });
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> getMoodAssessmentRange(
          String startDate, String endDate) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> getDagboekRange(
          String startDate, String endDate) async =>
      dagboek;

  @override
  Future<List<Map<String, dynamic>>> getEpisodes(
          {String? type, int limit = 50}) async =>
      [];

  @override
  Future<Map<String, dynamic>?> getLatestMedicationLevel(
          int medicationId) async =>
      null;

  @override
  Future<List<Map<String, dynamic>>> getRecentProdromalTrends(int days) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> getCrisisPlan() async => [];
}

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  test('slaap-buckets tellen op tot het aantal gepaarde dagen', () async {
    setDbForTesting(ConsistentieDb(today));
    final md = await RapportGenerator.instance
        .generateLCMReport(days: 14, localeCode: 'nl');

    // 6 korte + 6 lange = 12 gepaarde dagen; slaap 0 en ontbrekende stemming
    // tellen niet mee.
    expect(md, contains('## 🧬 Correlaties'));
    expect(md, contains('### Slaap vs Stemming (n=12)'));
    expect(md, contains('| Korte slaap (< 6 uur) | n=6 | 1.0 |'));
    expect(md, contains('| Normale slaap (6 – 9,5 uur) | n=6 | -1.0 |'));
    expect(md, contains('| Lange slaap / sedatie (> 9,5 uur) | n=0 | – |'));
  });

  test('P-Score telt alleen gelogde ankers en sluit een lege huidige dag uit', () async {
    final srm = <String, List<Map<String, dynamic>>>{};
    // Tien dagen met een gelogd anker (p=4).
    for (int i = 1; i <= 10; i++) {
      final d = DateTime(today.year, today.month, today.day - i);
      srm[_dateStr(d)] = [
        {'p_score': 4, 'actual_time': '08:00', 'activity_type': 'Opstaan'},
      ];
    }
    // Vandaag: alleen een gepland anker (geen actual_time) → telt niet mee.
    srm[_dateStr(today)] = [
      {'p_score': 4, 'actual_time': '', 'activity_type': 'Opstaan'},
    ];
    // Een andere dag met p_score maar zonder tijd → telt ook niet mee.
    srm[_dateStr(DateTime(today.year, today.month, today.day - 12))] = [
      {'p_score': 5, 'actual_time': '', 'activity_type': 'Opstaan'},
    ];

    setDbForTesting(ConsistentieDb(today, srm: srm));
    final md = await RapportGenerator.instance
        .generateLCMReport(days: 14, localeCode: 'nl');

    expect(md, contains('| **Gem. P-Score** | 4.0 / 5 (SRT: 80%, n=10) |'));
  });

  test('dagboek toont een blockquote-samenvatting, geen tabel', () async {
    final entries = <Map<String, dynamic>>[];
    final scores = [4, 3, 2, 2, 1, 1, 1];
    for (int i = 0; i < scores.length; i++) {
      final d = DateTime(today.year, today.month, today.day - (scores.length - i));
      entries.add({
        'date': _dateStr(d),
        'score': scores[i],
        'tekst': 'Notitie ${i + 1}',
      });
    }

    setDbForTesting(ConsistentieDb(today, dagboek: entries));
    final md = await RapportGenerator.instance
        .generateLCMReport(days: 30, localeCode: 'nl');

    expect(
      md,
      contains('> **Gemiddelde dagboekscore:** 2.0 (1×4, 1×3, 2×2, 3×1) · **Aantal entries:** 7'),
    );
    final sectie = md.split('## 📓 Dagboek').last.split('## ').first;
    expect(sectie, isNot(contains('| Dagboekscore |')),
        reason: 'geen tabelkop meer in de dagboeksectie');
  });
}
