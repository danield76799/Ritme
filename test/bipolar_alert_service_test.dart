// Tests voor de bipolaire waarschuwingen (BipolarAlertService).
// De service las voorheen slaap uit 'sleep_hours'/'uren_slaap' en
// berekent SRT-afwijking over per-dag gemiddelde P-scores; deze tests
// zetten het rekenwerk vast (regressie: de SRT-baseline was ooit stuk).

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/service_locator.dart';
import 'package:ritme/services/bipolar_alert_service.dart';

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class FakeAlertDb implements DatabaseRepository {
  FakeAlertDb({this.logs = const [], this.srm = const {}, this.prodromal = const []});

  final List<Map<String, dynamic>> logs;
  final Map<String, List<Map<String, dynamic>>> srm;
  final List<Map<String, dynamic>> prodromal;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  @override
  Future<List<Map<String, dynamic>>> getDailyLogs() async => logs;

  @override
  Future<List<Map<String, dynamic>>> getSrmActivities(String date) async =>
      srm[date] ?? [];

  @override
  Future<List<Map<String, dynamic>>> getRecentProdromalTrends(int days) async =>
      prodromal;
}

/// Slaaplogs voor [days] dagen terug t/m vandaag. [sleepFor] geeft de uren
/// per dag-index (0 = vandaag).
List<Map<String, dynamic>> _slaapLogs(DateTime now, double Function(int daysAgo) sleep) {
  return List.generate(30, (i) {
    final d = now.subtract(Duration(days: i));
    return {'date': _dateStr(d), 'sleep_hours': sleep(i)};
  });
}

/// SRM-activiteiten per dag: elke dag `scores(i)` scores.
Map<String, List<Map<String, dynamic>>> _srmMap(
    DateTime now, List<int> Function(int daysAgo) scores) {
  final map = <String, List<Map<String, dynamic>>>{};
  for (var i = 0; i < 14; i++) {
    final d = _dateStr(now.subtract(Duration(days: i)));
    final s = scores(i);
    if (s.isEmpty) continue;
    map[d] = s.map((p) => {'p_score': p}).toList();
  }
  return map;
}

void main() {
  final now = DateTime.now();

  group('checkSleepBaseline', () {
    test('stabiele slaap → geen alarm', () async {
      setDbForTesting(FakeAlertDb(logs: _slaapLogs(now, (_) => 7.5)));
      expect(await BipolarAlertService.instance.checkSleepBaseline(), isNull);
    });

    test('plotselinge korte nacht (>30% onder baseline) → hoog alarm', () async {
      setDbForTesting(FakeAlertDb(logs: _slaapLogs(now, (i) => i == 0 ? 4.0 : 8.0)));
      final alert = await BipolarAlertService.instance.checkSleepBaseline();
      expect(alert, isNotNull);
      expect(alert!.type, 'slaap_afname');
      expect(alert.severity, 'high');
    });

    test('matige daling (>20%, <7u) → mild alarm', () async {
      // 5.5 vs baseline 7.5 → 26.7% daling, boven de 20%-drempel, onder 30%
      setDbForTesting(FakeAlertDb(logs: _slaapLogs(now, (i) => i == 0 ? 5.5 : 7.5)));
      final alert = await BipolarAlertService.instance.checkSleepBaseline();
      expect(alert, isNotNull);
      expect(alert!.type, 'slaap_afname_mild');
      expect(alert.severity, 'medium');
    });

    test('de afwijkende nacht telt zelf niet mee voor de baseline', () async {
      // Alle nachten 4 uur: baseline (exclusief vannacht) is dus óók 4 uur,
      // afwijking 0% → géén alarm, ook al is 4u op zichzelf alarmerend weinig.
      setDbForTesting(FakeAlertDb(logs: _slaapLogs(now, (_) => 4.0)));
      expect(await BipolarAlertService.instance.checkSleepBaseline(), isNull);
    });

    test('te weinig data (<5 basisdagen) → geen alarm', () async {
      final logs = _slaapLogs(now, (_) => 8.0).take(4).toList();
      setDbForTesting(FakeAlertDb(logs: logs));
      expect(await BipolarAlertService.instance.checkSleepBaseline(), isNull);
    });

    test('plotselinge lange slaap (>150% baseline en >10u) → toename-signaal',
        () async {
      setDbForTesting(
          FakeAlertDb(logs: _slaapLogs(now, (i) => i == 0 ? 11.0 : 7.0)));
      final alert = await BipolarAlertService.instance.checkSleepBaseline();
      expect(alert, isNotNull);
      expect(alert!.type, 'slaap_toename');
    });
  });

  group('checkSRTStability', () {
    test('stabiel ritme → geen alarm', () async {
      setDbForTesting(FakeAlertDb(srm: _srmMap(now, (i) => [5, 5, 4])));
      expect(await BipolarAlertService.instance.checkSRTStability(), isNull);
    });

    test('recente daling >30% t.o.v. baseline → alarm', () async {
      // Laatste 7 dagen P=2, de 7 dagen daarvoor P=5 → 2 < 5*0.7
      setDbForTesting(FakeAlertDb(
          srm: _srmMap(now, (i) => i < 7 ? [2] : [5])));
      final alert = await BipolarAlertService.instance.checkSRTStability();
      expect(alert, isNotNull);
      expect(alert!.type, 'srt_daling');
    });

    test('minder dan 3 waarneemdagen in de laatste week → geen alarm', () async {
      setDbForTesting(FakeAlertDb(
          srm: _srmMap(now, (i) => i < 2 ? [1] : (i < 7 ? [] : [5]))));
      expect(await BipolarAlertService.instance.checkSRTStability(), isNull);
    });
  });

  group('checkProdromalTrend', () {
    test('8+ voortekenen in 3 dagen → hoog alarm', () async {
      setDbForTesting(FakeAlertDb(prodromal: const [
        {'warning_count': 3},
        {'warning_count': 3},
        {'warning_count': 2},
      ]));
      final alert = await BipolarAlertService.instance.checkProdromalTrend();
      expect(alert, isNotNull);
      expect(alert!.type, 'voortekenen_hoog');
    });

    test('5-7 voortekenen → matig alarm', () async {
      setDbForTesting(FakeAlertDb(prodromal: const [
        {'warning_count': 2},
        {'warning_count': 2},
        {'warning_count': 1},
      ]));
      final alert = await BipolarAlertService.instance.checkProdromalTrend();
      expect(alert, isNotNull);
      expect(alert!.type, 'voortekenen_matig');
    });

    test('minder dan 5 voortekenen → geen alarm', () async {
      setDbForTesting(FakeAlertDb(prodromal: const [
        {'warning_count': 1},
        {'warning_count': 1},
      ]));
      expect(await BipolarAlertService.instance.checkProdromalTrend(), isNull);
    });

    test('minder dan 2 dagen data → geen alarm', () async {
      setDbForTesting(
          FakeAlertDb(prodromal: const [{'warning_count': 9}]));
      expect(await BipolarAlertService.instance.checkProdromalTrend(), isNull);
    });
  });
}
