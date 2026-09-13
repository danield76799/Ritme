// Regressietests voor het plannen van herinneringen op het juiste MOMENT.
//
// Twee bugs die hier worden geborgd:
//
// 1. TIJDZONE. tz.initializeTimeZones() zet de lokale zone op UTC. Zonder een
//    volgende setLocalLocation rekent alles in UTC — in Nederland scheelt dat
//    in de zomer 2 uur, dus een melding van 19:30 komt om 21:30. De fallback in
//    de oude code deed alleen een debugPrint en zette dus niets, en de
//    WorkManager-isolate initialiseerde de tijdzone nooit.
//
// 2. TIJD AL VOORBIJ. Een tijd instellen die vandaag al voorbij is gaat naar
//    morgen. Dat is correct, maar zonder terugkoppeling lijkt het op een
//    storing: de gebruiker kiest 19:30 om 19:34 en er gebeurt "niets".

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/services/notification_helper.dart';

String _bron(String pad) => File(pad).readAsStringSync();

void main() {
  group('volgendeMoment kiest vandaag of morgen', () {
    test('een tijd later vandaag blijft vandaag', () {
      final nu = DateTime.now();
      // Een uur vooruit, met de klok mee binnen dezelfde dag.
      final doel = nu.add(const Duration(hours: 1));
      if (doel.day != nu.day) return; // rond middernacht: niet te testen
      final tijd =
          '${doel.hour.toString().padLeft(2, '0')}:${doel.minute.toString().padLeft(2, '0')}';

      final r = NotificationHelper.volgendeMoment(tijd);
      expect(r.morgen, isFalse, reason: 'een uur vooruit is nog vandaag');
      expect(r.moment.day, nu.day);
    });

    test('een tijd die al voorbij is gaat naar morgen', () {
      final nu = DateTime.now();
      final doel = nu.subtract(const Duration(hours: 2));
      if (doel.day != nu.day) return; // rond middernacht: niet te testen
      final tijd =
          '${doel.hour.toString().padLeft(2, '0')}:${doel.minute.toString().padLeft(2, '0')}';

      final r = NotificationHelper.volgendeMoment(tijd);
      expect(r.morgen, isTrue,
          reason: 'dit is precies het geval dat op een storing lijkt');
    });

    test('precies nu telt als voorbij (geen melding in het verleden)', () {
      final nu = DateTime.now();
      final tijd = '${nu.hour.toString().padLeft(2, '0')}:'
          '${nu.minute.toString().padLeft(2, '0')}';
      final r = NotificationHelper.volgendeMoment(tijd);
      expect(r.moment.isAfter(DateTime.now()), isTrue,
          reason: 'een melding in het verleden vuurt nooit; hij moet vooruit wijzen');
    });

    test('het moment ligt altijd in de toekomst', () {
      for (final tijd in ['00:00', '08:00', '12:30', '21:00', '23:59']) {
        final r = NotificationHelper.volgendeMoment(tijd);
        expect(r.moment.isAfter(DateTime.now().subtract(const Duration(seconds: 1))),
            isTrue,
            reason: '$tijd mag nooit in het verleden liggen');
      }
    });

    test('ongeldige invoer valt terug op de standaardtijd, niet op een crash', () {
      final r = NotificationHelper.volgendeMoment('');
      expect(r.moment, isNotNull);
      expect(r.moment.isAfter(DateTime.now().subtract(const Duration(seconds: 1))), isTrue);
    });
  });

  group('De tijdzone wordt op ELK planningspad gezet', () {
    test('initializeTimeZones wordt niet meer kaal aangeroepen', () {
      final helper = _bron('lib/services/notification_helper.dart');
      // initializeTimeZones() zet de lokale zone op UTC. Hij mag alleen binnen
      // _ensureTimeZoneInitialized staan, direct gevolgd door setLocalLocation.
      final aantal = 'tz.initializeTimeZones()'.allMatches(helper).length;
      expect(aantal, 1,
          reason: 'meer dan één aanroep betekent: ergens blijft de zone op UTC');
    });

    test('de fallback zet echt een locatie in plaats van alleen te loggen', () {
      final helper = _bron('lib/services/notification_helper.dart');
      final start = helper.indexOf('Future<void> _ensureTimeZoneInitialized()');
      expect(start, greaterThan(-1), reason: 'de guard-methode hoort te bestaan');
      final rest = helper.substring(start + 1);
      final match = RegExp(r'\n  (?:Future|void|String|bool|int|static)').firstMatch(rest);
      final eind = match == null ? helper.length : start + 1 + match.start;
      final body = helper.substring(start, eind);

      // BELANGRIJK: alleen kijken of 'setLocalLocation' ergens voorkomt is te
      // zwak — het plugin-pad (de try hierboven) bevat hem ook, waardoor de
      // test ook op de kapotte versie groen bleef. Daarom specifiek de
      // FALLBACK-tak controleren: alles ná het woord 'Fallback'.
      final fb = body.indexOf('Fallback');
      expect(fb, greaterThan(-1), reason: 'er hoort een fallback te zijn');
      final fallbackTak = body.substring(fb);

      expect(fallbackTak.contains('setLocalLocation'), isTrue,
          reason: 'de fallback moet ECHT een locatie zetten; alleen loggen '
              'laat de zone op UTC staan en verschuift alle meldingen');
      expect(fallbackTak.contains('timeZoneName'), isFalse,
          reason: 'de oude bug logde alleen de naam zonder iets te zetten');
    });

    test('de WorkManager-taak komt langs de tijdzone-guard', () {
      // De taak draait in een eigen isolate en riep initialize() nooit aan,
      // waardoor tz.local daar een LateInitializationError gaf en de
      // herplanning stil mislukte.
      final helper = _bron('lib/services/notification_helper.dart');
      final start = helper.indexOf('Future<int> rescheduleAllMedicationReminders()');
      final rest = helper.substring(start + 1);
      final match = RegExp(r'\n  Future<').firstMatch(rest);
      final eind = match == null ? helper.length : start + 1 + match.start;
      final body = helper.substring(start, eind);

      expect(body.contains('_ensureTimeZoneInitialized'), isTrue,
          reason: 'de WorkManager-isolate moet de tijdzone ook zetten');
    });

    test('het plannen van check-in herinneringen komt langs de guard', () {
      final helper = _bron('lib/services/notification_helper.dart');
      final start = helper.indexOf('Future<void> rescheduleCheckinReminders()');
      final rest = helper.substring(start + 1);
      final match = RegExp(r'\n  Future<').firstMatch(rest);
      final eind = match == null ? helper.length : start + 1 + match.start;
      final body = helper.substring(start, eind);

      expect(body.contains('_ensureTimeZoneInitialized'), isTrue);
    });
  });

  group('De gebruiker ziet wanneer de melding komt', () {
    test('de UI toont de eerstvolgende vuurtijd', () {
      final settings = _bron('lib/screens/settings_screen.dart');
      expect(settings.contains('volgendeMoment'), isTrue,
          reason: 'zonder terugkoppeling lijkt een verstreken tijd op een storing');
    });

    test('het verschil vandaag/morgen is er in beide talen', () {
      final nl = _bron('lib/l10n/intl_nl.arb');
      final en = _bron('lib/l10n/intl_en.arb');
      for (final key in [
        'volgendeHerinneringVandaag',
        'volgendeHerinneringMorgen',
      ]) {
        expect(nl.contains(key), isTrue, reason: '$key mist in NL');
        expect(en.contains(key), isTrue, reason: '$key mist in EN');
      }
    });
  });
}
