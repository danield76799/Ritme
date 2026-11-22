// Het "Actief Medicatieschema" toonde dubbele en gestopte medicatie:
// opnieuw ingevoerde middelen verschenen twee keer, en soft-delete
// middelen ('gestopt') bleven als actief in het schema staan.

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/service_locator.dart';
import 'package:ritme/services/rapport_generator.dart';

class DedupTestDb implements DatabaseRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  @override
  Future<Map<String, dynamic>?> getSettings() async => {'username': 'Test'};

  @override
  Future<List<Map<String, dynamic>>> getDailyLogs() async => [];

  @override
  Future<List<Map<String, dynamic>>> getMedicationConfigsAll() async => [
        // Dubbele Olanzapine (zelfde naam/dosering/tijden) — moet als 1 regel verschijnen.
        {'id': 1, 'naam': 'Olanzapine', 'dosering': '5', 'eenheid': 'mg'},
        {'id': 2, 'naam': 'Olanzapine', 'dosering': '5', 'eenheid': 'mg'},
        // Gestopt middel — mag niet in het actieve schema verschijnen.
        {'id': 3, 'naam': 'Lithium', 'dosering': '600', 'eenheid': 'mg',
         'deleted': 1, 'stopped_at': '2026-01-01T00:00:00.000'},
        // Normaal, actief middel.
        {'id': 4, 'naam': 'Quetiapine', 'dosering': '50', 'eenheid': 'mg'},
      ];

  @override
  Future<List<Map<String, dynamic>>> getMedicationSchedules() async => [
        {'id': 11, 'medication_id': 1, 'reminder_time': '21:00', 'days_of_week': '1,2,3,4,5,6,7'},
        {'id': 12, 'medication_id': 2, 'reminder_time': '21:00', 'days_of_week': '1,2,3,4,5,6,7'},
        {'id': 13, 'medication_id': 3, 'reminder_time': '08:00', 'days_of_week': '1,2,3,4,5,6,7'},
        {'id': 14, 'medication_id': 4, 'reminder_time': '22:00', 'days_of_week': '1,2,3,4,5,6,7'},
      ];

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakeForMedication(
          int medicationId) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakeRange(
          String startDate, String endDate) async =>
      [];

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
  test('actief schema: gededupliceerd en zonder gestopte middelen', () async {
    setDbForTesting(DedupTestDb());
    final md = await RapportGenerator.instance
        .generateLCMReport(days: 14, localeCode: 'nl');

    expect(md, contains('Actief Medicatieschema'));
    final schema = md.split('Actief Medicatieschema').last.split('##').first;
    expect(schema, contains('Olanzapine'));
    expect('Olanzapine'.allMatches(schema).length, 1,
        reason: 'dubbele Olanzapine-config moet één keer verschijnen');
    expect(schema, isNot(contains('Lithium')),
        reason: 'gestopt middel hoort niet in het actieve schema');
    expect(schema, contains('Quetiapine'));
  });
}
