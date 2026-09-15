// Borgt settings_extra (09-2026): vrije instellingssleutels (backupmap,
// backupfrequentie) braken op SQLite met SQLITE_ERROR omdat de
// settings-tabel vaste kolommen heeft. Alles buiten de vaste kolommen gaat
// nu naar settings_extra — nooit meer een migratie per sleutel.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _code(String pad) {
  final c = File(pad).readAsStringSync();
  final zonderBlok = c.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return zonderBlok
      .split('\n')
      .map((r) => r.replaceAll(RegExp(r'//.*$'), ''))
      .join('\n');
}

void main() {
  group('settings_extra: vrije sleutels zonder SQLITE_ERROR', () {
    test('versie 6 met extra-tabel in create én upgrade', () {
      final code = _code('lib/database/database_helper.dart');
      expect(code.contains('version: 6'), isTrue);
      expect(code.contains('CREATE TABLE IF NOT EXISTS settings_extra'),
          isTrue);
      expect(code.contains('if (oldVersion < 6)'), isTrue,
          reason: 'bestaande installaties migreren mee');
    });

    test('updateSettingsMap splitst bekend en extra', () {
      final code = _code('lib/database/database_helper.dart');
      expect(code.contains('_settingsKolommen'), isTrue);
      expect(code.contains("'biometric_enabled'"), isTrue,
          reason: 'eerder per kolom toegevoegd — blijft werken');
      expect(code.contains('settings_extra'), isTrue);
      expect(code.contains('ConflictAlgorithm.replace'), isTrue,
          reason: 'zelfde sleutel overschrijven (upsert)');
      // Binnen updateSettingsMap geen ruwe map meer naar db (dat gooide
      // SQLITE_ERROR bij onbekende sleutels). NB: de ongebruikte
      // updateSettings(username, ...) laat ik met rust (interface, dood).
      final start = code.indexOf('Future<int> updateSettingsMap(');
      expect(start, greaterThan(-1));
      final stop = code.indexOf('@override', start + 10);
      final blok = code.substring(start, stop > start ? stop : start + 2000);
      expect(blok.contains("db.update('settings', settings,"), isFalse,
          reason: 'ruwe map gooide SQLITE_ERROR bij onbekende sleutels');
      expect(blok.contains("db.insert('settings', settings)"), isFalse);
    });

    test('getSettings plakt extras erbij', () {
      final code = _code('lib/database/database_helper.dart');
      final start = code.indexOf('Future<Map<String, dynamic>?> getSettings()');
      expect(start, greaterThan(-1));
      final stop = code.indexOf('insertSettings', start);
      final blok = code.substring(start, stop > start ? stop : start + 800);
      expect(blok.contains('settings_extra'), isTrue);
    });

    test('wisBackupMap werkt met lege strings (geen delete nodig)', () {
      final code = _code('lib/services/backup_map_service.dart');
      expect(code.contains("merged[mapUriKey] = '';"), isTrue);
      expect(code.contains('.remove(mapUriKey)'), isFalse,
          reason: 'remove haalt niets uit settings_extra');
    });

    test('backup-services gaan via de locator, niet direct SQLite', () {
      // 09-2026: op Android is Hive leidend; BackupService en
      // BackupMapService schreven direct naar SQLite — een tweede,
      // onzichtbare database. UI zag nooit map, frequentie of datum.
      for (final pad in [
        'lib/services/backup_service.dart',
        'lib/services/backup_map_service.dart',
      ]) {
        final code = _code(pad);
        expect(code.contains('DatabaseHelper.instance'), isFalse,
            reason: '$pad omzeilt de locator');
        expect(code.contains('service_locator'), isTrue,
            reason: '$pad gebruikt de locator');
      }
    });
  });
}
