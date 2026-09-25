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
    test('standaard is wekelijks: verse installatie krijgt backups', () {
      expect(BackupService.freqStandaard, BackupService.freqWeek);
      // Verse installatie: geen frequentie én geen laatste -> verschuldigd.
      expect(BackupService.autoBackupVerschuldigd(BackupService.freqStandaard, null, nu), isTrue);
    });

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

    test('dagelijkse frequentie krijgt een DATUMnaam, niet een weeknaam', () {
      // Regressie 09-2026: de naam was ALTIJD per week. Met 'dagelijks'
      // schreef elke dag naar hetzelfde weekbestand en overschreef de vorige,
      // dus de gebruiker zag één bestand per week in plaats van per dag.
      final ma = BackupService.autoBackupBestandsnaam(
          DateTime(2026, 9, 21), freq: BackupService.freqDagelijks);
      final di = BackupService.autoBackupBestandsnaam(
          DateTime(2026, 9, 22), freq: BackupService.freqDagelijks);
      final wo = BackupService.autoBackupBestandsnaam(
          DateTime(2026, 9, 23), freq: BackupService.freqDagelijks);

      expect(ma, 'ritme_backup_auto_2026-09-21.json');
      expect(di, 'ritme_backup_auto_2026-09-22.json');
      expect(wo, 'ritme_backup_auto_2026-09-23.json');
      expect({ma, di, wo}.length, 3,
          reason: 'drie dagen in dezelfde week = drie bestanden');
    });

    test('3dagen krijgt ook een datumnaam', () {
      expect(
        BackupService.autoBackupBestandsnaam(DateTime(2026, 9, 25),
            freq: BackupService.freq3Dagen),
        'ritme_backup_auto_2026-09-25.json',
      );
    });

    test('weekfrequentie houdt de weeknaam', () {
      expect(
        BackupService.autoBackupBestandsnaam(DateTime(2026, 9, 25),
            freq: BackupService.freqWeek),
        'ritme_backup_auto_2026-W39.json',
      );
      // En zonder freq (standaard) ook.
      expect(
        BackupService.autoBackupBestandsnaam(DateTime(2026, 9, 25)),
        'ritme_backup_auto_2026-W39.json',
      );
    });

    test('twee runs op dezelfde dag overschrijven elkaar (dat is de bedoeling)', () {
      final ochtend = BackupService.autoBackupBestandsnaam(
          DateTime(2026, 9, 25, 7), freq: BackupService.freqDagelijks);
      final avond = BackupService.autoBackupBestandsnaam(
          DateTime(2026, 9, 25, 22), freq: BackupService.freqDagelijks);
      expect(ochtend, avond);
    });

    test('de bewaartermijn hangt van de frequentie af', () {
      // Vier bestanden is bij 'dagelijks' maar vier dagen geschiedenis.
      expect(BackupService.autoBackupBehoudVoor(BackupService.freqDagelijks),
          greaterThan(BackupService.autoBackupBehoud));
      expect(
          BackupService.autoBackupBehoudVoor(BackupService.freqWeek),
          BackupService.autoBackupBehoud);
      // Dekking blijft in de buurt van een maand.
      for (final f in [BackupService.freqDagelijks, BackupService.freq3Dagen]) {
        expect(BackupService.autoBackupBehoudVoor(f) >= 10, isTrue,
            reason: 'minimaal 10 bestanden bij een dagfrequentie');
      }
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

  group('saveLocalBackup: terugval bij geblokkeerde Downloads (structuur)', () {
    test('schrijft altijd, valt terug op de app-map', () {
      // Regressie 09-2026: op moderne Android (scoped storage) gooide
      // writeAsString naar Downloads — elke opstart faalde stil en er kwam
      // nooit een backup ("nog nooit"). Nu: pogingen-lus met terugval.
      final code = File('lib/services/backup_service.dart').readAsStringSync();
      final start = code.indexOf('saveLocalBackup({bool auto');
      expect(start, greaterThan(-1));
      final stop = code.indexOf('ruimOudeAutoBackupsOp(Directory dir', start);
      final blok = code.substring(start, stop > start ? stop : start + 3000);
      expect(
          blok.contains(
              'pogingen.add(await getApplicationDocumentsDirectory())'),
          isTrue,
          reason: 'app-map zit altijd in de pogingen');
      expect(blok.contains('laatsteFout'), isTrue,
          reason: 'schrijffout per poging wordt bijgehouden');
      expect(blok.contains('Backup schrijven mislukt'), isTrue,
          reason: 'pas gooien als ALLES faalt');
    });

    test('mislukte auto-backup wordt gelogd, niet stilgeslikt', () {
      final code = File('lib/services/backup_service.dart').readAsStringSync();
      expect(code.contains('AppLogger.error'), isTrue);
    });
  });

  group('SAF-backupmap: gekozen map eerst (structuur)', () {
    test('saveLocalBackup probeert de SAF-map vóór Downloads', () {
      // Zonder gekozen map overleeft de backup de-installatie niet.
      final code = File('lib/services/backup_service.dart').readAsStringSync();
      final saf = code.indexOf('BackupMapService.schrijf(');
      final downloads = code.indexOf('/storage/emulated/0/Download');
      expect(saf, greaterThan(-1));
      expect(downloads, greaterThan(-1));
      expect(saf, lessThan(downloads),
          reason: 'gekozen map eerst, dan pas Downloads/app-map');
    });

    test('mapkeuze wordt bewaard (uri + naam) en wisbaar', () {
      final code =
          File('lib/services/backup_map_service.dart').readAsStringSync();
      expect(code.contains('pickDirectory'), isTrue);
      expect(code.contains('persistablePermission'), isTrue,
          reason: 'toestemming overleeft herstarts (staat default aan)');
      expect(code.contains('overwrite: true'), isTrue,
          reason: 'zelfde weekbestand overschrijven');
      expect(code.contains('wisBackupMap'), isTrue,
          reason: 'dode toestemming wordt opgeruimd');
    });

    test('instellingen tonen de map of waarschuwen', () {
      final code =
          File('lib/screens/settings_screen.dart').readAsStringSync();
      expect(code.contains('backupMapTitel'), isTrue);
      expect(code.contains('geenMapUitleg'), isTrue,
          reason: 'zonder map: backup weg bij verwijderen');
      expect(code.contains('_kiesBackupMap'), isTrue);
    });

    test('mislukte keuze toont de fout, lege naam valt terug op uri', () {
      // "Ik koos een map maar er staat Niet gekozen" (09-2026): het pakket
      // is solide, dus de stilte zat in onze UI. Nu: fouttekst in een rode
      // balk, en bij lege naam de uri-staart in plaats van "Niet gekozen".
      final service =
          File('lib/services/backup_map_service.dart').readAsStringSync();
      expect(service.contains('fout: e.toString()'), isTrue,
          reason: 'fouttekst gaat mee terug naar de UI');
      final scherm =
          File('lib/screens/settings_screen.dart').readAsStringSync();
      expect(scherm.contains('uitslag.fout'), isTrue,
          reason: 'rode balk bij falen');
      expect(scherm.contains('mapWeergave'), isTrue,
          reason: 'uri-staart bij lege naam');
    });
  });
}
