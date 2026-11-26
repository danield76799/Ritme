// Centrale formatters en de medicatie-cutoff in het LCM-rapport.

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/service_locator.dart';
import 'package:ritme/services/rapport_generator.dart';
import 'package:ritme/services/rapport_strings.dart';

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _MiniDb implements DatabaseRepository {
  _MiniDb({
    required this.configs,
    required this.schedules,
    required this.intakes,
  });

  final List<Map<String, dynamic>> configs;
  final List<Map<String, dynamic>> schedules;
  final List<Map<String, dynamic>> intakes;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  @override
  Future<Map<String, dynamic>?> getSettings() async => {'username': 'Test'};

  @override
  Future<List<Map<String, dynamic>>> getDailyLogs() async => const [];

  @override
  Future<List<Map<String, dynamic>>> getMedicationConfigsAll() async => configs;

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
  Future<List<Map<String, dynamic>>> getSrmActivitiesRange(
          String startDate, String endDate) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> getMoodAssessmentRange(
          String startDate, String endDate) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> getDagboekRange(
          String startDate, String endDate) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> getEpisodes(
          {String? type, int limit = 50}) async =>
      const [];

  @override
  Future<Map<String, dynamic>?> getLatestMedicationLevel(
          int medicationId) async =>
      null;

  @override
  Future<List<Map<String, dynamic>>> getRecentProdromalTrends(int days) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> getCrisisPlan() async => const [];
}

List<Map<String, dynamic>> _vasteMeds() => [
      {'id': 1, 'naam': 'Lithium', 'dosering': '1000.0', 'eenheid': 'mg'},
    ];

List<Map<String, dynamic>> _schema() => [
      {
        'id': 10,
        'medication_id': 1,
        'reminder_time': '20:45',
        'days_of_week': '1,2,3,4,5,6,7',
      },
    ];

List<Map<String, dynamic>> _innames(DateTime eind, {required bool vandaag}) {
  final rows = <Map<String, dynamic>>[];
  for (int i = 1; i <= 9; i++) {
    rows.add({
      'medication_id': 1,
      'date': _iso(DateTime(eind.year, eind.month, eind.day - i)),
      'aantal_ingenomen': 1,
    });
  }
  if (vandaag) {
    rows.add({'medication_id': 1, 'date': _iso(eind), 'aantal_ingenomen': 1});
  }
  return rows;
}

void main() {
  group('centrale formatters', () {
    test('dosering: hele getallen zonder .0, halve doses behouden decimalen',
        () {
      expect(RapportStrings.fmtDose('1000.0'), '1000');
      expect(RapportStrings.fmtDose('800.0'), '800');
      expect(RapportStrings.fmtDose('111.0'), '111');
      expect(RapportStrings.fmtDose('37.5'), '37.5');
      expect(RapportStrings.fmtDose('2,5'), '2.5');
      expect(RapportStrings.fmtDose(' 600 '), '600');
    });

    test('slaapduur: minuten altijd twee cijfers', () {
      final nl = RapportStrings.withLocale('nl');
      expect(nl.formatHours(9 + 2 / 60), '9u 02m');
      expect(nl.formatHours(9 + 30 / 60), '9u 30m');
      expect(nl.formatHours(9), '9u');
      expect(RapportStrings.withLocale('en').formatHours(9 + 2 / 60), '9h 02m');
    });

    test('datums: volledig dd-MM-yyyy en kort dd-MM', () {
      final d = DateTime(2026, 1, 5);
      expect(RapportStrings.fmtDatum(d), '05-01-2026');
      expect(RapportStrings.fmtDatumKort(d), '05-01');
      expect(RapportStrings.fmtDatumStr('2026-11-24'), '24-11-2026');
      expect(RapportStrings.fmtDatumKortStr('2026-11-24'), '24-11');
    });
  });

  group('medicatietelling en label', () {
    test('zonder inname vandaag: t/m gisteravond, geen doses van vandaag',
        () async {
      final eind = DateTime(2026, 11, 24);
      setDbForTesting(_MiniDb(
        configs: _vasteMeds(),
        schedules: _schema(),
        intakes: _innames(eind, vandaag: false),
      ));
      final md = await RapportGenerator.instance.generateLCMReport(
        localeCode: 'nl',
        now: DateTime(2026, 11, 24, 10),
        startDate: DateTime(2026, 11, 15),
        endDate: eind,
      );

      expect(md, contains('9 / 9 ingenomen (100%)'));
      expect(md, contains('Vaste medicatie t/m gisteravond'));
      expect(md, contains('- **Lithium** — 9/9 doses (100%)'));
      // Detail en samenvatting tellen dezelfde doses.
      expect(md, isNot(contains('10 / 10')));
    });

    test('met inname vandaag: label wordt t/m vandaag en de dosis telt mee',
        () async {
      final eind = DateTime(2026, 11, 24);
      setDbForTesting(_MiniDb(
        configs: _vasteMeds(),
        schedules: _schema(),
        intakes: _innames(eind, vandaag: true),
      ));
      final md = await RapportGenerator.instance.generateLCMReport(
        localeCode: 'nl',
        now: DateTime(2026, 11, 24, 10),
        startDate: DateTime(2026, 11, 15),
        endDate: eind,
      );

      expect(md, contains('10 / 10 ingenomen (100%)'));
      expect(md, contains('Vaste medicatie t/m vandaag'));
      expect(md, contains('- **Lithium** — 10/10 doses (100%)'));
      expect(md, isNot(contains('t/m gisteravond')));
    });

    test('PRN-tinnames blijven buiten de verwachte vaste doses', () async {
      final eind = DateTime(2026, 11, 24);
      final intakes = _innames(eind, vandaag: false)
        ..addAll([
          {'medication_id': 2, 'date': _iso(eind), 'aantal_ingenomen': 1},
          {
            'medication_id': 2,
            'date': _iso(DateTime(eind.year, eind.month, eind.day - 1)),
            'aantal_ingenomen': 1,
          },
        ]);
      setDbForTesting(_MiniDb(
        configs: [
          ..._vasteMeds(),
          {'id': 2, 'naam': 'Olanzapine', 'dosering': '2.5', 'eenheid': 'mg'},
        ],
        schedules: _schema(),
        intakes: intakes,
      ));
      final md = await RapportGenerator.instance.generateLCMReport(
        localeCode: 'nl',
        now: DateTime(2026, 11, 24, 10),
        startDate: DateTime(2026, 11, 15),
        endDate: eind,
      );

      expect(md, contains('9 / 9 ingenomen (100%)'));
      expect(md, contains('Vaste medicatie t/m gisteravond'));
      expect(md, contains('(PRN, 2.5 mg)'));
      expect(md, contains('1000 mg'));
      expect(md, isNot(contains('1000.0 mg')));
    });
  });
}
