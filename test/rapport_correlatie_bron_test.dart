// Beide correlaties moeten exact dezelfde dagelijkse stemmingsbron gebruiken
// (daily_logs.stemming_hoog op yyyy-MM-dd) en dagen zonder geldige stemming
// niet in n meerekenen. Regressie: de ochtend-check-in schreef P-score*2
// (2..10) in hetzelfde veld, waardoor gemiddelden als 0.0 ontstonden.

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/service_locator.dart';
import 'package:ritme/services/rapport_generator.dart';

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class BronTestDb implements DatabaseRepository {
  BronTestDb(this.today);
  final DateTime today;

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
      if (i == 0) continue; // geen log → geen stemming
      // 12 geldige dagen met stemming +2, één dag met oude P-score*2 (8).
      rows.add({
        'date': _dateStr(d),
        'stemming_hoog': i == 1 ? 8 : 2,
        'sleep_hours': 7.0,
      });
    }
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationConfigsAll() async => [
        {'id': 1, 'naam': 'Testmed', 'dosering': '5', 'eenheid': 'mg'},
      ];

  @override
  Future<List<Map<String, dynamic>>> getMedicationSchedules() async => [
        {'id': 11, 'medication_id': 1, 'reminder_time': '00:00',
         'days_of_week': '1,2,3,4,5,6,7'},
      ];

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakeRange(
      String startDate, String endDate) async {
    final rows = <Map<String, dynamic>>[];
    for (int i = 0; i < 14; i++) {
      final d = DateTime(today.year, today.month, today.day - (13 - i));
      rows.add({'medication_id': 1, 'date': _dateStr(d), 'aantal_ingenomen': 1});
    }
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakeForMedication(
          int medicationId) async {
    final all = await getMedicationIntakeRange('2000-01-01', '2099-12-31');
    return all.where((r) => r['medication_id'] == medicationId).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getSrmActivitiesRange(
          String startDate, String endDate) async => [];

  @override
  Future<List<Map<String, dynamic>>> getMoodAssessmentRange(
          String startDate, String endDate) async => [];

  @override
  Future<List<Map<String, dynamic>>> getDagboekRange(
          String startDate, String endDate) async => [];

  @override
  Future<List<Map<String, dynamic>>> getEpisodes(
          {String? type, int limit = 50}) async => [];

  @override
  Future<Map<String, dynamic>?> getLatestMedicationLevel(
          int medicationId) async => null;

  @override
  Future<List<Map<String, dynamic>>> getRecentProdromalTrends(int days) async => [];

  @override
  Future<List<Map<String, dynamic>>> getCrisisPlan() async => [];
}

void main() {
  test('medicatie-correlatie gebruikt dezelfde stemmingsbron als slaap-correlatie', () async {
    final now = DateTime.now();
    setDbForTesting(BronTestDb(DateTime(now.year, now.month, now.day)));

    final md = await RapportGenerator.instance
        .generateLCMReport(days: 14, localeCode: 'nl');

    // 12 geldige stemmingen van +2; de 8 (oude P-score×2) en de ontbrekende
    // dag tellen niet mee. Beide correlaties moeten dus 2.0 met n=12 tonen.
    expect(md, contains('Bij hoge trouw (>90%): gemiddelde stemming 2.0 (n=12 dagen; geen dagen met lage trouw in deze periode).'));
    expect(md, contains('Bij voldoende slaap (6+ uur): gemiddelde stemming 2.0 (n=12 dagen)'));
    expect(md, isNot(contains('gemiddelde stemming 0.0 (n=29')));
  });
}
