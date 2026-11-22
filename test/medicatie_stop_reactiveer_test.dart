// Het stop/herstart-mechanisme van medicatie:
//  - stoppen markeert de config als gestopt, verwijdert GEEN schema/inname;
//  - herinneringen voor gestopte middelen worden niet opnieuw ingepland;
//  - heractiveren maakt het middel weer actief, met schema intact.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:ritme/database/hive_database_helper.dart';
import 'package:ritme/services/notification_helper.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ritme_stop');
    Hive.init(dir.path);
    HiveDatabaseHelper.debugHiveDir = dir.path;
    HiveDatabaseHelper.recoveredBoxes.clear();
    await HiveDatabaseHelper.init();
  });

  tearDown(() async {
    HiveDatabaseHelper.debugHiveDir = null;
    await Hive.close(); // elke test een schone box-set, anders lekken data tussen tests
  });

  test('stoppen behoudt het schema, maar het middel valt uit de actieve lijst', () async {
    final db = HiveDatabaseHelper.instance;
    final id = await db.insertMedicationConfig('Olanzapine', '5', 'mg');
    await db.insertMedicationSchedule(id, '21:00', '1,2,3,4,5,6,7');

    await db.deleteMedicationConfig(id); // "Stoppen"

    expect(await db.getMedicationConfigs(), isEmpty,
        reason: 'gestopt middel mag niet in de dagelijkse lijst staan');
    expect((await db.getMedicationConfigsAll()).length, 1,
        reason: 'historie van het middel blijft bestaan');
    expect((await db.getMedicationSchedules()).length, 1,
        reason: 'het schema wordt bewaard zodat heractiveren weer werkt');
  });

  test('heractiveren zet het middel terug met schema intact', () async {
    final db = HiveDatabaseHelper.instance;
    final id = await db.insertMedicationConfig('Olanzapine', '5', 'mg');
    await db.insertMedicationSchedule(id, '21:00', '1,2,3,4,5,6,7');

    await db.deleteMedicationConfig(id);
    await db.reactivateMedicationConfig(id);

    final actief = await db.getMedicationConfigs();
    expect(actief.map((c) => c['id']), contains(id));
    expect((await db.getMedicationSchedules()).length, 1);
  });

  test('herinneringen worden alleen voor actieve middelen ingepland', () {
    final configs = [
      {'id': 1, 'naam': 'Lithium'},
      {'id': 2, 'naam': 'Olanzapine'},
    ];
    // Olanzapine (id 2) is gestopt en zit daarom NIET in getMedicationConfigs;
    // de out-lijst bevat alleen Lithium.
    final schedules = [
      {'id': 11, 'medication_id': 1, 'reminder_time': '21:00', 'enabled': '1'},
      {'id': 12, 'medication_id': 2, 'reminder_time': '07:30', 'enabled': '1'},
      {'id': 13, 'medication_id': 1, 'reminder_time': '08:00', 'enabled': '0'},
    ];
    final result = NotificationHelper.remindableSchedules(
        configs.where((c) => c['id'] == 1).toList(), schedules);
    expect(result.map((s) => s['id']), [11],
        reason: 'gestopte middelen en uitgeschakelde schedules krijgen geen herinnering');
  });
}
