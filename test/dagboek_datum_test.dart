// Het dagboek moet op de bekeken dag bewaard worden.
//
// HET PROBLEEM (gebruikersmelding 01-11-2026):
//   "Het dagboek wordt niet bewaard op de juiste dag als ik terugga in tijd."
//
// Oorzaak: het dashboard opende het dagboek ZONDER de geselecteerde dag.
// De ochtend- en avondcheck-in kregen `initialDate: _initialDateArg` wel,
// het dagboek niet — dus bladerde je in het dashboard terug en tikte je op
// Dagboek, dan opende het scherm op vandaag en werd je notitie onder vandaag
// bewaard.
//
// Daarnaast leidde `_initialDateArg` "is het vandaag?" af uit een Duration:
// `gisteren 23:00`.difference(`vandaag 01:00`) is -2 uur en `.inDays`
// truncateert dat naar 0 dagen, waarna een dag uit het verleden als vandaag
// gold. De regel vergelijkt nu de dag zelf.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ritme/utils/datum_sleutel.dart';

void main() {
  group('dagboekDatumArgument', () {
    final vandaag = DateTime(2026, 11, 1, 20, 31);

    test('vandaag geeft null (het scherm start dan op vandaag)', () {
      expect(dagboekDatumArgument(DateTime(2026, 11, 1), nu: vandaag), isNull);
    });

    test('vandaag met een tijdstip geeft nog steeds null', () {
      expect(
        dagboekDatumArgument(DateTime(2026, 11, 1, 23, 59), nu: vandaag),
        isNull,
      );
    });

    test('een dag terug geeft die dag', () {
      expect(
        dagboekDatumArgument(DateTime(2026, 10, 31), nu: vandaag),
        '2026-10-31',
      );
    });

    test('twee dagen terug geeft die dag', () {
      expect(
        dagboekDatumArgument(DateTime(2026, 10, 30), nu: vandaag),
        '2026-10-30',
      );
    });

    test('het uur van de dag maakt niet uit (de oude Duration-bug)', () {
      // Gisteren 23:00 tegenover vandaag 01:00 is -2 uur; `.inDays` geeft 0
      // en zou de dag als vandaag hebben behandeld.
      final kortNaMiddernacht = DateTime(2026, 11, 1, 1, 0);
      expect(
        dagboekDatumArgument(
          DateTime(2026, 10, 31, 23, 0),
          nu: kortNaMiddernacht,
        ),
        '2026-10-31',
      );
    });

    test('de sleutel is maand en dag met twee cijfers', () {
      expect(
        dagboekDatumArgument(DateTime(2026, 3, 5), nu: vandaag),
        '2026-03-05',
      );
    });

    test('DST-herfst: 25 oktober 2026 blijft één dag', () {
      // In de nacht van 24 op 25 oktober 2026 gaat de klok terug. Een
      // Duration-berekening zou hier 25 uur geven en naar een verkeerde dag
      // springen; de datumvergelijking niet.
      expect(
        dagboekDatumArgument(DateTime(2026, 10, 25), nu: vandaag),
        '2026-10-25',
      );
      expect(datumSleutel(DateTime(2026, 10, 25)), '2026-10-25');
    });

    test('een dag in de toekomst wordt niet verzonnen', () {
      // Het scherm zelf knijpt dit naar vandaag; de regel geeft de dag
      // gewoon door zodat het scherm die kan afkappen.
      expect(
        dagboekDatumArgument(DateTime(2026, 11, 2), nu: vandaag),
        '2026-11-02',
      );
    });
  });

  group('dagenVerschil', () {
    test('vandaag is 0', () {
      expect(
        dagenVerschil(DateTime(2026, 11, 1), nu: DateTime(2026, 11, 1, 20, 31)),
        0,
      );
    });

    test('gisteren is -1, ook vlak na middernacht', () {
      // Dit is de precieze casus die misging: -2 uur gaf `.inDays` == 0.
      expect(
        dagenVerschil(
          DateTime(2026, 10, 31, 23, 0),
          nu: DateTime(2026, 11, 1, 1, 0),
        ),
        -1,
      );
    });

    test('twee dagen terug is -2', () {
      expect(
        dagenVerschil(DateTime(2026, 10, 30), nu: DateTime(2026, 11, 1)),
        -2,
      );
    });

    test('morgen is +1', () {
      expect(
        dagenVerschil(DateTime(2026, 11, 2), nu: DateTime(2026, 11, 1)),
        1,
      );
    });

    test('de DST-nacht telt als één dag', () {
      // 25 oktober 2026 is 25 uur na 24 oktober. Gerekend in de lokale
      // tijdzone zou dat naar 1.04 dagen afronden; op UTC-middernacht is het
      // exact 1.
      expect(
        dagenVerschil(DateTime(2026, 10, 24), nu: DateTime(2026, 10, 25)),
        -1,
      );
      expect(
        dagenVerschil(DateTime(2026, 10, 26), nu: DateTime(2026, 10, 25)),
        1,
      );
    });
  });

  group('broncode', () {
    test('het dashboard geeft de geselecteerde dag aan het dagboek mee', () {
      final inhoud = File(
        'lib/screens/dashboard_screen.dart',
      ).readAsStringSync();
      expect(
        inhoud.contains(
          "case '/dagboek': return DagboekScreen(initialDate: _initialDateArg,",
        ),
        isTrue,
        reason:
            'zonder initialDate opent het dagboek op vandaag en wordt een '
            'notitie op de verkeerde dag bewaard',
      );
    });

    test('de dag wordt niet meer uit een Duration afgeleid', () {
      final inhoud = File(
        'lib/screens/dashboard_screen.dart',
      ).readAsStringSync();
      expect(
        inhoud.contains('_selectedDate.difference('),
        isFalse,
        reason:
            '.inDays truncateert naar 0 en behandelt een verleden dag als '
            'vandaag',
      );
    });

    test('de datumkop gebruikt dezelfde dagtelling', () {
      final inhoud = File(
        'lib/screens/dashboard_screen.dart',
      ).readAsStringSync();
      expect(
        inhoud.contains('final diff = dagenVerschil(_selectedDate);'),
        isTrue,
        reason: 'de kop "Vandaag" mag niet op een verleden dag verschijnen',
      );
    });

    test('de check-ins krijgen dezelfde dag mee als het dagboek', () {
      final inhoud = File(
        'lib/screens/dashboard_screen.dart',
      ).readAsStringSync();
      for (final scherm in [
        'DagboekScreen(initialDate: _initialDateArg',
        'MorningCheckInScreen(initialDate: _initialDateArg',
        'EveningCheckInScreen(initialDate: _initialDateArg',
      ]) {
        expect(inhoud.contains(scherm), isTrue, reason: 'mist: $scherm');
      }
    });
  });
}
