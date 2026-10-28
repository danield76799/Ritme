// End-to-end test van het Life Chart-rapport: de gegenereerde Markdown
// moet in zichzelf consistent zijn.
//
// De vijf punten die hier getest worden:
//  1. Eén periode overal: header, weekoverzicht, samenvatting en
//     medicatietelling bestrijken exact dezelfde dagen.
//  2. Gelijke noemer: vaste medicatie telt overal tegen hetzelfde aantal
//     dagen in de periode; 'zo nodig'-medicatie krijgt géén percentage.
//  3. Medicatienamen zijn opgeschoond (trim + hoofdletter).
//  4. Geen dubbele medicatiesectie, maar één 'Actief Medicatieschema'.
//  5. De huidige dag telt niet mee in de correlatie als de avonddosis nog
//     open staat.

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/service_locator.dart';
import 'package:ritme/services/rapport_generator.dart';

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Minimale database met het scenario van de gebruiker: twee vaste
/// middelen met een dagelijkse herinnering en één PRN-middel.
///
/// [avondTijd] is de herinneringstijd van lithium. Die bepaalt of de
/// rapportdag nog 'open' staat (tijd in de toekomst) of al afgelopen is.
class RapportTestDb implements DatabaseRepository {
  RapportTestDb(this.today, {required this.avondTijd});

  final DateTime today;
  final String avondTijd;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  @override
  Future<Map<String, dynamic>?> getSettings() async =>
      {'username': 'Testpatient'};

