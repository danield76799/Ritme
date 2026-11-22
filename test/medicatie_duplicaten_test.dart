// Test voor het samenvoegen van dubbele medicatie-registraties:
// groepering (puur) + de database-merge (innames verplaatsen, configs weg).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:ritme/database/hive_database_helper.dart';
import 'package:ritme/services/med_duplicaten.dart';
import 'package:ritme/service_locator.dart';

void main() {
  group('vindDubbeleMeds (puur)', () {
    test('groepeert op naam+dosering+eenheid, negeert eenlingen', () {
      final configs = [
        {'id': 1, 'naam': 'Olanzapine', 'dosering': '2.5', 'eenheid': 'mg'},
        {'id': 2, 'naam': 'olanzapine ', 'dosering': '2,5', 'eenheid': 'mg',
         'deleted': '1', 'stopped_at': '2026-11-22'},
        {'id': 3, 'naam': 'Lurasidon', 'dosering': '74', 'eenheid': 'mg'},
      ];
      final groepen = vindDubbeleMeds(configs);
      expect(groepen, hasLength(1));
      expect(groepen.first.keeper['id'], 1,
          reason: 'actieve config blijft de keeper');
      expect(groepen.first.verwijderen.map((m) => m['id']), [2]);
    });

    test('actieve config wint van gestopte; leeftijd beslist bij gelijke status', () {
      final configs = [
        {'id': 9, 'naam': 'X', 'dosering': '5', 'eenheid': 'mg', 'deleted': '1'},
        {'id': 3, 'naam': 'X', 'dosering': '5', 'eenheid': 'mg', 'deleted': '1'},
        {'id': 7, 'naam': 'X', 'dosering': '5', 'eenheid': 'mg'},
      ];
      final groepen = vindDubbeleMeds(configs);
      expect(groepen.single.keeper['id'], 7);
      expect(groepen.single.verwijderen.map((m) => m['id']).toSet(), {3, 9});
    });
  });

  group('mergeDubbeleMeds (hive)', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('ritme_dup');
      Hive.init(dir.path);
      HiveDatabaseHelper.debugHiveDir = dir.path;
      HiveDatabaseHelper.recoveredBoxes.clear();
      await HiveDatabaseHelper.init();
      setDbForTesting(HiveDatabaseHelper.instance);
    });

    tearDown(() async {
      HiveDatabaseHelper.debugHiveDir = null;
      await Hive.close();
    });

    test('innames verhuizen mee, dubbele configs verdwijnen, actieve blijft', () async {
      final db = HiveDatabaseHelper.instance;

      final actiefId = await db.insertMedicationConfig('Olanzapine', '2.5', 'mg');
      // Simuleer een gestopte dubbele registratie + innames op die config.
      final gestoptId = await db.insertMedicationConfig('Olanzapine', '2.5', 'mg');
      await db.insertMedicationIntake('2026-11-20', gestoptId, 1);
      await db.insertMedicationIntake('2026-11-21', gestoptId, 1);
      await db.insertMedicationIntake('2026-11-22', actiefId, 1);
      // Gestopt markeren (zonder schedule-cleanup, zoals in productie)
      await db.deleteMedicationConfig(gestoptId);

      final alle = await db.getMedicationConfigsAll();
      final groepen = vindDubbeleMeds(alle);
      expect(groepen, hasLength(1));

      final n = await mergeDubbeleMeds(groepen);
      expect(n, 1);

      final over = await db.getMedicationConfigsAll();
      expect(over.map((c) => c['id']), [actiefId]);

      final innames = await db.getMedicationIntakeRange('2026-11-01', '2026-11-30');
      final perMed = <int, int>{};
      for (final r in innames) {
        perMed[(r['medication_id'] as int)] = (perMed[(r['medication_id'] as int)] ?? 0) + 1;
      }
      expect(perMed[actiefId], 3, reason: 'alle innames hangen nu aan de actieve config');
      expect(perMed.containsKey(gestoptId), isFalse);
    });
  });
}
