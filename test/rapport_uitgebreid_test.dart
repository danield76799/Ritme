// Uitgebreide rapportopmaak: bandbreedtes, weekcontext (dosiswijziging/stop),
// correlatietabellen en de ⚠-markering in het dagboek.

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/service_locator.dart';
import 'package:ritme/services/rapport_generator.dart';

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _UitgebreidDb implements DatabaseRepository {
  _UitgebreidDb(this.vandaag);

  final DateTime vandaag;

  DateTime _dag(int offset) =>
      DateTime(vandaag.year, vandaag.month, vandaag.day - offset);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  @override
  Future<Map<String, dynamic>?> getSettings() async => {'username': 'Daan'};

  @override
  Future<List<Map<String, dynamic>>> getDailyLogs() async {
    const stemming = [-2, 0, 2, -1, 1, 0];
    const slaap = [5.0, 7.0, 8.0, 10.0, 7.0, 9.5];
    return [
      for (int i = 0; i < 6; i++)
        {
          'date': _iso(_dag(6 - i)),
          'stemming_hoog': stemming[i],
          'sleep_hours': slaap[i],
        },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getSrmActivitiesRange(
      String startDate, String endDate) async {
    return [
      for (int i = 1; i <= 4; i++)
        {'date': _iso(_dag(6 - (i - 1))), 'p_score': 4, 'actual_time': '08:00'},
      for (int i = 5; i <= 6; i++)
        {'date': _iso(_dag(6 - (i - 1))), 'p_score': 2, 'actual_time': '08:00'},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationConfigsAll() async => [
        {
          'id': 1,
          'naam': 'Lithium',
          'dosering': '800',
          'eenheid': 'mg',
          'created_at': '2026-11-18T09:00:00',
        },
        {
          'id': 2,
          'naam': 'Olanzapine',
          'dosering': '2.5',
          'eenheid': 'mg',
          'deleted': '1',
          'stopped_at': _iso(_dag(3)),
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> getMedicationSchedules() async => [
        {
          'id': 10,
          'medication_id': 1,
          'reminder_time': '20:45',
          'days_of_week': '1,2,3,4,5,6,7',
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakeRange(
      String startDate, String endDate) async {
    return [
      for (int i = 1; i <= 6; i++)
        {
          'medication_id': 1,
          'date': _iso(_dag(7 - i)),
          'aantal_ingenomen': 1,
          // Dosiswijziging na drie dagen: 1000 -> 800.
          'dosering': i <= 3 ? '1000' : '800',
        },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakeForMedication(
          int medicationId) async =>
      (await getMedicationIntakeRange('', ''))
          .where((r) => r['medication_id'] == medicationId)
          .toList();

  @override
  Future<List<Map<String, dynamic>>> getDagboekRange(
      String startDate, String endDate) async {
    return [
      {'date': _iso(_dag(5)), 'score': 1, 'tekst': 'Zware dag'},
      {'date': _iso(_dag(2)), 'score': 4, 'tekst': 'Betere dag'},
    ];
  }

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
  late DateTime vandaag;
  late String md;

  setUpAll(() async {
    vandaag = DateTime(2026, 11, 26);
    setDbForTesting(_UitgebreidDb(vandaag));
    md = await RapportGenerator.instance.generateLCMReport(
      localeCode: 'nl',
      now: DateTime(2026, 11, 26, 12),
      startDate: DateTime(2026, 11, 20),
      endDate: vandaag,
    );
  });

  test('samenvatting toont echte min/max-bandbreedtes', () {
    expect(md, contains('| **Dagen met data** | 6 / 7 kalenderdagen | 86% compleet |'));
    expect(md, contains('| **Gem. stemming** | 0.0 (n=6) | -2.0 t/m 2.0 (-5 t/m +5) |'));
    expect(md, contains('| **Gem. slaapduur** | 7u 45m (n=6) | 5u – 10u |'));
    expect(md, contains('| **Gem. P-Score** | 3.3 / 5 (SRT: 67%, n=6) | 2.0 – 4.0 |'));
    expect(md, contains('6 / 6 ingenomen (100%)'));
    expect(md, contains('Vaste medicatie t/m gisteravond'));
  });

  test('weekoverzicht toont bereik en context met wijzigingen', () {
    expect(md, contains('Gem. stemming (min / max)'));
    expect(md, contains('(-2.0 / 2.0)'));
    expect(md, contains('(5u – 10u)'));
    // Dosiswijziging en stop horen in de weekcontext, niet als placeholders.
    expect(md, contains('*23-11: Lithium → 800 mg*'));
    expect(md, contains('*23-11: Olanzapine gestopt*'));
  });

  test('medicatieschema toont sinds-datum', () {
    expect(md, contains('*(sinds 18-11-2026)*'));
  });

  test('correlaties vullen alle slaap- en ritmebuckets', () {
    expect(md, contains('### Slaap vs Stemming (n=6)'));
    expect(md, contains('### Dagritme (P-Score) vs. Stemming (n=6)'));
    expect(md, contains('### Medicatie-trouw vs Stemming (n=6)'));
    expect(md, contains('| Korte slaap (< 6 uur) | n=1 | -2.0 |'));
    expect(md, contains('| Normale slaap (6 – 9,5 uur) | n=4 | 0.8 |'));
    expect(md, contains('| Lange slaap / sedatie (> 9,5 uur) | n=1 | -1.0 |'));
    expect(md, contains('| Hoog ritme (P-Score ≥ 3.5) | n=4 | -0.3 |'));
    expect(md, contains('| Lager ritme (P-Score < 3.5) | n=2 | 0.5 |'));
  });

  test('dagboek markeert lage scores met ⚠', () {
    expect(md, contains('## 📓 Dagboek *(nieuwste bovenaan)*'));
    expect(md, contains('**21-11-2026 — score: 1 ⚠**'));
    expect(md, isNot(contains('**23-11-2026 — score: 4 ⚠**')));
  });

  test('nergens in het rapport staan sjabloon-placeholders', () {
    for (final token in ['[min]', '[max]', '[aantal]', '[gemiddelde]']) {
      expect(md, isNot(contains(token)), reason: 'placeholder $token');
    }
  });
}
