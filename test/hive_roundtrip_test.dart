import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ritme/database/hive_database_helper.dart';

/// Echte round-trip test: schrijft via de PRODUCTIE-methodes (insertSleepLog
/// + upsertDailyLog zoals de vragenlijst die gebruikt) en leest via
/// getDailyLogs — verifieert dat de dagrij beide bevat.
void main() {
  setUpAll(() {
    Hive.init('/tmp/hive_test_ritme2');
  });

  test('productie-flow: slaap-log + vragenlijst-log → 1 rij met beide', () async {
    if (Hive.isBoxOpen('daily_logs')) {
      await Hive.box('daily_logs').deleteFromDisk();
    }
    await Hive.openBox('daily_logs');
    // Reset de singleton-state (anders verwijst _dailyLogs naar de oude box)
    await boxClearAll();

    final helper = HiveDatabaseHelper.instance;

    // 1. Slaap-log via de productiemethode (int-key, _nextId)
    await helper.insertSleepLog('2026-09-06', '23:00', '07:30', 15);

    // 2. Vragenlijst-log via upsertDailyLog (date-key) — merge-preserving
    final existing = await helper.getDailyLog('2026-09-06');
    final log = existing != null ? Map<String, dynamic>.from(existing) : <String, dynamic>{};
    log['date'] = '2026-09-06';
    log['stemming_hoog'] = 2;
    log['stemming_laag'] = 2;
    log['gesplitste_stemming'] = 0;
    await helper.upsertDailyLog(log);

    // 3. Lees via getDailyLogs (de bron van statistieken/dashboard)
    final logs = await helper.getDailyLogs();
    final dayRow = logs.where((l) => l['date'] == '2026-09-06').toList();
    expect(dayRow.length, 1, reason: 'precies één dagrij per datum');

    final row = dayRow.first;
    final mood = row['stemming_hoog'] is num
        ? (row['stemming_hoog'] as num).toDouble()
        : double.tryParse(row['stemming_hoog']?.toString() ?? '');
    final sleep = row['sleep_hours'] is num
        ? (row['sleep_hours'] as num).toDouble()
        : double.tryParse(row['sleep_hours']?.toString() ?? '');

    expect(mood, isNotNull, reason: 'stemming_hoog moet in de dagrij zitten (vinkje + statistiek)');
    expect(sleep, isNotNull, reason: 'sleep_hours moet in de dagrij staan (slaap-KPI)');
    print('round-trip OK: mood=$mood, sleep=$sleep');
  });
}

Future<void> boxClearAll() async {
  final box = Hive.box('daily_logs');
  await box.clear();
}