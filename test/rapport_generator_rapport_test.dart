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
  RapportTestDb(this.today,
      {required this.avondTijd,
       this.metExtraVastMiddel = false,
       this.lurasidonTijd = '23:59',
       this.gemisteDagOffset,
       this.todayTakenIds = const {}});

  final DateTime today;
  final String avondTijd;
  final String lurasidonTijd;

  /// Voegt een vast middel toe dat in de periode helemaal niet is
  /// ingenomen (0/14 moet zichtbaar zijn in het rapport).
  final bool metExtraVastMiddel;

  /// Laat één dag vóór vandaag bewust zonder inname (dagen terug).
  final int? gemisteDagOffset;

  /// Medicatie-ids die vandaag wél zijn ingenomen. Bepaalt of de
  /// medicatietelling vandaag meeneemt ('t/m vandaag') of niet.
  final Set<int> todayTakenIds;

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
        if (metExtraVastMiddel)
          {
            'id': 4,
            'naam': 'Sertraline',
            'dosering': '50',
            'eenheid': 'mg',
          },
      ];

  @override
  Future<List<Map<String, dynamic>>> getMedicationSchedules() async => [
        {
          'id': 10,
          'medication_id': 1,
          'reminder_time': lurasidonTijd,
          'days_of_week': '1,2,3,4,5,6,7',
        },
        {
          'id': 11,
          'medication_id': 2,
          'reminder_time': avondTijd,
          'days_of_week': '1,2,3,4,5,6,7',
        },
        if (metExtraVastMiddel)
          {
            'id': 12,
            'medication_id': 4,
            'reminder_time': '00:01',
            'days_of_week': '1,2,3,4,5,6,7',
          },
      ];

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakeRange(
      String startDate, String endDate) async {
    final rows = <Map<String, dynamic>>[];
    for (int i = 0; i < 13; i++) {
      final offset = 13 - i;
      if (offset == gemisteDagOffset) continue;
      final d = DateTime(today.year, today.month, today.day - offset);
      final date = _dateStr(d);
      rows.add({'medication_id': 1, 'date': date, 'aantal_ingenomen': 1});
      rows.add({'medication_id': 2, 'date': date, 'aantal_ingenomen': 1});
    }
    // Vandaag: standaard nog niet ingenomen; tests kunnen dit per middel
    // aanpassen om de 't/m vandaag'-tak te testen.
    rows.add({
      'medication_id': 1,
      'date': _dateStr(today),
      'aantal_ingenomen': todayTakenIds.contains(1) ? 1 : 0,
    });
    rows.add({
      'medication_id': 2,
      'date': _dateStr(today),
      'aantal_ingenomen': todayTakenIds.contains(2) ? 1 : 0,
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
Future<String> _rapport(String avondTijd,
    {bool metExtraVastMiddel = false,
     String lurasidonTijd = '23:59',
     int? gemisteDagOffset,
     Set<int> todayTakenIds = const {}}) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  setDbForTesting(RapportTestDb(
    today,
    avondTijd: avondTijd,
    metExtraVastMiddel: metExtraVastMiddel,
    lurasidonTijd: lurasidonTijd,
    gemisteDagOffset: gemisteDagOffset,
    todayTakenIds: todayTakenIds,
  ));
  return RapportGenerator.instance
      .generateLCMReport(days: 14, localeCode: 'nl');
}

/// Een tijd die altijd in de toekomst ligt (twee uur vooruit).
String _toekomstigeTijd() {
  final t = DateTime.now().add(const Duration(hours: 2));
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Een tijd die altijd in het verleden ligt (drie uur terug).
String _verledenTijd() => '00:00'; // altijd ruim verstreken

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
      final dag = oudsteWeekStart.day.toString().padLeft(2, '0');
      final maand = oudsteWeekStart.month.toString().padLeft(2, '0');
      expect(
        report,
        contains('$dag-$maand t/m '),
        reason: 'de oudste week moet op de startdatum van de periode beginnen',
      );
    });

    test('de samenvatting toont actieve en kalenderdagen binnen de periode', () {
      expect(report, contains('| **Dagen met data** | 13 / 13 afgeronde dagen | 100% compleet · vandaag al deels ingevuld |'));
    });

    group('medicatie-noemer', () {
      test('vaste medicatie gebruikt overal hetzelfde aantal dagen', () {
        // Vandaag (nog) niet aan de beurt → 13 van de 13 verschenen doses.
        final lurasidon = report
            .split('\n')
            .firstWhere((l) => l.contains('**Lurasidon**') && l.contains('doses ('));
        expect(lurasidon, contains('13/13 doses (100%)'));
        // Weekoverzicht: 12/12 (de lopende week) en 14/14 (de eerste week).
        expect(report, contains('| 12/12 |'));
        expect(report, contains('| 14/14 |'));
        // Samenvatting: 26/26 ingenomen.
        expect(
          RegExp(r'\*\*Vaste medicatie\*\* \| 26 / 26 doses \(100%\) \| T/m gisteravond')
              .hasMatch(report),
          isTrue,
        );
      });

      test('PRN-medicatie krijgt geen percentage', () {
        final olanzapine = report
            .split('\n')
            .firstWhere((l) => l.contains('**Olanzapine**'));
        expect(olanzapine, contains('3× ingenomen op:'));
        expect(olanzapine, isNot(contains('%')));
        expect(olanzapine, isNot(contains('/3')));
      });

      test('de datums van de PRN-inname staan erbij', () {
        final regel = report
            .split('\n')
            .firstWhere((l) => l.contains('3× ingenomen op:'));
        // Drie datums in d-M-formaat op dezelfde regel.
        final datums = RegExp(r'\d{1,2}-\d{1,2}').allMatches(regel).length;
        expect(datums, 3);
      });

      test('dagen zonder inname staan als Gemist vermeld', () async {
        final rapport = await _rapport(_verledenTijd(),
            lurasidonTijd: '00:00', gemisteDagOffset: 3);
        final regels = rapport.split('\n');
        final index = regels.indexWhere((l) => l.contains('**Lurasidon**'));
        final blok = regels.sublist(index, index + 4).join('\n');
        expect(blok, contains('Gemist op:'));
      });
    });

    test('een vast middel zonder inname blijft zichtbaar (0/14)', () async {
      final rapport =
          await _rapport(_toekomstigeTijd(), metExtraVastMiddel: true);
      expect(rapport, contains('- **Sertraline** — 0/13 doses (0%)'));
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
      expect(
        '## 💊 Medicatie — Verloop in Periode'.allMatches(report).length,
        1,
      );
    });

    test('het medicatieschema onderscheidt vast en zo nodig', () {
      expect(report, contains('Dagelijks (vast)'));
      expect(report, contains('Zo nodig (PRN)'));
    });

    test('de correlatie sluit de nog open dag uit', () async {
      final sectie = report.split('### Medicatie-trouw vs Stemming')[1];
      expect(sectie, contains('Bij hoge trouw'));
      expect(
        sectie,
        contains('geen dagen met lage trouw in deze periode'),
        reason: 'de nog open dag zou ten onrechte als lage trouw meetellen',
      );
    });

    test('is de dag afgelopen, dan telt hij wél mee', () async {
      final rapport = await _rapport(_verledenTijd(),
          lurasidonTijd: '00:00', todayTakenIds: const {1});
      final sectie = rapport.split('### Medicatie-trouw vs Stemming')[1];
      expect(
        sectie,
        contains('Bij lage trouw (<70%): gemiddelde stemming'),
        reason: 'vandaag is deels ingenomen en de avonddosis is verstreken, '
            'dus de dag telt mee en is een lage-trouwdag',
      );
    });

    test('zonder inname vandaag blijft de dag buiten de telling', () async {
      // Ook als de avondtijd al verstreken is: het label is 't/m gisteravond'
      // en dan tellen de doses van vandaag niet mee.
      final rapport = await _rapport(_verledenTijd(), lurasidonTijd: '00:00');
      final sectie = rapport.split('### Medicatie-trouw vs Stemming')[1];
      expect(
        sectie,
        contains('geen dagen met lage trouw in deze periode'),
        reason: 'zonder inname vandaag is de dag nog niet afgesloten',
      );
    });
  });
}
