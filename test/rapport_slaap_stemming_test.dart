// Test voor de sleep-vs-mood-analyse in het LCM-rapport:
// dagen met <6 uur slaap en dagen met >=6 uur slaap worden apart geaggregeerd
// en het stemmingsverschil wordt zichtbaar in de markdown.

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/service_locator.dart';
import 'package:ritme/services/rapport_generator.dart';

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _SlaapStemmingDb implements DatabaseRepository {
  _SlaapStemmingDb(this.today);
  final DateTime today;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  @override
  Future<Map<String, dynamic>?> getSettings() async =>
      {'username': 'Testpatient'};

  @override
  Future<List<Map<String, dynamic>>> getDailyLogs() async {
    final rows = <Map<String, dynamic>>[];
    for (int i = 0; i < 14; i++) {
      final d = DateTime(today.year, today.month, today.day - (13 - i));
      // Afwisselend kort-en-somber / lang-en-goed gehumeurd.
      final kort = i.isEven;
      rows.add({
        'date': _dateStr(d),
        'stemming_hoog': kort ? -2 : 2,
        'sleep_hours': kort ? 5.0 : 8.0,
      });
    }
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationConfigsAll() async => [];

  @override
  Future<List<Map<String, dynamic>>> getMedicationSchedules() async => [];

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
  test('rapport bevat de sleep-vs-stemming sectie met beide groepen en het verschil', () async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    setDbForTesting(_SlaapStemmingDb(today));

    final md = await RapportGenerator.instance
        .generateLCMReport(days: 14, localeCode: 'nl');

    expect(md, contains('Slaap vs Stemming'));
    expect(md, contains('korte slaap'));
    expect(md, contains('-2.0'));
    expect(md, contains('2.0'));
    // Verschil tussen de twee groepen (4.0).
    expect(md, contains('4.0'));
  });
}
