// Regressietests voor de Ritme-review (logica/duidelijkheid, 09-2026).
//
// 1. STILLE OPSLAGFOUT. De ochtend-check-in zette `_step = 3` (klaar + vinkje)
//    ook als het opslaan mislukte; de avond-check-in meldde via _sluiten
//    altijd "bewaard". Nu: alleen bij echt gelukte opslag naar klaar,
//    anders een foutmelding en eerlijke terugmelding.
//
// 2. TWEE DEFINITIES VAN "GEDAAN". De tegel van vandaag telde een avondrij
//    zonder tijd en een ochtend met alleen q4 wel mee, terwijl de streak
//    ze afkeurde (en omgekeerd bij q4). Nu: één definitie (ochtendGedaan,
//    avondGedaan) voor tegel, teller, streak en terugkijkweergave.
//
// 3. TERUGKIJK-RANGE. _loadDataForDate hing de start van het weekvenster aan
//    vandaag, waardoor een datum ouder dan 6 dagen buiten zijn eigen range
//    viel. Nu: weekVenster(datum) eindigt op de bekeken datum.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/screens/dashboard_screen.dart'
    show ochtendGedaan, avondGedaan, weekVenster;

/// Broncode zonder commentaar: de uitleg bij een fix citeert bewust de oude
/// code, en daar mag een structuurtest niet op stuklopen.
String _code(String pad) {
  final zonderBlok =
      File(pad).readAsStringSync().replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return zonderBlok
      .split('\n')
      .map((regel) => regel.replaceAll(RegExp(r'//.*$'), ''))
      .join('\n');
}

void main() {
  group('ochtendGedaan: één definitie', () {
    test('volledige ochtend telt mee', () {
      expect(
        ochtendGedaan({
          'date': '2026-09-10',
          'uren_slaap': 7.5,
          'awake_minutes': 10,
          'q4_slaapbehoefte': 1.0,
        }),
        isTrue,
      );
    });

    test('alleen q4 telt mee (slaapuren ontbreken zonder bedtijd gisteren)', () {
      expect(
        ochtendGedaan({
          'date': '2026-09-10',
          'awake_minutes': 0,
          'q4_slaapbehoefte': -2.0,
        }),
        isTrue,
      );
    });

    test('lege log telt niet mee', () {
      expect(ochtendGedaan({'date': '2026-09-10'}), isFalse);
      expect(
        ochtendGedaan({
          'date': '2026-09-10',
          'uren_slaap': 0,
          'awake_minutes': 0,
        }),
        isFalse,
      );
    });

    test('tekstwaarden worden begrepen', () {
      expect(
        ochtendGedaan({'date': '2026-09-10', 'uren_slaap': '7.5'}),
        isTrue,
      );
    });
  });

  group('avondGedaan: één definitie', () {
    test('rij met tijd telt mee', () {
      expect(
        avondGedaan([
          {
            'date': '2026-09-10',
            'activity_type': 'Avondeten',
            'actual_time': '18:30',
            'p_score': 4,
          },
        ], '2026-09-10'),
        isTrue,
      );
    });

    test('rij zonder tijd telt nergens mee (ook niet op de tegel)', () {
      expect(
        avondGedaan([
          {
            'date': '2026-09-10',
            'activity_type': 'Avondeten',
            'actual_time': '',
          },
        ], '2026-09-10'),
        isFalse,
      );
      expect(
        avondGedaan([
          {'date': '2026-09-10', 'activity_type': 'Avondeten'},
        ], '2026-09-10'),
        isFalse,
      );
    });

    test('andere datum en ander type tellen niet mee', () {
      expect(
        avondGedaan([
          {
            'date': '2026-09-09',
            'activity_type': 'Avondeten',
            'actual_time': '18:30',
          },
        ], '2026-09-10'),
        isFalse,
      );
      expect(
        avondGedaan([
          {
            'date': '2026-09-10',
            'activity_type': 'Opstaan',
            'actual_time': '07:30',
          },
        ], '2026-09-10'),
        isFalse,
      );
    });
  });

  group('weekVenster: venster hangt aan de bekeken datum', () {
    test('oude datum valt binnen zijn eigen venster', () {
      final venster = weekVenster(DateTime(2026, 8, 20));
      expect(venster[1], '2026-08-20');
      expect(venster[0], '2026-08-14');
      expect(
        venster[0].compareTo('2026-08-20') <= 0 &&
            '2026-08-20'.compareTo(venster[1]) <= 0,
        isTrue,
      );
    });

    test('venster is 7 dagen en start ligt voor end', () {
      final venster = weekVenster(DateTime(2026, 9, 14));
      expect(venster[1], '2026-09-14');
      expect(venster[0], '2026-09-08');
      expect(venster[0].compareTo(venster[1]) < 0, isTrue);
    });

    test('maandgrens wordt correct overbrugd', () {
      final venster = weekVenster(DateTime(2026, 9, 2));
      expect(venster, ['2026-08-27', '2026-09-02']);
    });
  });

  group('één definitie, overal gebruikt (structuur)', () {
    test('geen tweede inline-definitie in het dashboard', () {
      final code = _code('lib/screens/dashboard_screen.dart');
      // Definitie + aanroepen; zakt dit aantal, dan is een plek weer
      // zijn eigen logica gaan doen.
      expect(RegExp(r'avondGedaan\(').allMatches(code).length,
          greaterThanOrEqualTo(5));
      expect(RegExp(r'ochtendGedaan').allMatches(code).length,
          greaterThanOrEqualTo(5));
      // De vier avondtypen staan op precies één plek (de const).
      expect(
        RegExp(r"'Eerste contact'").allMatches(code).length,
        1,
        reason: 'tweede letterlijke set = tweede definitie',
      );
    });

    test('terugkijkweergave gebruikt het gedeelde weekvenster', () {
      final code = _code('lib/screens/dashboard_screen.dart');
      final laad = code.substring(code.indexOf('_loadDataForDate'));
      expect(laad.contains('weekVenster('), isTrue);
      expect(laad.contains('now.subtract'), isFalse,
          reason: 'venster mag niet meer aan vandaag hangen');
    });
  });

  group('opslagfout toont geen vals vinkje (structuur)', () {
    test('ochtend: klaar-stap alleen bij gelukte opslag', () {
      final code = _code('lib/screens/morning_checkin_screen.dart');
      expect(code.contains('opgeslagen = true'), isTrue);
      // _step = 3 mag alleen in de opgeslagen-tak staan.
      final finish = code.substring(code.indexOf('Future<void> _finish()'));
      final klaarToekenningen =
          RegExp(r'_step\s*=\s*3').allMatches(finish).length;
      expect(klaarToekenningen, 1,
          reason: 'precies één overgang naar klaar, bewaakt door opgeslagen');
      expect(finish.contains('if (opgeslagen)'), isTrue);
      expect(finish.contains('SnackBar'), isTrue,
          reason: 'bij een fout krijgt de gebruiker een melding');
    });

    test('avond: _opslaan meldt eerlijk terug en _sluiten geeft het door', () {
      final code = _code('lib/screens/evening_checkin_screen.dart');
      expect(code.contains('Future<bool> _opslaan'), isTrue);
      expect(code.contains('return false'), isTrue);
      expect(code.contains('widget.onClose!(_opslagGelukt)'), isTrue);
      expect(code.contains('pop(_opslagGelukt)'), isTrue);
      expect(
        code.contains('onClose!(true)') || code.contains('pop(true)'),
        isFalse,
        reason: 'geen onvoorwaardelijk "bewaard" meer',
      );
    });
  });
}
