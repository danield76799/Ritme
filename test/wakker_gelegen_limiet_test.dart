import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ritme/database/hive_database_helper.dart';

/// Regressietests voor de max-4-uur limiet op wakker-gelegen (awake_minutes).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('/tmp/ritme_wakker_limiet_test');
    for (final b in ['daily_logs', 'srm_activities']) {
      await Hive.openBox(b);
    }
  });

  tearDownAll(() async => Hive.deleteFromDisk());

  tearDown(() async {
    for (final b in ['daily_logs', 'srm_activities']) {
      await Hive.box(b).clear();
    }
  });

  test('insertSleepLog kapt wakker-gelegen af op 240 minuten', () async {
    final helper = HiveDatabaseHelper.instance;
    const dag = '2026-09-27';

    await helper.insertSleepLog(dag, '21:15', '08:30', 300);

    final rijen = Hive.box('daily_logs')
        .toMap()
        .values
        .where((v) => v['date'] == dag && v['awake_minutes'] != null)
        .toList();

    expect(rijen, hasLength(1));
    expect(rijen.first['awake_minutes'], 240,
        reason: 'wakker-gelegen boven 4 uur wordt afgekapt tot 240');
  });

  test('insertSleepLog houdt normale waarden exact in stand', () async {
    final helper = HiveDatabaseHelper.instance;
    const dag = '2026-09-27';

    await helper.insertSleepLog(dag, '21:15', '08:30', 90);

    final rijen = Hive.box('daily_logs')
        .toMap()
        .values
        .where((v) => v['date'] == dag && v['awake_minutes'] != null)
        .toList();

    expect(rijen.first['awake_minutes'], 90,
        reason: 'waarden binnen de limiet worden niet gewijzigd');
  });

  test('slaapduur rekent met de geclampte waarde, niet de invoer', () async {
    final helper = HiveDatabaseHelper.instance;
    const dag = '2026-09-27';

    // 21:15 -> 08:30 = 675 min; met 300 min wakker-gelegen (geclampt naar
    // 240) hoort de slaapduur 675 - 240 = 435 min = 7,25 uur te zijn.
    await helper.insertSleepLog(dag, '21:15', '08:30', 300);

    final rijen = Hive.box('daily_logs')
        .toMap()
        .values
        .where((v) => v['date'] == dag && v['sleep_hours'] != null)
        .toList();

    expect(
      double.tryParse(rijen.first['sleep_hours'].toString()),
      closeTo(7.25, 0.01),
      reason: 'de slaapduur rekent met de afgekaste 240, niet de invoer 300',
    );
  });
}