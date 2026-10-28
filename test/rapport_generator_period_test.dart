// Regressietests voor de periode- en noemer-consistentie van het
// Life Chart-rapport.
//
// Het probleem: de header toonde 15 kalenderdagen (14-10 t/m 28-10 bij een
// 14-daags rapport), terwijl het weekoverzicht met 14 dagen werkte en de
// medicatietelling een eigen noemer gebruikte. De periode moet nu overal
// exact dezelfde dagen bestrijken.

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/services/rapport_generator.dart';

void main() {
  group('periode', () {
    test('een rapport van 14 dagen is exact 14 kalenderdagen', () {
      final end = DateTime(2026, 10, 28);
      final start = RapportGenerator.periodStart(end, 14);
      expect(start, DateTime(2026, 10, 15));
      // Inclusief beide uiteinden zijn dit 14 dagen.
      expect(end.difference(start).inDays + 1, 14);
    });

    test('een rapport van 1 dag is vandaag zelf', () {
      final end = DateTime(2026, 10, 28);
      expect(RapportGenerator.periodStart(end, 1), end);
    });

    test('de periode start altijd op de dagdatum (geen tijdcomponent)', () {
      final end = DateTime(2026, 10, 28, 23, 59);
      final start = RapportGenerator.periodStart(end, 14);
      expect(start.hour, 0);
      expect(start.minute, 0);
    });
  });

  group('weken', () {
    test('14 dagen zijn twee weken van 7 dagen', () {
      final start = DateTime(2026, 10, 15);
      final end = DateTime(2026, 10, 28);
      final weeks = RapportGenerator.periodWeeks(start, end);
      expect(weeks.length, 2);
      expect(weeks.every((w) => w.length == 7), isTrue);
    });

    test('de weken bestrijken exact de periode, zonder gaten of overlap', () {
      final start = DateTime(2026, 10, 15);
      final end = DateTime(2026, 10, 28);
      final weeks = RapportGenerator.periodWeeks(start, end);
      final alleDagen = weeks.expand((w) => w).toList();
      expect(alleDagen.length, 14);
      expect(alleDagen.toSet().length, 14, reason: 'geen dubbele dagen');
      for (final d in alleDagen) {
        expect(d.isBefore(start), isFalse);
        expect(d.isAfter(end), isFalse);
      }
    });

    test('de nieuwste week staat bovenaan en is chronologisch', () {
      final start = DateTime(2026, 10, 15);
      final end = DateTime(2026, 10, 28);
      final weeks = RapportGenerator.periodWeeks(start, end);
      expect(weeks.first.first, DateTime(2026, 10, 22));
      expect(weeks.first.last, DateTime(2026, 10, 28));
      expect(weeks.last.first, DateTime(2026, 10, 15));
      expect(weeks.last.last, DateTime(2026, 10, 21));
    });

    test('een periode die niet op een weekgrens eindigt wordt afgeknipt', () {
      // 30 dagen: de laatste (oudste) week heeft maar 2 dagen.
      final start = DateTime(2026, 9, 29);
      final end = DateTime(2026, 10, 28);
      final weeks = RapportGenerator.periodWeeks(start, end);
      expect(weeks.length, 5);
      expect(weeks.last.length, 2);
      expect(weeks.expand((w) => w).length, 30);
    });
  });

  group('medicatienaam', () {
    test('trailing spaces verdwijnen', () {
      expect(RapportGenerator.formatMedName('Lurasidon '), 'Lurasidon');
      expect(RapportGenerator.formatMedName('lithium '), 'Lithium');
    });

    test('de eerste letter wordt een hoofdletter', () {
      expect(RapportGenerator.formatMedName('olanzapine'), 'Olanzapine');
      expect(RapportGenerator.formatMedName('Lithium'), 'Lithium');
    });

    test('een lege naam geeft een lege string', () {
      expect(RapportGenerator.formatMedName(''), '');
      expect(RapportGenerator.formatMedName('   '), '');
    });
  });
}