  @override
  Future<List<Map<String, dynamic>>> getDailyLogs() async {
    // Elke dag van de periode (inclusief vandaag) heeft een stemming.
    final rows = <Map<String, dynamic>>[];
    for (int i = 0; i < 14; i++) {
      final d = DateTime(today.year, today.month, today.day - (13 - i));
      rows.add({
        'date': _dateStr(d),
        'stemming_hoog': i.isEven ? 1 : -1,
        'sleep_hours': 7.0,
      });
    }
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationConfigsAll() async => [
        {
          'id': 1,
          'naam': 'Lurasidon ',
          'dosering': '20',
          'eenheid': 'mg',
        },
        {
          'id': 2,
          'naam': 'lithium ',
          'dosering': '600',
          'eenheid': 'mg',
        },
        {
          'id': 3,
          'naam': 'olanzapine',
          'dosering': '5',
          'eenheid': 'mg',
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> getMedicationSchedules() async => [
        {
          'id': 10,
          'medication_id': 1,
          'reminder_time': '08:00',
          'days_of_week': '1,2,3,4,5,6,7',
        },
        {
          'id': 11,
          'medication_id': 2,
          'reminder_time': avondTijd,
          'days_of_week': '1,2,3,4,5,6,7',
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakeRange(
      String startDate, String endDate) async {
    final rows = <Map<String, dynamic>>[];
    for (int i = 0; i < 13; i++) {
      final d = DateTime(today.year, today.month, today.day - (13 - i));
      final date = _dateStr(d);
      rows.add({'medication_id': 1, 'date': date, 'aantal_ingenomen': 1});
      rows.add({'medication_id': 2, 'date': date, 'aantal_ingenomen': 1});
    }
    // Vandaag is nog niet ingenomen.
    rows.add({
      'medication_id': 1,
      'date': _dateStr(today),
      'aantal_ingenomen': 0,
    });
    rows.add({
      'medication_id': 2,
      'date': _dateStr(today),
      'aantal_ingenomen': 0,
    });
    // PRN: drie keer ingenomen in de periode.
    for (final offset in [12, 9, 4]) {
      final d = DateTime(today.year, today.month, today.day - offset);
      rows.add({
        'medication_id': 3,
        'date': _dateStr(d),
        'aantal_ingenomen': 1,
      });
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
          String startDate, String endDate) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> getMoodAssessmentRange(
          String startDate, String endDate) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> getDagboekRange(
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

/// Bouwt het rapport voor de gegeven [avondTijd].
Future<String> _rapport(String avondTijd) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  setDbForTesting(RapportTestDb(today, avondTijd: avondTijd));
  return RapportGenerator.instance
      .generateLCMReport(days: 14, localeCode: 'nl');
}

/// Een tijd die altijd in de toekomst ligt (twee uur vooruit).
String _toekomstigeTijd() {
  final t = DateTime.now().add(const Duration(hours: 2));
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Een tijd die altijd in het verleden ligt (drie uur terug).
String _verledenTijd() {
  final t = DateTime.now().subtract(const Duration(hours: 3));
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

void main() {
  group('rapport', () {
    late String report;

    setUp(() async {
      report = await _rapport(_toekomstigeTijd());
    });

    test('de header toont exact de 14 dagen van de periode', () {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day - 13);
      expect(
        report,
        contains('**Periode:** ${start.day}-${start.month}-${start.year} t/m '
            '${today.day}-${today.month}-${today.year}'),
      );
    });

    test('het weekoverzicht dekt dezelfde periode als de header', () {
      final today = DateTime.now();
      final oudsteWeekStart = DateTime(today.year, today.month, today.day - 13);
      expect(
        report,
        contains('${oudsteWeekStart.day}/${oudsteWeekStart.month} – '),
        reason: 'de oudste week moet op de startdatum van de periode beginnen',
      );
    });

    test('de samenvatting telt de dagen met data binnen de periode', () {
      final regel = report
          .split('\n')
          .firstWhere((l) => l.contains('Dagen met data'));
      final aantal = int.parse(regel.split('|')[2].trim());
      expect(aantal, 14);
    });

    group('medicatie-noemer', () {
      test('vaste medicatie gebruikt overal hetzelfde aantal dagen', () {
        // Detailweergave: Lurasidon 13/14 (93%).
        final lurasidon = report
            .split('\n')
            .firstWhere((l) => l.contains('**Lurasidon**'));
        expect(lurasidon, contains('13/14 (93%)'));
        // Weekoverzicht: 12/14 (de laatste week) en 14/14 (de eerste week).
        expect(report, contains('| 12/14 |'));
        expect(report, contains('| 14/14 |'));
        // Samenvatting: 26/28 — 13+13 ingenomen, 14+14 verwacht.
        expect(report, contains('| **Verwachte doses** | 26/28 ingenomen (93%) |'));
      });

      test('PRN-medicatie krijgt geen percentage', () {
        final olanzapine = report
            .split('\n')
            .firstWhere((l) => l.contains('**Olanzapine**'));
        expect(olanzapine, contains('3x ingenomen in deze periode (zo nodig)'));
        expect(olanzapine, isNot(contains('%')));
        expect(olanzapine, isNot(contains('/3')));
      });

      test('de datums van de PRN-inname staan erbij', () {
        final regels = report.split('\n');
        final index =
            regels.indexWhere((l) => l.contains('3x ingenomen in deze periode'));
        expect(index, greaterThan(-1));
        expect(regels[index + 1], contains('✅'));
        expect(regels[index + 2], contains('✅'));
        expect(regels[index + 3], contains('✅'));
      });

      test('dagen zonder inname staan als niet ingenomen in de lijst', () {
        final regels = report.split('\n');
        final index = regels.indexWhere((l) => l.contains('**Lurasidon**'));
        expect(regels[index + 14], contains('❌'));
      });
    });

    test('medicatienamen zijn opgeschoond', () {
      expect(report, contains('**Lurasidon**'));
      expect(report, contains('**Lithium**'));
      expect(report, contains('**Olanzapine**'));
      expect(report, isNot(contains('Lurasidon ')));
      expect(report, isNot(contains('lithium')));
    });

    test('er is geen dubbele medicatiesectie', () {
      expect(report, contains('## 📋 Actief Medicatieschema'));
      expect(report, isNot(contains('## 💊 Medicatie\n')));
      expect(
        '## 💊 Medicatie — ingenomen dagen'.allMatches(report).length,
        1,
      );
    });

    test('het medicatieschema onderscheidt vast en zo nodig', () {
      expect(report, contains('Dagelijks (vast)'));
      expect(report, contains('Zo nodig (PRN)'));
    });

    test('de correlatie sluit de nog open dag uit', () async {
      final sectie = report.split('## 🧬 Correlatie')[1].split('##')[0];
      expect(sectie, contains('Bij hoge trouw'));
      expect(
        sectie,
        isNot(contains('Bij lage trouw')),
        reason: 'de nog open dag zou ten onrechte als lage trouw meetellen',
      );
    });

    test('is de dag afgelopen, dan telt hij wél mee', () async {
      final rapport = await _rapport(_verledenTijd());
      final sectie = rapport.split('## 🧬 Correlatie')[1].split('##')[0];
      expect(
        sectie,
        contains('Bij lage trouw'),
        reason: 'vandaag is inmiddels afgelopen, dus de gemiste dosis telt '
            'echt mee in de correlatie',
      );
    });
  });
}
