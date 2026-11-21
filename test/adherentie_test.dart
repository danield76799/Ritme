import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/utils/adherentie.dart';

void main() {
  final vandaag = DateTime(2026, 11, 20);
  String d(int daysAgo) => DateTime(2026, 11, 20 - daysAgo).toIso8601String().substring(0, 10);

  test('adherentie telt ingenomen dagen over het venster', () {
    final configs = [
      {'id': 1, 'zo_nodig': 0, 'created_at': '2026-10-01T00:00:00.000Z'},
    ];
    final intakes = [
      for (var i = 0; i < 10; i++)
        {'medication_id': 1, 'date': d(i), 'aantal_ingenomen': 1},
    ];
    final r = berekenAdherentie(intakes: intakes, configs: configs, vandaag: vandaag);
    expect(r[1]!.dagen, 30);
    expect(r[1]!.percentage, ((10 * 100) / 30).round());
  });

  test('zo-nodig medicatie wordt overgeslagen', () {
    final configs = [
      {'id': 1, 'zo_nodig': 1, 'created_at': '2026-10-01T00:00:00.000Z'},
    ];
    final r = berekenAdherentie(intakes: [], configs: configs, vandaag: vandaag);
    expect(r.containsKey(1), isFalse);
  });

  test('korter venster bij recente aanmaakdatum', () {
    final configs = [
      {'id': 2, 'zo_nodig': 0, 'created_at': '2026-11-17T12:00:00.000Z'},
    ];
    final intakes = [
      {'medication_id': 2, 'date': d(0), 'aantal_ingenomen': 1},
      {'medication_id': 2, 'date': d(1), 'aantal_ingenomen': 1},
      {'medication_id': 2, 'date': d(2), 'aantal_ingenomen': 1},
      {'medication_id': 2, 'date': d(3), 'aantal_ingenomen': 1},
    ];
    final r = berekenAdherentie(intakes: intakes, configs: configs, vandaag: vandaag);
    expect(r[2]!.dagen, 4); // 17, 18, 19, 20 nov
    expect(r[2]!.percentage, 100);
  });

  test('meerdere innames op één dag tellen als één ingenomen dag', () {
    final configs = [
      {'id': 3, 'zo_nodig': 0, 'created_at': '2026-10-01T00:00:00.000Z'},
    ];
    final intakes = [
      {'medication_id': 3, 'date': d(0), 'aantal_ingenomen': 2},
      {'medication_id': 3, 'date': d(0), 'aantal_ingenomen': 1},
      {'medication_id': 3, 'date': d(5), 'aantal_ingenomen': 1},
    ];
    final r = berekenAdherentie(intakes: intakes, configs: configs, vandaag: vandaag);
    expect(r[3]!.percentage, ((2 * 100) / 30).round());
  });

  test('medicatie van vandaag: created_at vandaag telt één dag', () {
    final configs = [
      {'id': 4, 'zo_nodig': 0, 'created_at': '2026-11-20T08:00:00.000Z'},
    ];
    final r = berekenAdherentie(intakes: [], configs: configs, vandaag: vandaag);
    expect(r[4]!.dagen, 1);
    expect(r[4]!.percentage, 0);
  });
}
