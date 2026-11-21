// Regressietest: na een backup-restore staan Hive-rijen onder STRING-sleutels
// (box.put(key.toString(), ...)). De app mag daar niet op stuk gaan:
// - insertSrmActivity op een bestaande datum+type moet updaten, geen TypeError,
//   en een int teruggeven;
// - insertMedicationIntakeMap mag geen 'as int'-crash geven op een
//   string-medication_id uit een restore.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:ritme/database/hive_database_helper.dart';
import 'package:ritme/service_locator.dart';

const _boxen = [
  'settings', 'daily_logs', 'srm_activities', 'mood_assessment',
  'medication_config', 'medication_intake', 'medication_schedule',
  'life_events', 'weight_logs', 'medical_appointments', 'crisis_plan',
  'prodromal_checklist', 'prodromal_logs', 'episode_logs', 'daily_dagboek',
];

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('ritme_restore_test');
    Hive.init(dir.path);
    for (final naam in _boxen) {
      if (!Hive.isBoxOpen(naam)) await Hive.openBox(naam);
    }
    setDbForTesting(HiveDatabaseHelper.instance);
  });

  setUp(() async {
    for (final naam in ['srm_activities', 'medication_intake']) {
      await Hive.box(naam).clear();
    }
  });

  test('insertSrmActivity op een string-sleutelrij update in plaats van te crashen', () async {
    final box = Hive.box('srm_activities');
    // Rij zoals na een backup-restore: string sleutel, string waarden.
    await box.put('srm_1700000000', {
      'id': '1700000000',
      'date': '2026-11-20',
      'activity_type': 'Opstaan',
      'actual_time': '07:15',
      'p_score': '4',
      'srt_point': null,
      'target_time': '07:00',
    });

    final id = await HiveDatabaseHelper.instance.insertSrmActivity('2026-11-20', 'Opstaan', '07:30', 5, null);
    expect(id, isA<int>());

    final rijen = box.values.where((e) => e['activity_type'] == 'Opstaan').toList();
    expect(rijen.length, 1, reason: 'bestaande rij moet bijgewerkt worden, niet gedupliceerd');
    expect(rijen.single['actual_time'], '07:30');
  });

  test('insertSrmActivity voor nieuw type maakt netjes een nieuwe rij', () async {
    final id = await HiveDatabaseHelper.instance.insertSrmActivity('2026-11-20', 'Avondeten', '18:30', 5, null);
    expect(id, isA<int>());
    expect(Hive.box('srm_activities').length, 1);
  });

  test('insertMedicationIntakeMap met string medication_id crasht niet', () async {
    final box = Hive.box('medication_intake');
    await box.put('intake_42', {
      'id': 'intake_42',
      'date': '2026-11-20',
      'medication_id': '1234',
      'aantal_ingenomen': '1',
    });

    final id = await HiveDatabaseHelper.instance.insertMedicationIntakeMap({
      'date': '2026-11-20',
      'medication_id': '1234',
      'aantal_ingenomen': 1,
    });
    expect(id, isA<int>());
    final rijen = box.values.where((e) => e['medication_id'].toString() == '1234').toList();
    expect(rijen.length, 1, reason: 'bestaande intake bijwerken, niet dupliceren');
  });
}
