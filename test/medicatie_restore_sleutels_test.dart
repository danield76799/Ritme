// Regressietest: na een backup-restore staan medicatie-configs onder
// STRING-sleutels in Hive (de restore schrijft box-entries met
// box.put(key.toString(), ...)). Verwijderen/updaten moet die rijen ook
// bereiken — voorheen schreef de code met put(int id, ...) een NIEUWE
// int-entry en bleef de zichtbare string-entry staan, waardoor "verwijderde"
// medicatie gewoon zichtbaar bleef (en dubbel in de lijst stond).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:ritme/database/hive_database_helper.dart';

const _boxen = [
  'settings', 'daily_logs', 'srm_activities', 'mood_assessment',
  'medication_config', 'medication_intake', 'medication_schedule',
  'life_events', 'weight_logs', 'medical_appointments', 'crisis_plan',
  'prodromal_checklist', 'prodromal_logs', 'episode_logs', 'daily_dagboek',
];

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('ritme_restore_test');
    Hive.init(tempDir.path);
    for (final naam in _boxen) {
      if (!Hive.isBoxOpen(naam)) await Hive.openBox(naam);
    }
  });

  setUp(() async {
    await Hive.box('medication_config').clear();
    await Hive.box('medication_intake').clear();
    await Hive.box('medication_schedule').clear();
  });

  test('verwijderen werkt ook voor string-sleutelde config (na restore)', () async {
    // Simuleer een rij zoals de backup-restore die schrijft: string-sleutel.
    await Hive.box('medication_config').put('42', {
      'id': 42,
      'naam': 'Testpil',
      'dosering': '100',
      'eenheid': 'mg',
      'reminder_enabled': '0',
    });

    final helper = HiveDatabaseHelper.instance;
    expect((await helper.getMedicationConfigs()).length, 1);

    await helper.deleteMedicationConfig(42);
    expect(await helper.getMedicationConfigs(), isEmpty,
        reason: 'na verwijderen mag de config niet meer zichtbaar zijn');
  });

  test('normalisatieCollabseert string- en int-sleutels tot één rij', () async {
    // Zoals na een restore: string-rij (origineel) + int-rij (door restore
    // opnieuw aangemaakt via upsert) naast elkaar.
    await Hive.box('medication_config').put('7', {
      'id': 7, 'naam': 'Dubbel', 'dosering': '50', 'eenheid': 'mg',
      'reminder_enabled': '0',
    });
    await Hive.box('medication_config').put(7, {
      'id': 7, 'naam': 'Dubbel', 'dosering': '50', 'eenheid': 'mg',
      'reminder_enabled': '0', 'deleted': '1',
    });

    await HiveDatabaseHelper.instance.normaliseerMedicationConfigSleutels();

    // Eén rij over; de int-variant (met delete-markering) wint.
    expect(Hive.box('medication_config').length, 1);
    expect(await HiveDatabaseHelper.instance.getMedicationConfigs(), isEmpty,
        reason: 'verwijderde int-rij blijft leidend na normalisatie');
  });

  test('upsert maakt geen dubbele entry naast een string-sleutelde rij', () async {
    await Hive.box('medication_config').put('9', {
      'id': 9, 'naam': 'Oud', 'dosering': '25', 'eenheid': 'mg',
      'reminder_enabled': '0',
    });

    await HiveDatabaseHelper.instance.upsertMedicationConfigById(
      9, 'Nieuw', '75', 'mg', reminderEnabled: false, zoNodig: false);

    expect(Hive.box('medication_config').length, 1,
        reason: 'upsert mag geen tweede entry naast de string-sleutelde rij maken');
    final configs = await HiveDatabaseHelper.instance.getMedicationConfigs();
    expect(configs.single['naam'], 'Nieuw');
    expect(configs.single['dosering'], '75');
  });
}
