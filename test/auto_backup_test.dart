// Tests voor de automatische backup (09-2026).
//
// - Interval-logica is puur (geen DB) en direct testbaar.
// - Bestandsnaam is één bestand per ISO-week dat overschreven wordt
//   (geen timestamp-stapel in Downloads).
// - Opruiming houdt de nieuwste weken, raakt handmatige backups niet aan.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/services/backup_service.dart';

void main() {
  final nu = DateTime(2026, 9, 15, 8, 0); // di, week 38

  group('autoBackupVerschuldigd: interval per frequentie', () {
    test('uit doet nooit iets', () {
      expect(BackupService.autoBackupVerschuldigd('uit', null, nu), isFalse);
      expect(
        BackupService.autoBackupVerschuldigd('uit', '2020-01-01T00:00:00', nu),
        isFalse,
      );
    });

    test('onbekende frequentie doet niets', () {
      expect(BackupService.autoBackupVerschuldigd('maandelijks', null, nu), isFalse);
    });

    test('nog nooit gehad -> verschuldigd (behalve uit)', () {
      expect(BackupService.autoBackupVerschuldigd('dagelijks', null, nu), isTrue);
      expect(BackupService.autoBackupVerschuldigd('3dagen', '', nu), isTrue);
      expect(BackupService.autoBackupVerschuldigd('week', 'geen-datum', nu), isTrue);
    });

    test('dagelijks: gisteren wel, vandaag niet', () {
      expect(
        BackupService.autoBackupVerschuldigd(
            'dagelijks', '2026-09-14T08:00:00', nu),
        isTrue,
      );
      expect(
        BackupService.autoBackupVerschuldigd(
            'dagelijks', '2026-09-15T07:59:00', nu),
        isFalse,
      );
    });

    test('3 dagen: 2 dagen geleden niet, 3 dagen geleden wel', () {
      expect(
        BackupService.autoBackupVerschuldigd('3dagen', '2026-09-13T08:00:00', nu),
        isFalse,
      );
      expect(
        BackupService.autoBackupVerschuldigd('3dagen', '2026-09-12T08:00:00', nu),
        isTrue,
      );
    });

    test('week: 6 dagen geleden niet, 7 dagen geleden wel', () {
      expect(
        BackupService.autoBackupVerschuldigd('week', '2026-09-09T08:00:00', nu),
        isFalse,
      );
      expect(
        BackupService.autoBackupVerschuldigd('week', '2026-09-08T08:00:00', nu),
        isTrue,
      );
    });
  });

  group('autoBackupBestandsnaam: één bestand per ISO-week', () {
    test('vandaag heet 2026-W38', () {
      expect(
        BackupService.autoBackupBestandsnaam(nu),
        'ritme_backup_auto_2026-W38.json',
      );
    });

    test('zelfde week, andere dag -> zelfde naam (overschrijven)', () {
      expect(
        BackupService.autoBackupBestandsnaam(DateTime(2026, 9, 20)),
        BackupService.autoBackupBestandsnaam(nu),
      );
    });

    test('jaargrens volgt het ISO-weekjaar, niet de kalender', () {
      // 29-12-2025 (ma) valt in week 1 van 2026.
      expect(
        BackupService.autoBackupBestandsnaam(DateTime(2025, 12, 29)),
        'ritme_backup_auto_2026-W01.json',
      );
      expect(
        BackupService.autoBackupBestandsnaam(DateTime(2026, 1, 1)),
        'ritme_backup_auto_2026-W01.json',
      );
    });

    test('weeknummer hangt niet van het tijdstip af (DST-val)', () {
      // Regressie: met lokale middernachten gaf 20-09-2026 00:00 W37 en
      // 15-09-2026 08:00 W38 (zomertijd-uur). Nu overal W38.
      for (final uur in [0, 8, 23]) {
        expect(
          BackupService.autoBackupBestandsnaam(DateTime(2026, 9, 20, uur)),
          'ritme_backup_auto_2026-W38.json',
        );
      }
    });

    test('week 53 bestaat (2026 heeft er een)', () {
      expect(BackupService.isoWeekNummer(DateTime(2026, 12, 31)), 53);
      expect(
        BackupService.autoBackupBestandsnaam(DateTime(2026, 12, 31)),
        'ritme_backup_auto_2026-W53.json',
      );
    });
  });

  group('ruimOudeAutoBackupsOp: weken bewaren, handmatig sparen', () {
    test('houdt de nieuwste 4, verwijdert oudere weken', () async {
      final dir = await Directory.systemTemp.createTemp('autobackup');
      try {
        for (var i = 0; i < 6; i++) {
          final f = File('${dir.path}/ritme_backup_auto_2026-W${30 + i}.json');
          await f.writeAsString('{}');
          await f.setLastModified(DateTime(2026, 7, 20 + i));
        }
        await BackupService.ruimOudeAutoBackupsOp(dir);
        final over = dir
            .listSync()
            .whereType<File>()
            .map((f) => f.path.split('/').last)
            .toList()
          ..sort();
        expect(over, [
          'ritme_backup_auto_2026-W32.json',
          'ritme_backup_auto_2026-W33.json',
          'ritme_backup_auto_2026-W34.json',
          'ritme_backup_auto_2026-W35.json',
        ]);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('handmatige backups blijven altijd staan', () async {
      final dir = await Directory.systemTemp.createTemp('autobackup2');
      try {
        final handmatig = File('${dir.path}/ritme_backup_2026-01-01.json');
        await handmatig.writeAsString('{}');
        await handmatig.setLastModified(DateTime(2025, 1, 1));
        for (var i = 0; i < 5; i++) {
          final f = File('${dir.path}/ritme_backup_auto_2026-W${30 + i}.json');
          await f.writeAsString('{}');
          await f.setLastModified(DateTime(2026, 7, 20 + i));
        }
        await BackupService.ruimOudeAutoBackupsOp(dir);
        expect(await handmatig.exists(), isTrue);
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
