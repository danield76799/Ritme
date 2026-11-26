// Edge-case tests zoals aangeleverd door de gebruiker, gekoppeld aan de
// echte generator. De wrapper genereert met expliciete periode en 'now',
// zodat de tests onafhankelijk van de systeemklok zijn.

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/service_locator.dart';
import 'package:ritme/services/rapport_generator.dart';

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class TestDb implements DatabaseRepository {
  TestDb({
    this.logs = const [],
    this.srm = const [],
    this.diary = const [],
    this.configs = const [],
    this.schedules = const [],
    this.intakes = const [],
  });

  final List<Map<String, dynamic>> logs;
  final List<Map<String, dynamic>> srm;
  final List<Map<String, dynamic>> diary;
  final List<Map<String, dynamic>> configs;
  final List<Map<String, dynamic>> schedules;
  final List<Map<String, dynamic>> intakes;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  @override
  Future<Map<String, dynamic>?> getSettings() async => {'username': 'Test'};

  @override
  Future<List<Map<String, dynamic>>> getDailyLogs() async => logs;

  @override
  Future<List<Map<String, dynamic>>> getSrmActivitiesRange(
          String startDate, String endDate) async =>
      srm;

  @override
  Future<List<Map<String, dynamic>>> getDagboekRange(
          String startDate, String endDate) async =>
      diary;

  @override
  Future<List<Map<String, dynamic>>> getMedicationConfigsAll() async =>
      configs;

  @override
  Future<List<Map<String, dynamic>>> getMedicationSchedules() async =>
      schedules;

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakeRange(
          String startDate, String endDate) async =>
      intakes;

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakeForMedication(
          int medicationId) async =>
      intakes.where((r) => r['medication_id'] == medicationId).toList();

  @override
  Future<List<Map<String, dynamic>>> getMoodAssessmentRange(
          String startDate, String endDate) async =>
      [];

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

Future<String> generateMarkdown({
  required DateTime startDate,
  required DateTime endDate,
  required DateTime now,
  List<Map<String, dynamic>> logs = const [],
  List<Map<String, dynamic>> srm = const [],
  List<Map<String, dynamic>> diary = const [],
  List<Map<String, dynamic>> configs = const [],
  List<Map<String, dynamic>> schedules = const [],
  List<Map<String, dynamic>> intakes = const [],
}) {
  setDbForTesting(TestDb(
    logs: logs,
    srm: srm,
    diary: diary,
    configs: configs,
    schedules: schedules,
    intakes: intakes,
  ));
  return RapportGenerator.instance.generateLCMReport(
    localeCode: 'nl',
    now: now,
    startDate: startDate,
    endDate: endDate,
  );
}

Map<String, dynamic> _log(DateTime d, {int stem = 0, double? slaap}) =>
    {'date': _dateStr(d), 'stemming_hoog': stem, if (slaap != null) 'sleep_hours': slaap};

List<Map<String, dynamic>> _dailyMeds() => [
      {'id': 1, 'naam': 'Lithium', 'dosering': '1000', 'eenheid': 'mg'},
    ];

List<Map<String, dynamic>> _dailySchedule({String tijd = '20:45'}) => [
      {'id': 11, 'medication_id': 1, 'reminder_time': tijd,
       'days_of_week': '1,2,3,4,5,6,7'},
    ];

void main() {
  group('Ritme Rapport Generator — Edge Cases', () {
    test('1. Volledig lege periode geeft geen NaN/Infinity of 0u 0m', () async {
      final md = await generateMarkdown(
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 7),
        now: DateTime(2026, 11, 7, 12),
      );
      expect(md, isNot(contains('NaN')));
      expect(md, isNot(contains('Infinity')));
      expect(md, isNot(contains('0u 0m')));
      expect(md, contains('–'));
    });

    test('2. Dag 1 vóór de geplande inname toont 0/0 zonder NaN%', () async {
      final md = await generateMarkdown(
        startDate: DateTime(2026, 11, 24),
        endDate: DateTime(2026, 11, 24),
        now: DateTime(2026, 11, 24, 10),
        configs: _dailyMeds(),
        schedules: _dailySchedule(),
      );
      expect(md, isNot(contains('NaN%')));
      expect(md, contains('0/0'));
    });

    test('3. Vandaag telt pas mee nadat de avonddosis is ingenomen', () async {
      final start = DateTime(2026, 10, 26);
      final end = DateTime(2026, 11, 24);

      List<Map<String, dynamic>> intakesTot({required bool vandaag}) {
        final rows = <Map<String, dynamic>>[];
        // De 29 dagen vóór vandaag.
        for (int i = 1; i <= 29; i++) {
          rows.add({'medication_id': 1,
                    'date': _dateStr(DateTime(end.year, end.month, end.day - i)),
                    'aantal_ingenomen': 1, 'dosering': '1000'});
        }
        if (vandaag) {
          rows.add({'medication_id': 1, 'date': _dateStr(end),
                    'aantal_ingenomen': 1, 'dosering': '1000'});
        }
        return rows;
      }

      final voor = await generateMarkdown(
        startDate: start, endDate: end, now: DateTime(2026, 11, 24, 12, 28),
        configs: _dailyMeds(), schedules: _dailySchedule(),
        intakes: intakesTot(vandaag: false),
      );
      expect(voor, contains('29/29'));

      final na = await generateMarkdown(
        startDate: start, endDate: end, now: DateTime(2026, 11, 24, 21, 15),
        configs: _dailyMeds(), schedules: _dailySchedule(),
        intakes: intakesTot(vandaag: true),
      );
      expect(na, contains('30/30'));
    });

    test('4. Onderbroken reeks wordt niet foutief samengevoegd', () async {
      final start = DateTime(2026, 11, 10);
      final end = DateTime(2026, 11, 14);
      final intakes = <Map<String, dynamic>>[];
      for (final d in [10, 11, 13, 14]) {
        intakes.add({'medication_id': 1, 'date': _dateStr(DateTime(2026, 11, d)),
                     'aantal_ingenomen': 1, 'dosering': '1000'});
      }
      final md = await generateMarkdown(
        startDate: start, endDate: end, now: DateTime(2026, 11, 15, 9),
        configs: _dailyMeds(), schedules: _dailySchedule(tijd: '00:00'),
        intakes: intakes,
      );
      expect(md, isNot(contains('- 10-11 t/m 14-11:')));
      expect(md, contains('10-11 t/m 11-11'));
      expect(md, contains('13-11 t/m 14-11'));
    });

    test('5. Gestopte medicatie zonder innames in de periode wordt verborgen', () async {
      final md = await generateMarkdown(
        startDate: DateTime(2026, 11, 18),
        endDate: DateTime(2026, 11, 24),
        now: DateTime(2026, 11, 24, 12),
        configs: [
          {'id': 2, 'naam': 'Olanzapine', 'dosering': '2.5', 'eenheid': 'mg',
           'deleted': '1', 'stopped_at': '2026-11-17'},
        ],
        schedules: [
          {'id': 12, 'medication_id': 2, 'reminder_time': '21:00',
           'days_of_week': '1,2,3,4,5,6,7'},
        ],
      );
      expect(md, isNot(contains('Olanzapine')));
    });

    test('6. Twee notities op dezelfde dag geven één alert', () async {
      final md = await generateMarkdown(
        startDate: DateTime(2026, 11, 18),
        endDate: DateTime(2026, 11, 24),
        now: DateTime(2026, 11, 24, 12),
        diary: [
          {'date': '2026-11-20', 'score': 1, 'tekst': 'Eerste'},
          {'date': '2026-11-20', 'score': 1, 'tekst': 'Tweede'},
        ],
      );
      expect(md, contains('⚠ 20-11'));
      expect(md, isNot(contains('20-11, 20-11')));
    });

    test('7. Slaap-correlatie zonder korte-slaapgroep toont n=0 en geen verschil', () async {
      final logs = <Map<String, dynamic>>[];
      for (int i = 1; i <= 7; i++) {
        logs.add(_log(DateTime(2026, 11, i), stem: 1, slaap: 7.0));
      }
      final md = await generateMarkdown(
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 7),
        now: DateTime(2026, 11, 8, 9),
        logs: logs,
      );
      expect(md, contains('(n=0 dagen)'));
      expect(md, isNot(contains('Verschil in stemming:')));
    });

    test('8. Negatieve nul wordt genormaliseerd naar 0.0', () async {
      final md = await generateMarkdown(
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 2),
        now: DateTime(2026, 11, 3, 9),
        logs: [
          _log(DateTime(2026, 11, 1), stem: 0, slaap: 7),
          _log(DateTime(2026, 11, 2), stem: 0, slaap: 7),
        ],
      );
      expect(md, isNot(contains('-0.0')));
    });

    test('9. Zomer-/wintertijdovergang houdt de dagtelling intact', () async {
      final logs = <Map<String, dynamic>>[];
      for (int d = 24; d <= 27; d++) {
        logs.add(_log(DateTime(2026, 10, d), stem: 1, slaap: 7));
      }
      final md = await generateMarkdown(
        startDate: DateTime(2026, 10, 24),
        endDate: DateTime(2026, 10, 27),
        now: DateTime(2026, 10, 28, 9),
        logs: logs,
      );
      expect(md, contains('4 / 4 kalenderdagen'));
    });
  });
}
