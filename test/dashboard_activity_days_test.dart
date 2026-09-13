// Regressietest: de dubbel getelde activiteitentegel blijft weg van het
// dashboard.
//
// Het dashboard had naast "SRT Score" een tweede tegel "Dagen met activiteiten"
// (voorheen "Activiteiten deze week", met de bug "8/5"). Die was een dubbeling:
// de SRT-score ís de activiteiten-op-tijd-score (gemiddelde P-score / 5 x 100),
// maar de tegel ernaast telde iets anders — dagen met activiteiten — en leidde
// naar een eigen detailscherm.
//
// Deze test borgt dat die tegel niet terugsluipt: hij zou opnieuw voor twee
// concurrerende cijfers over dezelfde data zorgen.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('De dubbele activiteitentegel is verwijderd', () {
    late String dashboard;

    setUpAll(() {
      dashboard = File('lib/screens/dashboard_screen.dart').readAsStringSync();
    });

    test('de kaartfunctie bestaat niet meer', () {
      expect(dashboard.contains('_buildActivityMetricCard'), isFalse,
          reason: 'de activiteitentegel-widget hoort verwijderd te zijn');
    });

    test('het veld _weeklyActivities bestaat niet meer', () {
      expect(dashboard.contains('_weeklyActivities'), isFalse,
          reason: 'de teller hoorde alleen bij de verwijderde tegel');
    });

    test('er wordt niet meer naar het activiteitenscherm gelinkt', () {
      expect(dashboard.contains('/activities-detail'), isFalse);
    });

    test('de verwijderde ARB-keys worden nergens meer gebruikt', () {
      for (final sleutel in [
        'activiteitenDezeWeekLabel',
        'activiteitDagenVan7',
        'nogGeenActiviteitenDezeWeek',
      ]) {
        expect(dashboard.contains(sleutel), isFalse,
            reason: '"$sleutel" hoorde bij de verwijderde tegel');
      }
    });

    test('SRT Score staat nog wel op het dashboard', () {
      expect(dashboard.contains('srtScore'), isTrue);
      expect(dashboard.contains('/rhythm-detail'), isTrue,
          reason: 'de SRT-tegel hoort nog naar Ritme Stabiliteit te linken');
    });

    test('de SRT-tegel staat niet meer in een Row naast een tweede kaart', () {
      // Op volle breedte heeft het percentage meer ruimte en is er geen
      // tweede, concurrerend cijfer meer.
      final srtIndex = dashboard.indexOf('srtScore');
      expect(srtIndex, greaterThan(0));
      // Zoek de eerstvolgende kaartaanroep vóór en na de SRT-titel.
      final voor = dashboard.substring(
        0,
        srtIndex,
      );
      expect(voor.endsWith('_buildMetricCard(\n                context,\n') ||
              voor.contains('_buildMetricCard(\n                context,'),
          isTrue,
          reason: 'SRT hoort direct als losse _buildMetricCard te worden aangeroepen');
    });
  });
}
