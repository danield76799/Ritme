// Regressietests voor de notificatie-planning.
//
// Aanleiding: de check-in herinneringen verdwenen meteen weer, omdat ze gepland
// werden VÓÓR rescheduleAllMedicationReminders() — en die roept intern
// _notifications.cancelAll() aan. Alles wat daarvóór gepland is, wordt gewist.
//
// Deze tests leggen de volgorde en de bijbehorende afspraken vast, zodat de
// meldingen niet opnieuw stil kunnen verdwijnen.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Leest een bestand uit de project-root.
String _bron(String pad) => File(pad).readAsStringSync();

/// Geeft de body van rescheduleAllMedicationReminders() terug.
///
/// Het einde wordt bepaald door de eerstvolgende regel die op twee spaties
/// inspringt en op 'Future<' begint — dus de volgende methode. Ankeren op een
/// specifieke methodenaam is fragiel gebleken: die naam stond niet naast de
/// functie waar ik hem zocht.
String _body(String helper) {
  final start = helper.indexOf('Future<int> rescheduleAllMedicationReminders()');
  if (start < 0) return '';
  final rest = helper.substring(start + 1);
  final match = RegExp(r'\n  Future<').firstMatch(rest);
  final eind = match == null ? helper.length : start + 1 + match.start;
  return helper.substring(start, eind);
}

void main() {
  group('Check-in herinneringen worden NA de cancelAll gepland', () {
    late String helper;

    setUpAll(() {
      helper = _bron('lib/services/notification_helper.dart');
    });

    test('rescheduleAllMedicationReminders plant de check-in herinneringen zelf', () {
      // De methode moet de aanroep bevatten, zodat een aanroeper de volgorde
      // niet kan verprutsen.
      final body = _body(helper);
      expect(body, contains('rescheduleCheckinReminders()'),
          reason: 'de check-in planning hoort IN deze methode te zitten');
    });

    test('de cancelAll-aanroep staat vóór de check-in planning', () {
      final body = _body(helper);

      final cancelPos = body.indexOf('cancelAllReminders()');
      final checkinPos = body.indexOf('rescheduleCheckinReminders()');

      expect(cancelPos, greaterThan(-1), reason: 'cancelAll hoort hier te staan');
      expect(checkinPos, greaterThan(-1));
      expect(checkinPos, greaterThan(cancelPos),
          reason: 'check-in planning moet NA het wissen gebeuren, anders verdwijnt de melding meteen');
    });

    test('een fout in de check-in planning blokkeert de medicatie-herinneringen niet', () {
      final body = _body(helper);
      // De aanroep moet in een eigen try/catch zitten; zou hij in de buitenste
      // try vallen, dan meldt de functie "mislukt" terwijl de medicatie al goed
      // gepland is — en gaat de teller naar 0.
      expect(body, contains('Check-in herinneringen plannen mislukt'),
          reason: 'de check-in planning hoort zijn eigen foutafhandeling te hebben');
    });

    test('de aanroepers plannen de check-in herinneringen niet nog een keer zelf', () {
      // Dubbel plannen is niet fataal, maar het betekent wel dat iemand de
      // volgorde weer zelf gaat bepalen — en dat ging mis.
      for (final pad in [
        'lib/services/boot_service.dart',
        'lib/services/work_manager_service.dart',
        'lib/main.dart',
      ]) {
        final inhoud = _bron(pad);
        expect(inhoud.contains('rescheduleCheckinReminders'), isFalse,
            reason: '$pad hoort de check-in planning NIET zelf te doen; '
                'dat zit in rescheduleAllMedicationReminders()');
      }
    });
  });

  group('Notificatie-ID\'s botsen niet met medicatie of afspraken', () {
    test('medicatie blijft onder 100000, afspraken onder 10000', () {
      final helper = _bron('lib/services/notification_helper.dart');
      // Medicatie: (id % 90000) + 10000 -> max 99999.
      expect(helper, contains('(id % 90000) + 10000'));
      // Afspraken: eigen range 1000-9999 (de oude (id*100)%100000 kon met
      // medicatie botsen en herinneringen overschrijven).
      expect(helper, contains('(appointmentId % 9000) + 1000'));
      expect(helper.contains('(appointmentId * 100) % 100000'), isFalse);
    });

    test('de check-in ID\'s liggen boven beide bereiken', () {
      final helper = _bron('lib/services/notification_helper.dart');
      expect(helper, contains('_ochtendNotifId = 900001'));
      expect(helper, contains('_avondNotifId = 900002'));
    });
  });

  group('De notificatie-tik leidt naar een bestaande route', () {
    test('de payload mapt op /morning-checkin en /evening-checkin', () {
      final helper = _bron('lib/services/notification_helper.dart');
      expect(helper, contains("'ochtend': '/morning-checkin'"));
      expect(helper, contains("'avond': '/evening-checkin'"));
    });

    test('die routes bestaan ook echt in de app', () {
      final main = _bron('lib/main.dart');
      expect(main, contains("'/morning-checkin'"));
      expect(main, contains("'/evening-checkin'"));
    });

    test('een koude start leest de launch-details van de plugin', () {
      // Zonder getNotificationAppLaunchDetails komt de payload bij een
      // afgesloten app nooit aan: de app opent wel, maar navigeert niet door.
      final helper = _bron('lib/services/notification_helper.dart');
      expect(helper, contains('getNotificationAppLaunchDetails'));
    });
  });
}
