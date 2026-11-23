// Regressietests voor de "dosis nog niet aan de beurt"-logica in het rapport:
// - toekomstige doses tellen niet mee als verwacht/gemist
// - al ingenomen doses tellen altijd mee
// - verschil van 0 wordt niet als "-0.0" getoond

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/service_locator.dart';
import 'package:ritme/services/rapport_generator.dart';

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class DueTestDb implements DatabaseRepository {
  DueTestDb(this.today, {this.intakes = const []});
  final DateTime today;
  final List<Map<String, dynamic>> intakes;

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
      rows.add({'date': _dateStr(d), 'stemming_hoog': 2, 'sleep_hours': 7.0});
    }
    return rows;
  }

  String get _todayWeekday => '${today.weekday}';

  @override
  Future<List<Map<String, dynamic>>> getMedicationConfigsAll() async => [
        {'id': 1, 'naam': 'Testmed', 'dosering': '5', 'eenheid': 'mg'},
      ];

  @override
  Future<List<Map<String, dynamic>>> getMedicationSchedules() async => [
        {
          'id': 11,
          'medication_id': 1,
          // Alleen vandaag (deze weekdag), om 23:59 → 's middags nog niet aan de beurt.
          'reminder_time': '23:59',
          'days_of_week': _todayWeekday,
        },
      ];

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

void main() {
  group('isDoseDue', () {
    final now = DateTime(2026, 11, 23, 7, 43); // maandagochtend 07:43

    test('toekomstige dag is nooit aan de beurt', () {
      expect(
          RapportGenerator.isDoseDue(
              date: DateTime(2026, 11, 24), scheduledTime: '00:01', now: now),
          isFalse);
    });

    test('verleden dag is altijd aan de beurt', () {
      expect(
          RapportGenerator.isDoseDue(
              date: DateTime(2026, 11, 22), scheduledTime: '23:59', now: now),
          isTrue);
    });

    test('vandaag na geplande tijd is aan de beurt', () {
      expect(
          RapportGenerator.isDoseDue(
              date: now, scheduledTime: '07:00', now: now),
          isTrue);
    });

    test('vandaag vóór geplande tijd is niet aan de beurt', () {
      expect(
          RapportGenerator.isDoseDue(
              date: now, scheduledTime: '20:45', now: now),
          isFalse);
    });

    test('precies op de minuut is nog niet aan de beurt', () {
      final t = DateTime(2026, 11, 23, 20, 45);
      expect(
          RapportGenerator.isDoseDue(
              date: now, scheduledTime: '20:45', now: t),
          isFalse);
      expect(
          RapportGenerator.isDoseDue(
              date: now, scheduledTime: '20:45', now: t.add(const Duration(minutes: 1))),
          isTrue);
    });
  });

  test('al ingenomen dosis van vandaag telt mee, ook vóór het geplande tijdstip',
      () async {
    final today = DateTime.now();
    final todayStr = _dateStr(DateTime(today.year, today.month, today.day));
    setDbForTesting(DueTestDb(
      DateTime(today.year, today.month, today.day),
      intakes: [
        {'medication_id': 1, 'date': todayStr, 'aantal_ingenomen': 1},
      ],
    ));

    final md = await RapportGenerator.instance
        .generateLCMReport(days: 1, localeCode: 'nl');

    // Alleen vandaag telt mee: de 23:59-dosis (nog niet aan de beurt) is al
    // ingenomen → 1/1, en er mag geen "Gemist op" staan.
    expect(md, contains('1/1 dosis (100%)'));
    expect(md, isNot(contains('Gemist op')));
  });

  test('verschil van 0 wordt niet als -0.0 getoond', () async {
    // Beide trouw-groepen met identieke stemming → verschil exact 0.0.
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final rows = <Map<String, dynamic>>[];
    for (int i = 0; i < 14; i++) {
      final d = today.subtract(Duration(days: 13 - i));
      rows.add({
        'medication_id': 1,
        'date': _dateStr(d),
        // Afwisselend wel/niet ingenomen zodat beide trouw-groepen voorkomen.
        'aantal_ingenomen': i.isEven ? 1 : 0,
      });
    }

    // SCHEMA dagelijks; alle stemmingen gelijk (+2) → beide groepen gemiddelde 2.0
    setDbForTesting(_TweeGroepenDb(today, rows));
    final md = await RapportGenerator.instance
        .generateLCMReport(days: 14, localeCode: 'nl');

    expect(md, contains('Verschil in stemming: 0.0'));
    expect(md, isNot(contains('-0.0')));
  });
}

class _TweeGroepenDb extends DueTestDb {
  _TweeGroepenDb(super.today, List<Map<String, dynamic>> intakes)
      : super(intakes: intakes);

  @override
  Future<List<Map<String, dynamic>>> getMedicationSchedules() async => [
        {'id': 11, 'medication_id': 1, 'reminder_time': '08:00',
         'days_of_week': '1,2,3,4,5,6,7'},
      ];
}
