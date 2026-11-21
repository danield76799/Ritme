// Round-trip-test voor de backup: alles wat de app kan schrijven moet na een
// volledige export → wissen → restore identiek terugkomen. Dit dekt de
// klassieke restore-bugs (string-sleutels na restore, stille deelrestores).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:ritme/database/hive_database_helper.dart';
import 'package:ritme/service_locator.dart';
import 'package:ritme/services/backup_service.dart';

const _boxen = [
  'settings', 'daily_logs', 'srm_activities', 'mood_assessment',
  'medication_config', 'medication_intake', 'medication_schedule',
  'life_events', 'weight_logs', 'medical_appointments', 'crisis_plan',
  'prodromal_checklist', 'prodromal_logs', 'episode_logs', 'daily_dagboek',
];

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('ritme_roundtrip');
    Hive.init(dir.path);
    for (final naam in _boxen) {
      if (!Hive.isBoxOpen(naam)) await Hive.openBox(naam);
    }
    setDbForTesting(HiveDatabaseHelper.instance);
  });

  setUp(() async {
    for (final naam in _boxen) {
      await Hive.box(naam).clear();
    }
  });

  test('export -> wis -> restore brengt alles intact terug en faalt nergens', () async {
    final db = HiveDatabaseHelper.instance;

    // Seed: verspreiding over zo veel mogelijk secties.
    await db.updateSettingsMap({'username': 'Daan', 'target_slaap': '23:00'});
    await db.upsertDailyLog({'date': '2026-11-10', 'uren_slaap': 7.5, 'awake_minutes': 20, 'stemming_hoog': 6});
    await db.upsertDailyLog({'date': '2026-11-11', 'uren_slaap': 6.0, 'awake_minutes': 45, 'stemming_laag': 4});
    await db.insertSrmActivity('2026-11-10', 'Opstaan', '07:30', 4, null, targetTime: '07:00');
    final medId = await db.insertMedicationConfig('Olanzapine', '2.5', 'mg', reminderEnabled: false);
    await db.insertMedicationIntake('2026-11-10', medId, 1);
    await Hive.box('daily_dagboek').put('2026-11-10', {'datum': '2026-11-10', 'tekst': 'Rustige dag'});
    await Hive.box('medical_appointments')
        .put('appt1', {'id': 'appt1', 'datum': '2026-11-25', 'titel': 'Psychiater'});
    await Hive.box('weight_logs')
        .put('2026-11-10', {'date': '2026-11-10', 'weight_kg': 82.5});

    // Export (exact zoals het delen/download pad dat doet).
    final backup = await BackupService.exportAllData();
    expect(backup['data'], isNotNull);
    final data = Map<String, dynamic>.from(backup['data'] as Map);
    expect(data.containsKey('sqlite_daily_logs'), isTrue);
    expect(data.containsKey('medication_config') || data.containsKey('sqlite_medication_config'), isTrue);

    // Alles wissen.
    for (final naam in _boxen) {
      await Hive.box(naam).clear();
    }
    expect(await db.getDailyLogs(), isEmpty);

    // Restore.
    final failures = await BackupService.restoreFromData(backup);
    expect(failures, isEmpty, reason: 'secties mislukt: $failures');

    // Verifieer inhoud.
    final settings = await db.getSettings();
    expect(settings?['username'], 'Daan');
    expect(settings?['target_slaap'], '23:00');

    final logs = await db.getDailyLogs();
    expect(logs.length, 2);
    final log1 = logs.firstWhere((l) => l['date'] == '2026-11-10');
    expect(log1['uren_slaap'].toString(), '7.5');

    final srm = await db.getSrmActivities('2026-11-10');
    expect(srm.any((a) => a['activity_type'] == 'Opstaan'), isTrue);

    final configs = await db.getMedicationConfigs();
    expect(configs.any((c) => c['naam'] == 'Olanzapine'), isTrue);

    final intakes = await db.getMedicationIntakeRange('2026-11-01', '2026-11-30');
    expect(intakes, isNotEmpty);

    expect(Hive.box('daily_dagboek').get('2026-11-10'), isNotNull);
    expect(Hive.box('medical_appointments').get('appt1'), isNotNull);
    expect(Hive.box('weight_logs').get('2026-11-10'), isNotNull);
  });

  test('een kapotte sectie blokkeert de rest niet en wordt gerapporteerd', () async {
    final db = HiveDatabaseHelper.instance;
    await db.upsertDailyLog({'date': '2026-11-10', 'uren_slaap': 7.5});

    final backup = await BackupService.exportAllData();
    // Verniel één box-sectie in de backup zelf (zelfde map-object als backup['data']).
    (backup['data'] as Map)['weight_logs'] = {'bad': 'geen-map', 'worse': 42};
    // Lokale boxes leegmaken om te zien dat alles netjes wordt hersteld/overgeslagen.
    await Hive.box('daily_logs').clear();
    await Hive.box('weight_logs').clear();

    final failures = await BackupService.restoreFromData(backup);
    expect(failures, contains('weight_logs'));
    // daily_logs moet wél hersteld zijn.
    final logs = await db.getDailyLogs();
    expect(logs.length, 1);
  });
}
