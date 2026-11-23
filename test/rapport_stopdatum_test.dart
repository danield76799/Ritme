// Stopdatum in het rapport: doses t/m de dag vóór de stopdatum tellen mee,
// daarna niet meer. Ook: de gekozen datum wordt zo opgeslagen.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:ritme/database/hive_database_helper.dart';
import 'package:ritme/service_locator.dart';
import 'package:ritme/services/rapport_generator.dart';

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class StopDb implements DatabaseRepository {
  StopDb(this.today);
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
        {
          'id': 1,
          'naam': 'Olanzapine',
          'dosering': '2.5',
          'eenheid': 'mg',
          'deleted': '1',
          // Gestopt 8 dagen geleden: dagen daarvóór tellen mee, daarna niet.
          'stopped_at': _dateStr(DateTime(today.year, today.month, today.day - 8)),
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> getMedicationSchedules() async => [
        {'id': 11, 'medication_id': 1, 'reminder_time': '00:00',
         'days_of_week': '1,2,3,4,5,6,7'},
      ];

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakeRange(
          String startDate, String endDate) async =>
      [
        // Drie innames van vóór de stopdatum; daarna niets.
        {'medication_id': 1, 'date': _dateStr(DateTime(today.year, today.month, today.day - 10)), 'aantal_ingenomen': 1},
        {'medication_id': 1, 'date': _dateStr(DateTime(today.year, today.month, today.day - 9)), 'aantal_ingenomen': 1},
        {'medication_id': 1, 'date': _dateStr(DateTime(today.year, today.month, today.day - 8)), 'aantal_ingenomen': 1},
      ];

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakeForMedication(
          int medicationId) async {
    final all = await getMedicationIntakeRange('2000-01-01', '2099-12-31');
    return all.where((r) => r['medication_id'] == medicationId).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getSrmActivitiesRange(
          String startDate, String endDate) async => [];

  @override
  Future<List<Map<String, dynamic>>> getMoodAssessmentRange(
          String startDate, String endDate) async => [];

  @override
  Future<List<Map<String, dynamic>>> getDagboekRange(
          String startDate, String endDate) async => [];

  @override
  Future<List<Map<String, dynamic>>> getEpisodes(
          {String? type, int limit = 50}) async => [];

  @override
  Future<Map<String, dynamic>?> getLatestMedicationLevel(
          int medicationId) async => null;

  @override
  Future<List<Map<String, dynamic>>> getRecentProdromalTrends(int days) async => [];

  @override
  Future<List<Map<String, dynamic>>> getCrisisPlan() async => [];
}

void main() {
  test('doses tellen t/m de dag vóór de stopdatum', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setDbForTesting(StopDb(today));

    final md = await RapportGenerator.instance
        .generateLCMReport(days: 14, localeCode: 'nl');

    // Periode 10-11 t/m 23-11, stop per 15-11: dagen 10 t/m 14 tellen mee
    // (5 doses). Innames op 13 en 14 tellen; de inname op de stopdag zelf
    // (15-11) valt buiten de dekking en telt dus niet mee.
    expect(md, contains('2/5 doses (40%)'));
    final stopDag = DateTime(today.year, today.month, today.day - 8);
    expect(md, contains('gestopt op ${stopDag.day}-${stopDag.month}'));
    // De gemiste dagen liggen vóór de stopdatum.
    expect(md, contains('Gemist op'));
  });

  test('deleteMedicationConfig bewaart de gekozen stopdatum', () async {
    final dir = await Directory.systemTemp.createTemp('ritme_stopdatum');
    Hive.init(dir.path);
    HiveDatabaseHelper.debugHiveDir = dir.path;
    HiveDatabaseHelper.recoveredBoxes.clear();
    await HiveDatabaseHelper.init();
    setDbForTesting(HiveDatabaseHelper.instance);

    final db = HiveDatabaseHelper.instance;
    final id = await db.insertMedicationConfig('Testmed', '5', 'mg');
    await db.deleteMedicationConfig(id, stoppedAt: '2026-10-15');

    final all = await db.getMedicationConfigsAll();
    expect(all.single['stopped_at'], '2026-10-15');

    HiveDatabaseHelper.debugHiveDir = null;
    await Hive.close();
  });

  test('stopdatum kan achteraf gecorrigeerd worden', () async {
    final dir = await Directory.systemTemp.createTemp('ritme_stopdatum2');
    Hive.init(dir.path);
    HiveDatabaseHelper.debugHiveDir = dir.path;
    HiveDatabaseHelper.recoveredBoxes.clear();
    await HiveDatabaseHelper.init();
    setDbForTesting(HiveDatabaseHelper.instance);

    final db = HiveDatabaseHelper.instance;
    final id = await db.insertMedicationConfig('Testmed', '5', 'mg');
    await db.deleteMedicationConfig(id, stoppedAt: '2026-11-22');
    await db.updateMedicationStopDate(id, '2026-11-05');

    final all = await db.getMedicationConfigsAll();
    expect(all.single['stopped_at'], '2026-11-05');
    // Nog steeds gestopt: niet terug in de actieve lijst.
    expect(await db.getMedicationConfigs(), isEmpty);

    HiveDatabaseHelper.debugHiveDir = null;
    await Hive.close();
  });
}
