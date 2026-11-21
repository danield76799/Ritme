// Borgt het settings-contract: vrije instellingssleutels (backupmap,
// backupfrequentie, ...) moeten foutloos heen en weer gaan. Voorheen (SQLite)
// had de settings-tabel vaste kolommen en faalden vrije sleutels met
// SQLITE_ERROR; Hive slaat willekeurige sleutels native op. Sinds de
// iOS/SQLite-tak verwijderd is (11-2026), leunt dit bestand op de Hive-implementatie.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:ritme/database/hive_database_helper.dart';
import 'package:ritme/service_locator.dart';

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('ritme_settings_test');
    Hive.init(dir.path);
    for (final naam in ['settings']) {
      if (!Hive.isBoxOpen(naam)) await Hive.openBox(naam);
    }
    setDbForTesting(HiveDatabaseHelper.instance);
  });

  setUp(() async {
    await Hive.box('settings').clear();
  });

  test('vrije sleutels gaan verliesvrij heen en weer (Hive)', () async {
    final db = HiveDatabaseHelper.instance;
    await db.updateSettingsMap({'backup_map_uri': 'content://example', 'backup_map_naam': 'Backups'});
    final s = await db.getSettings();
    expect(s, isNotNull);
    expect(s!['backup_map_uri'], 'content://example');
    expect(s['backup_map_naam'], 'Backups');
  });

  test('twee keer schrijven naar dezelfde sleutel overschrijft netjes', () async {
    final db = HiveDatabaseHelper.instance;
    await db.updateSettingsMap({'backup_freq': 'week'});
    await db.updateSettingsMap({'backup_freq': 'maand'});
    final s = await db.getSettings();
    expect(s!['backup_freq'], 'maand');
  });

  test('backup-services gaan via de locator, niet direct naar een losse database', () {
    for (final pad in [
      'lib/services/backup_service.dart',
      'lib/services/backup_map_service.dart',
    ]) {
      final code = File(pad).readAsStringSync();
      expect(code.contains('DatabaseHelper.instance'), isFalse,
          reason: 'omzeilt de locator');
      expect(code.contains('service_locator'), isTrue,
          reason: 'gebruikt de locator');
    }
  });
}
