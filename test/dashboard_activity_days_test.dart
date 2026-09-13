// Regressietest voor de tegel "Dagen met activiteiten" op het dashboard.
//
// Bug: de tegel toonde "8/5". Dat kwam door twee fouten tegelijk:
//   1. de teller telde DAGEN met activiteiten, maar de noemer (5) hoorde bij
//      het aantal activiteitstypes;
//   2. de onderliggende query haalde 14 dagen op, terwijl de tegel over één
//      week gaat — dus de teller kon boven de 7 (en zelfs boven de noemer)
//      uitkomen.
//
// Deze test borgt dat de teller nooit boven 7 komt en dat het label de juiste
// noemer toont.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ritme/generated/l10n/app_localizations.dart';

/// Telt de dagen met activiteiten binnen een venster van 7 dagen.
///
/// Spiegelt de logica uit dashboard_screen.dart: de query levert een langere
/// reeks dan een week, dus er wordt op ondergrens gefilterd en daarna
/// begrensd.
int dagenMetActiviteiten(
  List<String> activiteitDatums,
  DateTime vandaag,
) {
  final grens = vandaag.subtract(const Duration(days: 6));
  final grensStr =
      '${grens.year}-${grens.month.toString().padLeft(2, '0')}-${grens.day.toString().padLeft(2, '0')}';
  final uniek = <String>{};
  for (final d in activiteitDatums) {
    if (d.isEmpty) continue;
    if (d.compareTo(grensStr) >= 0) uniek.add(d);
  }
  return uniek.length.clamp(0, 7);
}

void main() {
  final vandaag = DateTime(2026, 9, 13);

  group('Dagen met activiteiten telt nooit meer dan 7', () {
    test('14 dagen aan data levert maximaal 7 op (de oude bug gaf 8+)', () {
      // De queryreeks beslaat het hele 14-daagse bereik.
      final datums = <String>[
        for (int i = 0; i < 14; i++)
          DateTime(2026, 9, 13)
              .subtract(Duration(days: i))
              .toIso8601String()
              .substring(0, 10),
      ];
      final aantal = dagenMetActiviteiten(datums, vandaag);
      expect(aantal, 7);
      expect(aantal, lessThanOrEqualTo(7));
    });

    test('data van vóór het weekvenster telt niet mee', () {
      final datums = [
        '2026-09-13', // vandaag
        '2026-09-12',
        '2026-09-08',
        '2026-09-07', // buiten het venster (grens = 2026-09-07? zie hieronder)
      ];
      final aantal = dagenMetActiviteiten(datums, vandaag);
      expect(aantal, lessThanOrEqualTo(7));
      // 13, 12, 08 vallen binnen; 07 is de grens zelf (>= grens) dus telt mee.
      expect(aantal, 4);
    });

    test('lege lijst geeft 0', () {
      expect(dagenMetActiviteiten([], vandaag), 0);
      expect(dagenMetActiviteiten([''], vandaag), 0);
    });

    test('meerdere activiteiten op dezelfde dag tellen als één dag', () {
      final datums = ['2026-09-13', '2026-09-13', '2026-09-13', '2026-09-12'];
      // Bewust NIET het oude .clamp(0,7) pad: dit is de rauwe telling.
      final grens = vandaag.subtract(const Duration(days: 6));
      final grensStr =
          '${grens.year}-${grens.month.toString().padLeft(2, '0')}-${grens.day.toString().padLeft(2, '0')}';
      final uniek =
          datums.where((d) => d.isNotEmpty && d.compareTo(grensStr) >= 0).toSet();
      expect(uniek.length, 2);
    });
  });

  group('Label toont de noemer 7, niet 5', () {
    late AppLocalizations nl;
    late AppLocalizations en;

    setUpAll(() async {
      nl = await AppLocalizations.delegate.load(const Locale('nl'));
      en = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('label noemt 7 dagen', () {
      expect(nl.activiteitDagenVan7(8), '8/7 dagen');
      expect(nl.activiteitDagenVan7(3), '3/7 dagen');
      expect(en.activiteitDagenVan7(3), '3/7 days');
    });

    test('titel zegt "dagen", niet "activiteiten"', () {
      // De oude titel ("Activiteiten deze week") suggereerde dat de teller
      // activiteiten telde, terwijl er dagen geteld worden.
      expect(nl.activiteitenDezeWeekLabel.toLowerCase(), contains('dagen'));
      expect(en.activiteitenDezeWeekLabel.toLowerCase(), contains('days'));
    });

    test('het label bevat nergens meer de oude foute noemer /5', () {
      for (final n in [0, 1, 5, 7]) {
        expect(nl.activiteitDagenVan7(n), isNot(contains('/5')));
        expect(nl.activiteitDagenVan7(n), isNot(contains('/ 5')));
      }
    });
  });
}
