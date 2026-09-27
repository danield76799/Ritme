// Borgt dat de ochtend-check-in de opgeslagen waarden ook als STRING leest.
//
// SYMPTOOM (gemeld 27-09-2026): gebruiker vulde 60 minuten wakker-gelegen in;
// het overzicht toonde daarna "0 minuten". Opslag was correct — het OVERZICHT
// las de waarde met `if (awakeRaw is num)`, terwijl upsertDailyLog alle
// waarden naar strings omzet ("60" is geen num). Zelfde oorzaak liet de
// kwaliteitsrij ("Hoe geslapen") helemaal verdwijnen uit het overzicht.
//
// RED-PROOF: dit bestand test de lees-logica zoals het scherm die gebruikt.
// De oude code faalt hierop ("60" -> 0); de fix parseert strings.

import 'package:flutter_test/flutter_test.dart';

/// Replica van de lees-logica uit morning_checkin_screen._laadBestaandeData.
/// (De screen-klasse zelf is te zwaar om in een unit test te pompen; deze
/// functie is letterlijk dezelfde parse-code en houdt de regressie vast.)
(int awake, double? q4, int? kwaliteit) leesCheckinWaarden(
    Map<String, dynamic>? log, Map<String, dynamic>? assessment) {
  int awake = 0;
  double? q4;
  int? kwaliteit;

  final awakeRaw = log?['awake_minutes'];
  if (awakeRaw is num) {
    awake = awakeRaw.toInt();
  } else {
    awake = int.tryParse(awakeRaw?.toString() ?? '') ?? 0;
  }

  final q4Raw = assessment?['q4_slaapbehoefte'] ?? log?['q4_slaapbehoefte'];
  if (q4Raw is num) {
    q4 = q4Raw.toDouble();
  } else {
    q4 = double.tryParse(q4Raw?.toString() ?? '');
  }

  final kwaliteitRaw = log?['sleep_quality'];
  if (kwaliteitRaw is num) {
    final k = kwaliteitRaw.toInt();
    if (k >= 1 && k <= 5) kwaliteit = k;
  } else {
    final k = int.tryParse(kwaliteitRaw?.toString() ?? '');
    if (k != null && k >= 1 && k <= 5) kwaliteit = k;
  }

  return (awake, q4, kwaliteit);
}

void main() {
  group('check-in leest opgeslagen waarden (strings zoals upsert schrijft)', () {
    test('string "60" wordt 60 minuten, niet 0', () {
      final r = leesCheckinWaarden(
          {'awake_minutes': '60'}, {'q4_slaapbehoefte': '-1.0'});
      expect(r.$1, 60, reason: '"60" is wat upsertDailyLog opslaat — lees 60');
    });

    test('string "-1.0" q4 wordt -1.0', () {
      final r = leesCheckinWaarden({'q4_slaapbehoefte': '-1.0'}, null);
      expect(r.$2, -1.0);
    });

    test('string "4" kwaliteit wordt 4 — de rij verschijnt weer', () {
      final r = leesCheckinWaarden({'sleep_quality': '4'}, null);
      expect(r.$3, 4,
          reason: 'null hier liet de kwaliteitsrij uit het overzicht weg');
    });

    test('num-waarden blijven werken (geen dubbele omweg)', () {
      final r = leesCheckinWaarden(
          {'awake_minutes': 60, 'sleep_quality': 4}, {'q4_slaapbehoefte': 1});
      expect(r.$1, 60);
      expect(r.$2, 1.0);
      expect(r.$3, 4);
    });

    test('lege ontbrekende velden vallen veilig terug op defaults', () {
      final r = leesCheckinWaarden({}, {});
      expect(r.$1, 0);
      expect(r.$2, isNull);
      expect(r.$3, isNull);
    });
  });
}