// Regressietests voor de dagboek-bladerbalk + zichtbare tijdzone (09-2026).
//
// 1. DAGBOEK-BLADERBALK. De bekeken datum kwam alleen via het route-argument
//    binnen; in het scherm viel er niets te bladeren. Nu staat er een
//    bladerbalk (‹ datum › + kalender) boven de inhoud: terugbladeren mag,
//    de toekomst niet, en bij wisselen wordt het formulier geleegd en de
//    nieuwe dag geladen.
//
// 2. TIJDZONE ZICHTBAAR. UTC-terugval kan "nooit geen melding" niet
//    verklaren (hooguit uren te laat), maar zonder zichtbare tijdzone blijft
//    het gissen. Instellingen toont nu "Tijdzone: Europe/Amsterdam" (of UTC
//    als de init terugviel) onder de check-in herinneringen.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
  group('Dagboek-bladerbalk', () {
    test('bekeken datum leeft in state, niet alleen in het route-argument',
        () {
      final code = _code('lib/screens/dagboek_screen.dart');
      expect(code.contains('_bekekenDatum'), isTrue);
      expect(code.contains('_gaNaarDatum'), isTrue);
      expect(code.contains('_datumNavigator'), isTrue);
    });

    test('kalender staat geen toekomst toe', () {
      final code = _code('lib/screens/dagboek_screen.dart');
      expect(code.contains('showDatePicker'), isTrue);
      expect(code.contains('lastDate: _vandaag()'), isTrue,
          reason: 'geen dagboek voor morgen');
      expect(code.contains('isAfter(_vandaag())'), isTrue,
          reason: 'ook programmatisch nooit verder dan vandaag');
    });

    test('volgende-pijl is uit op vandaag', () {
      final code = _code('lib/screens/dagboek_screen.dart');
      expect(code.contains('_isVandaag'), isTrue);
      expect(code.contains('chevron_left'), isTrue);
      expect(code.contains('chevron_right'), isTrue);
    });

    test('bij wisselen wordt het formulier geleegd en opnieuw geladen', () {
      final code = _code('lib/screens/dagboek_screen.dart');
      final wissel = code.substring(code.indexOf('_gaNaarDatum('));
      expect(wissel.contains('_tekstController.clear()'), isTrue,
          reason: 'anders blijft de tekst van gisteren staan');
      expect(wissel.contains('_laadBestaandeData()'), isTrue);
      expect(wissel.contains('_bekijkModus = false'), isTrue);
    });

    test('bladerbalk staat boven de inhoud', () {
      final code = _code('lib/screens/dagboek_screen.dart');
      final build = code.substring(code.indexOf('_datumNavigator(context)'));
      expect(build.contains('Expanded('), isTrue);
    });
  });

  group('Tijdzone zichtbaar', () {
    test('helper geeft de resolved zonenaam', () {
      final code = _code('lib/services/notification_helper.dart');
      expect(code.contains('tijdzoneNaam'), isTrue);
      expect(code.contains('tz.local'), isTrue);
    });

    test('instellingen tonen de tijdzone onder de herinneringen', () {
      final code = _code('lib/screens/settings_screen.dart');
      expect(code.contains('tijdzoneNaam'), isTrue);
      expect(code.contains('checkinHerinneringenUitleg'), isTrue);
    });

    test('tijdzone-label bestaat in NL en EN', () {
      Map<String, dynamic> arb(String naam) => json.decode(
            File('lib/l10n/$naam').readAsStringSync(),
          ) as Map<String, dynamic>;
      expect((arb('intl_nl.arb')['tijdzone'] as String).isNotEmpty, isTrue);
      expect((arb('intl_en.arb')['tijdzone'] as String).isNotEmpty, isTrue);
    });
  });
}
