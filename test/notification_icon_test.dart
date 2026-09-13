// Regressietest voor het notificatie-icoon en de stille foutafhandeling.
//
// Aanleiding: met shrinkResources = true (R8) verdween ic_launcher.png uit de
// release-bundle. R8 ziet alleen verwijzingen vanuit XML/Java, en het
// notificatie-icoon wordt enkel via een STRING aangeduid in Dart. Gevolg: alle
// notificaties mislukten STIL — geen foutmelding, alleen "verstuurd" in de UI.
//
// Deze test controleert de twee dingen die dat veroorzaakten, zodat het niet
// terugkomt: de keep-regel en het niet-inslikken van fouten.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _bron(String pad) => File(pad).readAsStringSync();

void main() {
  group('R8 mag het notificatie-icoon niet wegstrippen', () {
    test('de keep-regel voor het notificatie-icoon bestaat', () {
      final keep = File('android/app/src/main/res/raw/keep.xml');
      expect(keep.existsSync(), isTrue,
          reason: 'zonder keep.xml gooit shrinkResources ic_launcher.png weg, '
              'en mislukken alle notificaties zonder foutmelding');
      final inhoud = keep.readAsStringSync();
      expect(inhoud, contains('@mipmap/ic_launcher'),
          reason: 'precies dit icoon wordt door de plugin gebruikt');
    });

    test('de keep-regel gebruikt geen strict shrinkMode', () {
      final inhoud = _bron('android/app/src/main/res/raw/keep.xml');
      // strict gooit alles weg wat niet expliciet in een keep-regel staat —
      // precies het risico dat dit bestand moet wegnemen.
      //
      // Alleen de tools:keep-regel zelf bekijken, niet de toelichting
      // erboven: die noemt shrinkMode juist om uit te leggen waarom hij
      // NIET gebruikt wordt. Op de hele file matchen gaf een valse faler.
      final attr = RegExp(r'tools:shrinkMode\s*=\s*"([^"]*)"')
          .firstMatch(inhoud.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ''));
      expect(attr, isNull,
          reason: 'strict is te agressief; de plugin zelf gebruikt het ook niet');
    });

    test('de plugin-initialisatie vraagt om datzelfde icoon', () {
      final helper = _bron('lib/services/notification_helper.dart');
      expect(helper, contains("@mipmap/ic_launcher"),
          reason: 'keep.xml en de initialisatie moeten hetzelfde icoon noemen');
    });

    test('shrinkResources staat aan — dus de keep-regel is echt nodig', () {
      final gradle = _bron('android/app/build.gradle.kts');
      if (gradle.contains('isShrinkResources = true')) {
        expect(File('android/app/src/main/res/raw/keep.xml').existsSync(), isTrue,
            reason: 'shrinkResources zonder keep.xml = stille notificatiefalers');
      }
    });
  });

  group('Notificatiefouten worden niet stil ingeslikt', () {
    test('showImmediateNotification gooit door naar de aanroeper', () {
      final helper = _bron('lib/services/notification_helper.dart');
      final start = helper.indexOf('Future<void> showImmediateNotification(');
      expect(start, greaterThan(-1));
      final rest = helper.substring(start + 1);
      final match = RegExp(r'\n  (?:Future|void|String|bool|int)').firstMatch(rest);
      final eind = match == null ? helper.length : start + 1 + match.start;
      final body = helper.substring(start, eind);

      expect(body.contains('rethrow'), isTrue,
          reason: 'een fout moet doorlopen, anders meldt de UI "verstuurd" '
              'terwijl er niets verschijnt');
      // Alleen debugPrint was precies het probleem.
      expect(body.contains('debugPrint(\'Immediate notification error'),
          isFalse,
          reason: 'een debugPrint alleen maakt de fout onzichtbaar voor de UI');
    });

    test('de functie controleert of meldingen überhaupt aan staan', () {
      final helper = _bron('lib/services/notification_helper.dart');
      expect(helper, contains('areNotificationsEnabled'),
          reason: 'nodig om "verstuurd" te onderscheiden van "zichtbaar"');
    });
  });
}
