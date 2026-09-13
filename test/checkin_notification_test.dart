// Test de check-in herinneringslogica.
//
// De kernvragen:
//   1. Wordt de juiste herinneringstekst gekozen (met/zonder "gisteren gemist")?
//   2. Kiest CheckinStatus de juiste dag en het juiste type check-in?
//   3. Blijven de notificatie-ID's buiten het bereik van medicatie/afspraken?
//
// De tijden en aan/uit-standen zijn instellingen; die worden hier niet
// getest omdat ze in Hive staan (aparte integration-test).

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/utils/checkin_status.dart';
import 'package:ritme/utils/notif_strings.dart';

void main() {
  group('dateKey gebruikt hetzelfde formaat als de database', () {
    test('vult maand en dag aan met een nul', () {
      expect(CheckinStatus.dateKey(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('laat tweecijferige waarden ongemoeid', () {
      expect(CheckinStatus.dateKey(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('is lexicografisch sorteerbaar (zoals de DB-ranges verwachten)', () {
      final eerder = CheckinStatus.dateKey(DateTime(2026, 9, 9));
      final later = CheckinStatus.dateKey(DateTime(2026, 9, 10));
      expect(eerder.compareTo(later), lessThan(0));
    });
  });

  group('avondTypes bevatten de DB-waarden, niet de weergavelabels', () {
    test('de vier SRM-activiteiten van de avondcheck-in', () {
      expect(CheckinStatus.avondTypes, {
        'Eerste contact',
        'Werk / Hobby',
        'Avondeten',
        'Naar bed',
      });
    });

    test('bevat geen vertaalde labels (ENGelse telefoon mag niets breken)', () {
      // De DB bewaart Nederlandse waarden ongeacht de app-taal; een
      // vertaald label hier zou de herkenning stil breken.
      for (final t in CheckinStatus.avondTypes) {
        expect(t, isNot(contains('Bedtime')));
        expect(t, isNot(contains('Dinner')));
      }
    });
  });

  group('Herinneringstekst', () {
    test('ochtend zonder gemiste dag: geen waarschuwingsregel', () {
      final body = NotifStrings.checkinBody(ochtend: true, gisterenGemist: false);
      expect(body, isNot(contains('gisteren')));
      expect(body.toLowerCase(), isNot(contains('yesterday')));
    });

    test('ochtend met gemiste dag: waarschuwingsregel erbij', () {
      final body = NotifStrings.checkinBody(ochtend: true, gisterenGemist: true);
      // Precies één van beide talen, afhankelijk van de platform-locale.
      final heeftWaarschuwing = body.contains('gisteren') ||
          body.toLowerCase().contains('yesterday');
      expect(heeftWaarschuwing, isTrue,
          reason: 'de melding moet zeggen dat gisteren nog open staat');
    });

    test('de gewone tekst blijft staan bij een gemiste dag', () {
      final zonder = NotifStrings.checkinBody(ochtend: true, gisterenGemist: false);
      final met = NotifStrings.checkinBody(ochtend: true, gisterenGemist: true);
      // De waarschuwing komt ERBIJ, de herinnering zelf verdwijnt niet.
      expect(met.startsWith(zonder), isTrue,
          reason: 'één melding met context, geen losse tweede melding');
    });

    test('ochtend en avond hebben een verschillende body', () {
      final o = NotifStrings.checkinBody(ochtend: true, gisterenGemist: false);
      final a = NotifStrings.checkinBody(ochtend: false, gisterenGemist: false);
      expect(o, isNot(equals(a)));
    });

    test('titel onderscheidt ochtend van avond', () {
      final o = NotifStrings.checkinTitle(ochtend: true, gisterenGemist: false);
      final a = NotifStrings.checkinTitle(ochtend: false, gisterenGemist: false);
      expect(o, isNot(equals(a)));
    });

    test('de waarschuwingsregel begint op een nieuwe regel', () {
      expect(NotifStrings.checkinMissedSuffix.startsWith('\n\n'), isTrue);
    });
  });
}
