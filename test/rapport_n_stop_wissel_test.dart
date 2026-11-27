// Gerichte tests voor de aangescherpte rapportregels:
// 1. n per correlatesubsectie (slaap vs P-Score ongelijk)
// 2. gestopt middel met laatste inname vóór de stopdatum
// 3. afwisselend doseschema in de weekcontext (>2 wissels, 2 doses)

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/service_locator.dart';
import 'package:ritme/services/rapport_generator.dart';

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _kort(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}';

class _Db implements DatabaseRepository {
  _Db({
    this.logs = const [],
    this.srm = const [],
    this.configs = const [],
    this.schedules = const [],
    this.intakes = const [],
  });

  final List<Map<String, dynamic>> logs;
  final List<Map<String, dynamic>> srm;
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
  Future<List<Map<String, dynamic>>> getDagboekRange(
          String startDate, String endDate) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> getMoodAssessmentRange(
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

void main() {
  test('n per correlatesubsectie volgt de geldige dagen van die subsectie',
      () async {
    final vandaag = DateTime.now();
    final today = DateTime(vandaag.year, vandaag.month, vandaag.day);

    final logs = <Map<String, dynamic>>[];
    for (int i = 0; i < 10; i++) {
      final d = DateTime(today.year, today.month, today.day - (9 - i));
      logs.add({
        'date': _iso(d),
        'stemming_hoog': 1,
        // Eerste vier dagen kort, daarna normaal.
        'sleep_hours': i < 4 ? 5.0 : 8.0,
      });
    }
    // P-Score alleen op zes dagen (drie hoog, drie laag).
    final srm = <Map<String, dynamic>>[];
    for (int i = 1; i <= 6; i++) {
      srm.add({
        'date': _iso(DateTime(today.year, today.month, today.day - i)),
        'p_score': i <= 3 ? 4 : 2,
        'actual_time': '08:00',
      });
    }

    setDbForTesting(_Db(
      logs: logs,
      srm: srm,
      configs: [
        {'id': 1, 'naam': 'Lithium', 'dosering': '800', 'eenheid': 'mg'},
      ],
      schedules: [
        {
          'id': 10,
          'medication_id': 1,
          'reminder_time': '08:00',
          'days_of_week': '1,2,3,4,5,6,7',
        },
      ],
      intakes: [
        for (int i = 0; i < 10; i++)
          {
            'medication_id': 1,
            'date': _iso(DateTime(today.year, today.month, today.day - (9 - i))),
            'aantal_ingenomen': 1,
            'dosering': '800',
          },
      ],
    ));

    final md = await RapportGenerator.instance.generateLCMReport(
      localeCode: 'nl',
      now: DateTime(today.year, today.month, today.day, 12),
      startDate: DateTime(today.year, today.month, today.day - 9),
      endDate: today,
    );

    // Geen algemene n meer in de hoofdkop.
    expect(md, contains('## 🧬 Correlaties'));
    expect(md, isNot(contains('## 🧬 Correlaties (n=')));

    // Slaap: 10 geldige dagen (4 kort + 6 normaal), P-Score: 6.
    expect(md, contains('### Slaap vs Stemming (n=10)'));
    expect(md, contains('| Korte slaap (< 6 uur) | n=4 | +1.0 |'));
    expect(md, contains('| Normale slaap (6.0 – 9.5 uur) | n=6 | +1.0 |'));
    expect(md, contains('| Lange slaap / sedatie (> 9.5 uur) | n=0 | – |'));

    expect(md, contains('### Dagritme (P-Score) vs. Stemming (n=6)'));
    expect(md, contains('| Hoog ritme (P-Score ≥ 3.5) | n=3 | +1.0 |'));
    expect(md, contains('| Lager ritme (P-Score < 3.5) | n=3 | +1.0 |'));

    expect(md, contains('### Medicatie-trouw vs Stemming (n=10)'));
  });

  test('gestopt middel toont laatste inname als die vóór de stopdatum ligt',
      () async {
    final vandaag = DateTime.now();
    final today = DateTime(vandaag.year, vandaag.month, vandaag.day);
    final stopTramadol = DateTime(today.year, today.month, today.day - 2);
    final laatsteTramadol = DateTime(today.year, today.month, today.day - 4);
    final stopCodeine = DateTime(today.year, today.month, today.day - 3);

    setDbForTesting(_Db(
      configs: [
        {
          'id': 7,
          'naam': 'Tramadol',
          'dosering': '50',
          'eenheid': 'mg',
          'deleted': '1',
          'stopped_at': _iso(stopTramadol),
        },
        {
          'id': 8,
          'naam': 'Codeine',
          'dosering': '20',
          'eenheid': 'mg',
          'deleted': '1',
          'stopped_at': _iso(stopCodeine),
        },
        {
          'id': 9,
          'naam': 'Quetiapine',
          'dosering': '50',
          'eenheid': 'mg',
          'deleted': '1',
          'stopped_at': _iso(DateTime(today.year, today.month, today.day - 4)),
        },
      ],
      schedules: [
        {
          'id': 12,
          'medication_id': 9,
          'reminder_time': '21:00',
          'days_of_week': '1,2,3,4,5,6,7',
        },
      ],
      intakes: [
        {'medication_id': 7, 'date': _iso(laatsteTramadol), 'aantal_ingenomen': 1},
        {
          'medication_id': 7,
          'date': _iso(DateTime(today.year, today.month, today.day - 5)),
          'aantal_ingenomen': 1,
        },
        {'medication_id': 8, 'date': _iso(stopCodeine), 'aantal_ingenomen': 1},
        {
          'medication_id': 9,
          'date': _iso(DateTime(today.year, today.month, today.day - 6)),
          'aantal_ingenomen': 1,
          'dosering': '50',
        },
        {
          'medication_id': 9,
          'date': _iso(DateTime(today.year, today.month, today.day - 5)),
          'aantal_ingenomen': 1,
          'dosering': '25',
        },
      ],
    ));

    final md = await RapportGenerator.instance.generateLCMReport(
      localeCode: 'nl',
      now: DateTime(today.year, today.month, today.day, 12),
      startDate: DateTime(today.year, today.month, today.day - 9),
      endDate: today,
    );

    expect(
      md,
      contains('**Tramadol** (PRN, laatste inname: ${_kort(laatsteTramadol)}, '
          'gestopt: ${_kort(stopTramadol)}) — 2× ingenomen op:'),
    );
    // Laatste inname == stopdatum: geen dubbele datumaanduiding.
    expect(md, contains('**Codeine** (PRN, gestopt: ${_kort(stopCodeine)})'));
    expect(md, isNot(contains('**Codeine** (PRN, laatste inname:')));
    // Vast middel met meerdere doseringen: als afbouw gemarkeerd.
    expect(md, contains('**Quetiapine** — 2/5 doses (40%) · afbouw · gestopt op'));
  });

  test('weekcontext comprimeert >2 wissels tussen twee doseringen', () async {
    // Maandag 16 t/m zondag 22 november 2026.
    final start = DateTime(2026, 11, 16);
    final eind = DateTime(2026, 11, 22);

    final intakes = <Map<String, dynamic>>[];
    const lithiumDoses = [800, 1000, 800, 1000, 800, 1000, 800];
    for (int i = 0; i < 7; i++) {
      intakes.add({
        'medication_id': 1,
        'date': _iso(DateTime(2026, 11, 16 + i)),
        'aantal_ingenomen': 1,
        'dosering': '${lithiumDoses[i]}',
      });
    }
    // Sertraline: precies twee wissels → losse regels.
    const sertralineDoses = [50, 50, 100, 100, 50, 50, 50];
    for (int i = 0; i < 7; i++) {
      intakes.add({
        'medication_id': 2,
        'date': _iso(DateTime(2026, 11, 16 + i)),
        'aantal_ingenomen': 1,
        'dosering': '${sertralineDoses[i]}',
      });
    }

    setDbForTesting(_Db(
      configs: [
        {'id': 1, 'naam': 'Lithium', 'dosering': '800', 'eenheid': 'mg'},
        {'id': 2, 'naam': 'Sertraline', 'dosering': '50', 'eenheid': 'mg'},
      ],
      schedules: [
        {
          'id': 10,
          'medication_id': 1,
          'reminder_time': '08:00',
          'days_of_week': '1,2,3,4,5,6,7',
        },
        {
          'id': 11,
          'medication_id': 2,
          'reminder_time': '08:00',
          'days_of_week': '1,2,3,4,5,6,7',
        },
      ],
      intakes: intakes,
    ));

    final md = await RapportGenerator.instance.generateLCMReport(
      localeCode: 'nl',
      now: DateTime(2026, 11, 22, 20),
      startDate: start,
      endDate: eind,
    );

    // Vijf wissels (17 t/m 22) tussen 1000 en 800 → één regel.
    expect(
      md,
      contains('*16-11 t/m 22-11: Lithium → 800 / 1000 mg (afwisselend)*'),
    );
    // Twee wissels blijven los zichtbaar.
    expect(md, contains('*18-11: Sertraline → 100 mg*'));
    expect(md, contains('*20-11: Sertraline → 50 mg*'));
    expect(md, isNot(contains('Sertraline → 50 / 100')));
    // Meerdere wijzigingen in dezelfde week staan in één cel, gescheiden
    // door <br>.
    expect(md, contains('Dagboek & alerts | Medicatiewijzigingen'));
    expect(md, contains('<br>'));
  });

  test('wisselreeks stopt op de dag vóór een nieuw doseringsblok', () async {
    // 16-11 t/m 20-11: 800/1000 afwisselend; 21-11 start een nieuw
    // constant blok van 1000 mg. De reeks mag daarom t/m 20-11 lopen.
    final intakes = <Map<String, dynamic>>[];
    const doses = [800, 1000, 800, 1000, 800, 1000, 1000];
    for (int i = 0; i < 7; i++) {
      intakes.add({
        'medication_id': 1,
        'date': _iso(DateTime(2026, 11, 16 + i)),
        'aantal_ingenomen': 1,
        'dosering': '${doses[i]}',
      });
    }

    setDbForTesting(_Db(
      configs: [
        {'id': 1, 'naam': 'Lithium', 'dosering': '800', 'eenheid': 'mg'},
      ],
      schedules: [
        {
          'id': 10,
          'medication_id': 1,
          'reminder_time': '08:00',
          'days_of_week': '1,2,3,4,5,6,7',
        },
      ],
      intakes: intakes,
    ));

    final md = await RapportGenerator.instance.generateLCMReport(
      localeCode: 'nl',
      now: DateTime(2026, 11, 22, 20),
      startDate: DateTime(2026, 11, 16),
      endDate: DateTime(2026, 11, 22),
    );

    expect(md, contains('*16-11 t/m 20-11: Lithium → 800 / 1000 mg'));
    expect(md, isNot(contains('16-11 t/m 21-11')));
    expect(md, contains('*21-11: Lithium → 1000 mg*'));
  });
}
