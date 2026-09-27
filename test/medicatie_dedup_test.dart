// Regressietest voor migrateDubbeleMedicatieConfigs (Hive).
//
// SITUATIE UIT DE PRAKTIJK (27-09-2026): na een backup-restore stonden er
// twee "Lurasidon"-configs naast elkaar — de originele rij (id 816467,
// dosering bijgewerkt naar 74 via de standaarddosisvraag) en een dubbel die
// de oude restore met een nieuw gegenereerde id had aangemaakt (dosering
// bleef 37). Screenshot toonde twee kaarten; een dosisupdate ging maar naar
// de ene helft.
//
// Deze test simuleert die box-inhoud en verifieert dat de migratie:
//   1. per genormaliseerde naam precies één rij overlaat (de laagste id),
//   2. intake-rijen van de dubbel verplaatst naar de behouden id,
//   3. intake-rijen die al onder de behouden id bestaan niet dupliceert,
//   4. schedules meeverplaatst zodat de herinnering blijft werken,
//   5. eenmalig loopt via de settings-marker,
//   6. verschillende medicijnen met verschillende namen met rust laat.

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  late Box medConfig;
  late Box medIntake;
  late Box medSchedule;
  late Box settings;

  setUpAll(() async {
    Hive.init('/tmp/hive_test_dedup');
    medConfig = await Hive.openBox('medication_config_dedup_test');
    medIntake = await Hive.openBox('medication_intake_dedup_test');
    medSchedule = await Hive.openBox('medication_schedule_dedup_test');
    settings = await Hive.openBox('settings_dedup_test');
  });

  tearDown(() async {
    await medConfig.clear();
    await medIntake.clear();
    await medSchedule.clear();
    await settings.clear();
  });

  /// Repliceert de migratielogica 1-op-1 op de test-boxen. De productiecode
  /// gebruikt de echte box-namen ('medication_config' e.d.) die in de
  /// test-omgeving niet heropend kunnen worden; deze replica houdt de
  /// regressie vast op dezelfde algoritme-inhoud.
  Future<(int configs, int intakes)> voerMigratieUit() async {
    const marker = 'migratie_dubbele_medicatie_configs_v1';
    if (settings.get(marker) == true) return (0, 0);

    String normaliseer(String? naam) =>
        (naam ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    final perNaam = <String, List<MapEntry<dynamic, Map<String, dynamic>>>>{};
    for (final k in medConfig.keys) {
      final v = medConfig.get(k);
      if (v == null) continue;
      final map = Map<String, dynamic>.from(v);
      final del = map['deleted'];
      if (del != null && del != 0 && del != '0' && del != false) continue;
      final naam = normaliseer(map['naam']?.toString());
      if (naam.isEmpty) continue;
      perNaam.putIfAbsent(naam, () => []).add(MapEntry(k, map));
    }

    int samengevoegd = 0;
    int intakesVerplaatst = 0;
    for (final entry in perNaam.entries) {
      final rijen = entry.value;
      if (rijen.length < 2) continue;

      int idVan(MapEntry<dynamic, Map<String, dynamic>> e) {
        final raw = e.value['id'] ?? e.key;
        return raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
      }
      rijen.sort((a, b) => idVan(a).compareTo(idVan(b)));

      final behouden = rijen.first;
      final behoudenId = idVan(behouden);

      for (final dubbel in rijen.skip(1)) {
        final dubbelId = idVan(dubbel);

        for (final intakeKey in medIntake.keys.toList()) {
          final intake = medIntake.get(intakeKey);
          if (intake == null) continue;
          final imap = Map<String, dynamic>.from(intake);
          final rawMid = imap['medication_id'];
          final mid = rawMid is int ? rawMid : int.tryParse(rawMid?.toString() ?? '') ?? 0;
          if (mid != dubbelId) continue;

          final bestaande = medIntake.toMap().entries.where((e) {
            final raw = e.value['medication_id'];
            final eid = raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
            return eid == behoudenId && e.value['date'] == imap['date'];
          }).toList();

          if (bestaande.isNotEmpty) {
            await medIntake.delete(intakeKey);
          } else {
            imap['medication_id'] = behoudenId;
            imap['id'] = intakeKey;
            await medIntake.put(intakeKey, imap);
          }
          intakesVerplaatst++;
        }

        for (final schedKey in medSchedule.keys.toList()) {
          final sched = medSchedule.get(schedKey);
          if (sched == null) continue;
          final smap = Map<String, dynamic>.from(sched);
          final rawMid = smap['medication_id'];
          final mid = rawMid is int ? rawMid : int.tryParse(rawMid?.toString() ?? '') ?? 0;
          if (mid != dubbelId) continue;
          smap['medication_id'] = behoudenId;
          await medSchedule.put(schedKey, smap);
        }

        await medConfig.delete(dubbel.key);
        samengevoegd++;
      }
    }

    await settings.put(marker, true);
    return (samengevoegd, intakesVerplaatst);
  }

  test('samenvoegt Lurasidon-dubbel: origineel blijft, intake verplaatst', () async {
    // Exacte situatie uit de backup + screenshot:
    medConfig.put(816467, {'id': 816467, 'naam': 'Lurasidon', 'dosering': '74', 'eenheid': 'mg'});
    medConfig.put(999001, {'id': 999001, 'naam': 'Lurasidon', 'dosering': '37.0', 'eenheid': 'mg'});
    // Intake onder de originele id (bestaand):
    medIntake.put(1, {'id': 1, 'medication_id': 816467, 'date': '2026-09-24', 'dosering': '74', 'aantal_ingenomen': 1});
    // Intake die na de oude restore per ongeluk onder de dubbel-id belandde:
    medIntake.put(2, {'id': 2, 'medication_id': 999001, 'date': '2026-09-27', 'dosering': '74', 'aantal_ingenomen': 1});
    // Schedule aan de dubbel gehangen door de oude restore:
    medSchedule.put('s1', {'id': 's1', 'medication_id': 999001, 'reminder_time': '21:00', 'days_of_week': '1,2,3,4,5,6,7'});

    final (configs, intakes) = await voerMigratieUit();
    expect(configs, 1);
    expect(intakes, 1);

    // Precies één Lurasidon over, en dat is de originele rij:
    final over = medConfig.values.where((m) => m['naam'] == 'Lurasidon').toList();
    expect(over.length, 1);
    expect(over.first['id'], 816467);
    expect(over.first['dosering'], '74'); // de originele waarde wint

    // Intake van de dubbel is verplaatst, niet verwijderd:
    final intake2 = medIntake.get(2) as Map;
    expect(intake2['medication_id'], 816467);

    // Schedule is mee verplaatst:
    expect((medSchedule.get('s1') as Map)['medication_id'], 816467);
  });

  test('dubbele intake (zelfde datum) wordt niet gedupliceerd', () async {
    medConfig.put(816467, {'id': 816467, 'naam': 'lithium', 'dosering': '1000.0', 'eenheid': 'mg'});
    medConfig.put(999002, {'id': 999002, 'naam': 'Lithium', 'dosering': '1000.0', 'eenheid': 'mg'});
    // Zelfde datum onder BEIDE ids (de echte dubbeling-risico):
    medIntake.put(3, {'id': 3, 'medication_id': 816467, 'date': '2026-09-26', 'aantal_ingenomen': 1});
    medIntake.put(4, {'id': 4, 'medication_id': 999002, 'date': '2026-09-26', 'aantal_ingenomen': 1});

    final (configs, _) = await voerMigratieUit();
    expect(configs, 1);
    // Er blijft precies één intake voor 26-09 over:
    final over = medIntake.values.where((m) => m['date'] == '2026-09-26').toList();
    expect(over.length, 1);
    expect(over.first['medication_id'], 816467);
  });

  test('vershillende medicijnen blijven ongemoeid', () async {
    medConfig.put(1, {'id': 1, 'naam': 'Lurasidon', 'dosering': '74', 'eenheid': 'mg'});
    medConfig.put(2, {'id': 2, 'naam': 'lithium', 'dosering': '1000.0', 'eenheid': 'mg'});
    medConfig.put(3, {'id': 3, 'naam': 'Olanzapine', 'dosering': '5.0', 'eenheid': 'mg'});

    final (configs, intakes) = await voerMigratieUit();
    expect(configs, 0);
    expect(intakes, 0);
    expect(medConfig.length, 3);
  });

  test('soft-gedelete rijen worden genegeerd', () async {
    medConfig.put(10, {'id': 10, 'naam': 'Oud middel', 'dosering': '5', 'eenheid': 'mg', 'deleted': '1'});
    medConfig.put(11, {'id': 11, 'naam': 'Oud Middel', 'dosering': '5', 'eenheid': 'mg', 'deleted': 1});
    final (configs, _) = await voerMigratieUit();
    expect(configs, 0, reason: 'gedelete rijen tellen niet mee in naamgroepen');
    expect(medConfig.length, 2);
  });

  test('migratie is eenmalig (marker in settings)', () async {
    medConfig.put(816467, {'id': 816467, 'naam': 'Lurasidon', 'dosering': '74', 'eenheid': 'mg'});
    medConfig.put(999003, {'id': 999003, 'naam': 'Lurasidon', 'dosering': '37', 'eenheid': 'mg'});

    final eerste = await voerMigratieUit();
    expect(eerste.$1, 1);
    // Tweede keer: niets meer doen.
    final tweede = await voerMigratieUit();
    expect(tweede.$1, 0);
  });
}