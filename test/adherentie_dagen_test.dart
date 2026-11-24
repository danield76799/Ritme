import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/utils/adherentie_dagen.dart';

Map<String, dynamic> _sched(int medId, {String dagen = '1,2,3,4,5,6,7'}) =>
    {'medication_id': medId, 'days_of_week': dagen, 'reminder_time': '08:00'};

Map<String, dynamic> _inname(int medId, String datum, {int aantal = 1}) =>
    {'medication_id': medId, 'date': datum, 'aantal_ingenomen': aantal};

void main() {
  group('berekenAdherentieDagen', () {
    test('markeert genomen, gemist en vandaag als open', () {
      final vandaag = DateTime(2026, 11, 24);
      final dagen = berekenAdherentieDagen(
        intakes: [
          _inname(1, '2026-11-22'),
          _inname(1, '2026-11-23'),
        ],
        medicatieId: 1,
        schedules: [_sched(1)],
        vandaag: vandaag,
        dagen: 4,
      );

      expect(dagen.length, 4);
      expect(dagen[0].status, DagStatus.gemist); // 21-11
      expect(dagen[1].status, DagStatus.genomen); // 22-11
      expect(dagen[2].status, DagStatus.genomen); // 23-11
      expect(dagen[3].status, DagStatus.open); // 24-11, dosis kan nog komen
    });

    test('niet-geplande weekdagen tellen niet als gemist', () {
      final vandaag = DateTime(2026, 11, 24); // dinsdag
      final dagen = berekenAdherentieDagen(
        intakes: const [],
        medicatieId: 1,
        schedules: [_sched(1, dagen: '1')], // alleen maandag
        vandaag: vandaag,
        dagen: 3,
      );

      // 22-11 zo, 23-11 ma, 24-11 di
      expect(dagen[0].status, DagStatus.nietGepland);
      expect(dagen[1].status, DagStatus.gemist);
      expect(dagen[2].status, DagStatus.nietGepland);
    });

    test('zonder schema (PRN) is er geen heatmap', () {
      final dagen = berekenAdherentieDagen(
        intakes: [_inname(1, '2026-11-24')],
        medicatieId: 1,
        schedules: const [],
        vandaag: DateTime(2026, 11, 24),
      );
      expect(dagen, isEmpty);
    });
  });

  group('prnPerWeek', () {
    test('telt innames per week, oud naar nieuw', () {
      final vandaag = DateTime(2026, 11, 24); // dinsdag
      final waarden = prnPerWeek(
        intakes: [
          _inname(2, '2026-11-24', aantal: 2),
          _inname(2, '2026-11-23'),
          _inname(2, '2026-11-16'),
          _inname(2, '2026-11-02'),
        ],
        medicatieId: 2,
        vandaag: vandaag,
        weken: 4,
      );

      // Weken: 02-11, 09-11, 16-11, 23-11
      expect(waarden, [1, 0, 1, 3]);
    });

    test('negeert andere medicatie en 0-innames', () {
      final waarden = prnPerWeek(
        intakes: [
          _inname(9, '2026-11-24', aantal: 3),
          _inname(2, '2026-11-24', aantal: 0),
        ],
        medicatieId: 2,
        vandaag: DateTime(2026, 11, 24),
        weken: 2,
      );
      expect(waarden, [0, 0]);
    });
  });
}
