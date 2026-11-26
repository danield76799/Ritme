// (1) Rapport midden op de dag: vandaag telt niet mee zolang er niets is
//     ingevuld en de doses van vandaag nog niet aan de beurt zijn.
// (2) Afwisselende doseringen (>= 4 dagen) worden één regel, nieuwste eerst.

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/service_locator.dart';
import 'package:ritme/services/rapport_generator.dart';

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class MiddagDb implements DatabaseRepository {
  MiddagDb(this.today,
      {this.logCount = 28, this.afwisselend = false});
  final DateTime today;
  final int logCount;
  final bool afwisselend;

  DateTime _dag(int dagenTerug) =>
      DateTime(today.year, today.month, today.day - dagenTerug);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  @override
  Future<Map<String, dynamic>?> getSettings() async => {'username': 'Test'};

  @override
  Future<List<Map<String, dynamic>>> getDailyLogs() async {
    final rows = <Map<String, dynamic>>[];
    // De laatste [logCount] dagen mét data; vandaag (0) bewust leeg.
    for (int i = 1; i <= logCount; i++) {
      final d = _dag(i);
      rows.add({'date': _dateStr(d), 'stemming_hoog': 2, 'sleep_hours': 7.0});
    }
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> getSrmActivitiesRange(
      String startDate, String endDate) async {
    final rows = <Map<String, dynamic>>[];
    for (int i = 1; i <= logCount; i++) {
      rows.add({
        'date': _dateStr(_dag(i)),
        'p_score': 4,
        'actual_time': '08:00',
        'activity_type': 'Opstaan',
      });
    }
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationConfigsAll() async => [
        {'id': 1, 'naam': 'Lithium', 'dosering': '1000', 'eenheid': 'mg'},
      ];

  @override
  Future<List<Map<String, dynamic>>> getMedicationSchedules() async => [
        {'id': 11, 'medication_id': 1, 'reminder_time': '23:59',
         'days_of_week': '1,2,3,4,5,6,7'},
      ];

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakeRange(
      String startDate, String endDate) async {
    final rows = <Map<String, dynamic>>[];
    if (afwisselend) {
      // Oude constante reeks: 1000 mg, 12 t/m 9 dagen terug.
      for (int i = 12; i >= 9; i--) {
        rows.add({'medication_id': 1, 'date': _dateStr(_dag(i)),
                  'aantal_ingenomen': 1, 'dosering': '1000'});
      }
      // Afwisselende reeks van 5 dagen: 6 t/m 2 dagen terug.
      final doses = ['1000', '800', '1000', '800', '1000'];
      for (int k = 0; k < doses.length; k++) {
        rows.add({'medication_id': 1, 'date': _dateStr(_dag(6 - k)),
                  'aantal_ingenomen': 1, 'dosering': doses[k]});
      }
    } else {
      for (int i = 1; i <= 29; i++) {
        rows.add({'medication_id': 1, 'date': _dateStr(_dag(i)),
                  'aantal_ingenomen': 1, 'dosering': '1000'});
      }
    }
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakeForMedication(
          int medicationId) async =>
      getMedicationIntakeRange('2000-01-01', '2099-12-31');

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
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  test('midden op de dag: lege vandaag telt niet mee; doses t/m gisteravond', () async {
    setDbForTesting(MiddagDb(today));
    final md = await RapportGenerator.instance
        .generateLCMReport(days: 30, localeCode: 'nl');

    expect(md, contains('| **Dagen met data** | 28 / 30 kalenderdagen |'));
    expect(md, contains('| **Gem. P-Score** | 4.0 / 5 (SRT: 80%, n=28) |'));
    // Vandaag (23:59) is nog niet aan de beurt: 28 verwachte doses.
    expect(
      RegExp(r'\*\*Verwachte doses\*\* \| 29 / 29 ingenomen \(100%\) \| Vaste medicatie t/m gisteravond')
          .hasMatch(md),
      isTrue,
    );
    expect(md, contains('t/m gisteravond'));
  });

  test('afwisselende dosering wordt één regel, nieuwste eerst', () async {
    setDbForTesting(MiddagDb(today, logCount: 14, afwisselend: true));
    final md = await RapportGenerator.instance
        .generateLCMReport(days: 14, localeCode: 'nl');

    final sectie = md.split('## 💊').last.split('## ').first;
    expect(
      RegExp(r'- \d+-\d+ t/m \d+-\d+: (800 / 1000|1000 / 800) mg afwisselend \(5/5 ingenomen\)')
          .hasMatch(sectie),
      isTrue,
      reason: 'vijf afwisselende dagen moeten één regel zijn',
    );
    // Nieuwste (afwisselende) reeks staat boven de oudere constante reeks.
    final idxAfwisselend = sectie.indexOf('afwisselend');
    final idxOud = sectie.indexOf('1000 mg (4/4 ingenomen)');
    expect(idxAfwisselend, greaterThan(-1));
    expect(idxOud, greaterThan(-1));
    expect(idxAfwisselend, lessThan(idxOud),
        reason: 'medicatieverloop moet nieuwste-eerst staan');
  });
}
