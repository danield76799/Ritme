import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ritme/database/hive_database_helper.dart';

/// Regressietests voor de slaapduur- en medicatiebugs op Android (Hive).
///
/// Elke test is rood bewezen tegen de code van vóór de fix.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('/tmp/ritme_databank_fix_test');
    for (final b in [
      'settings',
      'daily_logs',
      'srm_activities',
      'medication_config',
      'medication_intake',
      'medication_schedule',
    ]) {
      await Hive.openBox(b);
    }
  });

  tearDownAll(() async => Hive.deleteFromDisk());

  tearDown(() async {
    for (final b in [
      'settings',
      'daily_logs',
      'srm_activities',
      'medication_config',
      'medication_intake',
      'medication_schedule',
    ]) {
      await Hive.box(b).clear();
    }
  });

  group('slaapduur', () {
    test('corrigeren van de bedtijd werkt de slaapduur echt bij', () async {
      final helper = HiveDatabaseHelper.instance;
      const dag = '2026-09-25';

      // Oud: 23:00 -> 08:30, 30 min wakker = 9,0 uur.
      await helper.insertSleepLog(dag, '23:00', '08:30', 30);
      // Gecorrigeerd: 21:15 -> 08:30, 30 min wakker = 10,75 uur.
      await helper.insertSleepLog(dag, '21:15', '08:30', 30);

      final bestaand = await helper.getDailyLog(dag);
      final log = bestaand != null
          ? Map<String, dynamic>.from(bestaand)
          : <String, dynamic>{};
      log['date'] = dag;
      log['uren_slaap'] = 10.75;
      await helper.upsertDailyLog(log);

      final rij = (await helper.getDailyLogs()).firstWhere((l) => l['date'] == dag);

      expect(
        double.tryParse(rij['sleep_hours'].toString()),
        closeTo(10.75, 0.01),
        reason: 'bedtijd 21:15 hoort 10,75 uur te geven, niet 9,0',
      );
    });

    test('corrigeren stapelt geen tweede slaaprij', () async {
      final helper = HiveDatabaseHelper.instance;
      const dag = '2026-09-25';

      await helper.insertSleepLog(dag, '23:00', '08:30', 30);
      await helper.insertSleepLog(dag, '21:15', '08:30', 30);

      final slaaprijen = Hive.box('daily_logs')
          .toMap()
          .entries
          .where((e) => e.value['date'] == dag && e.value['sleep_hours'] != null)
          .toList();

      expect(slaaprijen.length, 1,
          reason: 'corrigeren is bijwerken, niet een rij erbij zetten');
    });

    test('avond-bedtijd wordt niet overschreven door de ochtendrij', () async {
      final helper = HiveDatabaseHelper.instance;
      const dag = '2026-09-26';

      await helper.insertSleepLog(dag, '23:00', '08:30', 30);
      await helper.upsertDailyLog({
        'date': dag,
        'id': dag,
        'bed_time': '22:30',
        'stemming_hoog': '7',
      });

      final rij = (await helper.getDailyLogs()).firstWhere((l) => l['date'] == dag);

      expect(rij['bed_time'], '22:30',
          reason: 'de avond-check-in beschrijft de nacht die nog komt');
      expect(rij['stemming_hoog'], '7',
          reason: 'de dagrij mag niet verdwijnen bij het samenvoegen');
    });
  });

  group('medicatie', () {
    test('dosering aanpassen levert geen tweede medicijn op', () async {
      final helper = HiveDatabaseHelper.instance;
      final id = await helper.insertMedicationConfig('Lurasidon', '50', 'mg');

      await helper.updateMedicationConfig(id, {
        'naam': 'Lurasidon',
        'dosering': '74',
        'eenheid': 'mg',
        'reminder_enabled': 1,
      });

      final configs = await helper.getMedicationConfigs();
      expect(configs.length, 1);
      expect(configs.first['dosering'], '74');
    });

    test('gemigreerde data (id als string) levert geen tweede inname op', () async {
      // De SQLite->Hive migratie zet medication_id om naar een string.
      await Hive.box('medication_intake').put(111, {
        'id': 111,
        'date': '2026-09-24',
        'medication_id': '555',
        'aantal_ingenomen': '1',
      });

      final helper = HiveDatabaseHelper.instance;
      await helper.insertMedicationIntakeMap({
        'medication_id': 555,
        'date': '2026-09-24',
        'aantal_ingenomen': 1,
      });

      final rijen = Hive.box('medication_intake')
          .toMap()
          .entries
          .where((e) => e.value['date'] == '2026-09-24')
          .toList();

      expect(rijen.length, 1,
          reason: 'string-id en int-id zijn hetzelfde medicijn');
    });

    test('medicijn verwijderen wist de inname-historie niet', () async {
      final helper = HiveDatabaseHelper.instance;
      final id = await helper.insertMedicationConfig('Lurasidon', '74', 'mg');

      for (final d in ['2026-09-22', '2026-09-23', '2026-09-24']) {
        await helper.insertMedicationIntakeMap({
          'medication_id': id,
          'date': d,
          'aantal_ingenomen': 1,
        });
      }

      await helper.deleteMedicationConfig(id);

      expect((await helper.getMedicationIntake('2026-09-23')).length, 1,
          reason: 'innames zijn historie; die horen niet mee te verdwijnen');
      expect(await helper.getMedicationConfigs(), isEmpty,
          reason: 'het medicijn zelf moet wel uit de lijst');
    });

    test('dertig innames achter elkaar raken geen rij kwijt', () async {
      final helper = HiveDatabaseHelper.instance;
      final id = await helper.insertMedicationConfig('Lurasidon', '74', 'mg');

      final datums = <String>[];
      for (int d = 1; d <= 30; d++) {
        final dag = '2026-08-${d.toString().padLeft(2, '0')}';
        datums.add(dag);
        await helper.insertMedicationIntakeMap({
          'medication_id': id,
          'date': dag,
          'aantal_ingenomen': 1,
        });
      }

      final box = Hive.box('medication_intake');
      final bewaard = box.toMap().values.map((v) => v['date']).toList();
      final kwijt = datums.where((d) => !bewaard.contains(d)).toList();

      expect(box.length, 30,
          reason: 'twee schrijfacties binnen 16 min 40 s mogen niet botsen '
              'op dezelfde sleutel; kwijt: $kwijt');
    });
  });

  group('backup-restore', () {
    test('een restore overschrijft geen bestaande activiteiten', () async {
      // `insertSrmActivityMap` (de restore-weg) koos zijn sleutel uit
      // `_nextId++`, dat in ELKE app-start weer op 1 begon. Staat er al een rij
      // met sleutel 1 in de box, dan schrijft een restore daaroverheen.
      //
      // Nagebootst door sleutel 1 en 2 al in de box te zetten; een verse
      // testproces-start laat `_nextId` weer bij 1 beginnen — precies de
      // productiesituatie.
      final box = Hive.box('srm_activities');
      await box.put(1, {
        'id': 1, 'date': '2026-09-19', 'activity_type': 'opstaan',
        'actual_time': '07:00', 'p_score': '3',
      });
      await box.put(2, {
        'id': 2, 'date': '2026-09-20', 'activity_type': 'opstaan',
        'actual_time': '07:05', 'p_score': '3',
      });

      final helper = HiveDatabaseHelper.instance;
      await helper.insertSrmActivityMap({
        'date': '2026-09-21',
        'activity_type': 'opstaan',
        'actual_time': '07:30',
        'p_score': 3,
      });

      final datums = box.toMap().values.map((v) => v['date']).toList();
      print('  rijen: ${box.length}, datums: $datums');

      expect(datums.contains('2026-09-19'), isTrue,
          reason: 'de restore mag de oudste rij niet overschrijven');
      expect(datums.contains('2026-09-21'), isTrue);
    });
  });
}
