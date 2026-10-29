// Regressietest voor de slaapwaarschuwing: de waarschuwing moet over de
// LAATSTE nacht gaan, niet over de één-na-laatste.
//
// Het probleem: de daglogs staan oplopend gesorteerd (oudste eerst) en de
// code nam de EERSTE log met `daysAgo <= 1`. Daarmee won de log van
// gisteren — de nacht waarvan je die ochtend net hebt ingevuld werd
// genegeerd. Op de ochtend na een korte nacht kreeg je dus de waarschuwing
// over de nacht van twee nachten geleden, of helemaal geen waarschuwing.

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/service_locator.dart';
import 'package:ritme/services/bipolar_alert_service.dart';

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Database met een reeks dagenlogs. [slaapVandaag] is de slaap van de
/// nacht die vanmorgen eindigde (dus onder de datum van vandaag).
class _SlaapDb implements DatabaseRepository {
  _SlaapDb(this.logs);

  final List<Map<String, dynamic>> logs;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  @override
  Future<List<Map<String, dynamic>>> getDailyLogs() async => logs;
}

/// Bouwt [aantal] dagenlogs met [slaap] uur (van 2 dagen geleden tot
/// [aantal]+1 dagen geleden), plus de laatste dagen.
List<Map<String, dynamic>> _logs({
  required int aantal,
  required double slaap,
  double? gisteren,
  double? vandaag,
}) {
  final now = DateTime.now();
  final vandaagDatum = DateTime(now.year, now.month, now.day);
  final rows = <Map<String, dynamic>>[];
  // Oplopend gesorteerd, zoals de database ze teruggeeft.
  for (int i = aantal + 1; i >= 2; i--) {
    final d =
        DateTime(vandaagDatum.year, vandaagDatum.month, vandaagDatum.day - i);
    rows.add({
      'date': _dateStr(d),
      'sleep_hours': slaap,
    });
  }
  if (gisteren != null) {
    rows.add({
      'date': _dateStr(
          DateTime(vandaagDatum.year, vandaagDatum.month, vandaagDatum.day - 1)),
      'sleep_hours': gisteren,
    });
  }
  if (vandaag != null) {
    rows.add({'date': _dateStr(vandaagDatum), 'sleep_hours': vandaag});
  }
  rows.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  return rows;
}

void main() {
  group('slaapwaarschuwing gebruikt de laatste nacht', () {
    test('de nacht van vandaag wint van die van gisteren', () async {
      // 13 nachten van 8.8u, gisteren 8.0u, vandaag 5.3u.
      setDbForTesting(_SlaapDb(_logs(
        aantal: 13,
        slaap: 8.8,
        gisteren: 8.0,
        vandaag: 5.3,
      )));

      final alert = await BipolarAlertService.instance.checkSleepBaseline();
      expect(alert, isNotNull, reason: '5.3u is meer dan 30% onder de '
          'baseline en onder de 6 uur: dus een waarschuwing');
      // De melding is taalafhankelijk (u/h), dus alleen de waarde checken.
      expect(alert!.message, contains('5.3'));
      expect(alert.message, isNot(contains('8.0')),
          reason: 'de één-na-laatste nacht mag niet gebruikt worden');
      expect(alert.type, 'slaap_afname');
    });

    test('de afwijkende nacht telt niet mee in het gemiddelde', () async {
      // 13 nachten van 8.8u, vandaag 5.3u. Het gemiddelde in de melding
      // moet 8.8 zijn — de korte nacht zelf hoort niet in de referentie.
      setDbForTesting(_SlaapDb(_logs(
        aantal: 13,
        slaap: 8.8,
        vandaag: 5.3,
      )));

      final alert = await BipolarAlertService.instance.checkSleepBaseline();
      expect(alert, isNotNull);
      expect(alert!.message, contains('8.8'),
          reason: 'de baseline is het gemiddelde van de nachten vóór de '
              'afwijkende nacht');
      expect(alert.message, isNot(contains('8.5')),
          reason: 'met de afwijkende nacht erin zou het gemiddelde 8.5 zijn');
    });

    test('zonder slaap van vandaag valt de nacht van gisteren terug', () async {
      setDbForTesting(_SlaapDb(_logs(
        aantal: 13,
        slaap: 8.8,
        gisteren: 5.3,
      )));

      final alert = await BipolarAlertService.instance.checkSleepBaseline();
      expect(alert, isNotNull);
      expect(alert!.message, contains('5.3'));
    });

    test('een normale nacht geeft geen waarschuwing', () async {
      setDbForTesting(_SlaapDb(_logs(
        aantal: 13,
        slaap: 8.8,
        gisteren: 8.4,
        vandaag: 8.2,
      )));

      final alert = await BipolarAlertService.instance.checkSleepBaseline();
      expect(alert, isNull);
    });
  });
}
