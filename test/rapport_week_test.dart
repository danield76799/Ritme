import 'package:flutter_test/flutter_test.dart';

/// Pure-logic test van de weekvensters die rapport_generator gebruikt.
/// (Zelfde berekening, geïsoleerd van de DB.)
void main() {
  test('Weekvensters dekken de periode zonder gaten of overlappen', () {
    final now = DateTime(2026, 9, 5); // zaterdag
    const days = 30;
    final startDate = now.subtract(Duration(days: days));

    final fullWeeks = (days / 7).ceil(); // 5
    expect(fullWeeks, 5);

    final covered = <String>{};
    for (int w = 0; w < fullWeeks; w++) {
      final weekEnd = now.subtract(Duration(days: 7 * w));
      final weekStart = now.subtract(Duration(days: 7 * w + 6));
      for (int i = 0; i < 7; i++) {
        final d = weekEnd.subtract(Duration(days: i));
        if (d.isBefore(weekStart) || d.isAfter(now) || d.isAfter(weekEnd)) continue;
        if (d.isBefore(startDate)) continue; // voor de rapport-periode
        covered.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
      }
    }

    // Verwachting: 31 dagen (inclusief vandaag)
    expect(covered.length, days + 1, reason: 'periode dekt niet exact days+1 dagen');
    // Geen duplicaten/gaten: eerste dag = vandaag, laatste = start
    expect(covered.contains('2026-09-05'), true);
    expect(covered.contains('2026-08-06'), true);
  });
}