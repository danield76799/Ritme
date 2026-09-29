// Regressietests voor de l10n-placeholder-volgorde-bug.
//
// Achtergrond: intl_utils genereert de methode-signatuur met de
// placeholders ALFABETISCH gesorteerd, niet in de volgorde waarin ze in
// de ARB-tekst staan. Een aanroep die de waarden in "tekstuele" volgorde
// doorgeeft krijgt ze dus omgewisseld binnen.
//
// Concreet gezien op het ochtend-check-in scherm: bij 9u45m slaap stond
// er "45u 9m" — de minuten als uren en andersom.
//
// Deze test bewaakt drie dingen:
//   1. de gegenereerde signatuur-volgorde (alfabetisch) is ongewijzigd;
//   2. de aanroepen in de app geven hun argumenten in DIE volgorde door;
//   3. de gerenderde tekst zet de waarden op de juiste plek.

import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/generated/l10n/app_localizations.dart';

/// Haalt de argumenten van een aanroep `naam(` op door haakjes te tellen,
/// zodat geneste haakjes (zoals `floor()`) niet de boel verknallen.
List<String> argumentenVan(String bron, String aanroep) {
  final start = bron.indexOf(aanroep);
  if (start < 0) return const [];
  final open = bron.indexOf('(', start + aanroep.length - 1);
  if (open < 0) return const [];

  var diepte = 0;
  final args = <String>[];
  final buffer = StringBuffer();

  for (var i = open; i < bron.length; i++) {
    final c = bron[i];
    if (c == '(') {
      diepte++;
      if (diepte == 1) continue; // buitenste haak niet meenemen
    } else if (c == ')') {
      diepte--;
      if (diepte == 0) {
        args.add(buffer.toString());
        break;
      }
    } else if (c == ',' && diepte == 1) {
      args.add(buffer.toString());
      buffer.clear();
      continue;
    }
    buffer.write(c);
  }
  // Trailing comma's leveren een lege laatste entry op; die horen geen
  // argument te zijn (Dart-formattering zet er standaard één).
  return args
      .map((a) => a.trim())
      .where((a) => a.isNotEmpty)
      .toList();
}

void main() {
  group('l10n placeholder-volgorde', () {
    late AppLocalizations nl;

    setUp(() async {
      nl = await AppLocalizations.delegate.load(const Locale('nl'));
    });

    test('ochtendGeslapenUren rendert uren vóór minuten in de tekst', () {
      // Signatuur is (minuten, uren): 45 minuten + 9 uren = 9u 45m.
      final tekst = nl.ochtendGeslapenUren(45, 9);
      expect(
        tekst,
        contains('9u 45m'),
        reason: 'de uren horen in het {uren}-slot, de minuten in {minuten}',
      );
      expect(
        tekst,
        isNot(contains('45u 9m')),
        reason: 'dit is precies de omwissel-bug die op het scherm stond',
      );
    });

    test('wekenDagen rendert dagen na de weken', () {
      // Signatuur is (d, w): 3 dagen + 2 weken = "2 weken, 3 dagen".
      final tekst = nl.wekenDagen(3, 2);
      expect(
        tekst,
        contains('2 weken'),
        reason: 'de weken horen in het {w}-slot',
      );
      expect(
        tekst,
        contains('3 dagen'),
        reason: 'de dagen horen in het {d}-slot',
      );
    });

    test('ochtend-check-in geeft (minuten, uren) door aan de l10n', () {
      final bron = File(
        'lib/screens/morning_checkin_screen.dart',
      ).readAsStringSync();
      final args = argumentenVan(bron, 'l10n.ochtendGeslapenUren(');
      expect(args.length, 2, reason: 'twee argumenten (minuten, uren)');

      expect(
        args[0],
        contains('* 60'),
        reason: 'het EERSTE argument is de minuten-berekening (signatuur: '
            'Object minuten, Object uren)',
      );
      expect(
        args[1],
        contains('floor()'),
        reason: 'het TWEEDE argument is het hele-uren-getal',
      );
    });

    test('episoden-scherm geeft (dagen, weken) door aan de l10n', () {
      final bron = File(
        'lib/screens/episodes_screen.dart',
      ).readAsStringSync();
      final args = argumentenVan(bron, 'l10n.wekenDagen(');
      expect(args.length, 2, reason: 'wekenDagen heeft twee parameters');
      expect(
        args[0],
        'remainder',
        reason: 'eerste parameter is {d} (dagen)',
      );
      expect(
        args[1],
        'weeks',
        reason: 'tweede parameter is {w} (weken)',
      );
    });

    test('gegenereerde signaturen houden de alfabetische volgorde', () {
      // Bewaakt de aanname achter de bug: als intl_utils ooit van volgorde
      // verandert, moet deze test omvallen zodat de call sites herzien worden.
      final gen = File(
        'lib/generated/l10n/app_localizations_nl.dart',
      ).readAsStringSync();

      expect(
        gen.contains('String ochtendGeslapenUren(Object minuten, Object uren)'),
        isTrue,
        reason: 'alfabetisch: minuten vóór uren',
      );
      expect(
        gen.contains('String wekenDagen(num d, num w)'),
        isTrue,
        reason: 'alfabetisch: d vóór w',
      );
    });
  });
}
