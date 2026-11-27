// Regressietest: inname-historie mag niet verdwijnen uit het rapport als
// innames gelogd zijn op een inmiddels gestopte (soft-deleted) variant
// van hetzelfde middel. De gebruiker zag zijn ingenomen olanzapine
// "nergens meer" staan.

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/service_locator.dart';
import 'package:ritme/services/rapport_generator.dart';

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class HistorieTestDb implements DatabaseRepository {
  HistorieTestDb(this.today);
  final DateTime today;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  @override
  Future<Map<String, dynamic>?> getSettings() async => {'username': 'Test'};

  @override
  Future<List<Map<String, dynamic>>> getDailyLogs() async => [];

  @override
  Future<List<Map<String, dynamic>>> getMedicationConfigsAll() async => [
        // Actieve variant (opnieuw aangemaakt na stop).
        {'id': 10, 'naam': 'Olanzapine', 'dosering': '5', 'eenheid': 'mg'},
        // Gestopte variant waar de oude innames op staan.
        {'id': 9, 'naam': 'Olanzapine', 'dosering': '5', 'eenheid': 'mg',
         'deleted': 1, 'stopped_at': '2026-10-01'},
        // Alleen gestopt, nooit opnieuw aangemaakt; wél innames in de periode.
        {'id': 7, 'naam': 'Tramadol', 'dosering': '50', 'eenheid': 'mg',
         'deleted': 1, 'stopped_at': '2026-09-01'},
      ];

  @override
  Future<List<Map<String, dynamic>>> getMedicationSchedules() async => [
        {'id': 11, 'medication_id': 10, 'reminder_time': '21:00',
         'days_of_week': '1,2,3,4,5,6,7'},
      ];

  DateTime _ago(int n) => DateTime(today.year, today.month, today.day - n);

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakeRange(
          String startDate, String endDate) async =>
      [
        // 3 innames onder de OUDE (gestopte) config id 9, binnen de periode
        {'medication_id': 9, 'date': _dateStr(_ago(2)), 'aantal_ingenomen': 1},
        {'medication_id': 9, 'date': _dateStr(_ago(3)), 'aantal_ingenomen': 1},
        {'medication_id': 9, 'date': _dateStr(_ago(4)), 'aantal_ingenomen': 1},
        // 2 innames onder de nieuwe config id 10
        {'medication_id': 10, 'date': _dateStr(_ago(1)), 'aantal_ingenomen': 1},
        {'medication_id': 10, 'date': _dateStr(_ago(0)), 'aantal_ingenomen': 1},
        // Innames van het volledig gestopte middel
        {'medication_id': 7, 'date': _dateStr(_ago(2)), 'aantal_ingenomen': 1},
      ];

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakeForMedication(
      int medicationId) async {
    return (await getMedicationIntakeRange('2000-01-01', '2099-12-31'))
        .where((r) => r['medication_id'] == medicationId)
        .toList();
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

void main() {
  test('inname-historie van gestopte configs telt mee in het rapport', () async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    setDbForTesting(HistorieTestDb(today));

    final md = await RapportGenerator.instance
        .generateLCMReport(days: 14, localeCode: 'nl');

    // Olanzapine: 5 innames verspreid over beide configs (id 10 + id 9)
    expect(md, contains('**Olanzapine**'));
    expect(RegExp(r'\*\*Olanzapine\*\* — 5/14 doses').hasMatch(md), isTrue,
        reason: 'innames van beide configs moeten samengeteld worden');

    // Tramadol: alleen gestopt, met 1 inname in de periode → zichtbaar als (gestopt)
    expect(md, contains('**Tramadol** (PRN, laatste inname:'));
    expect(md, contains('gestopt: 01-09)'));
    expect(md, contains('1× ingenomen'));
  });
}
