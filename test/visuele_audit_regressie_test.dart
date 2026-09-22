// Regressietests voor de visuele defecten die in de audit zijn gevonden.
//
// 1. Web-opstart: `Platform.isAndroid` gooit op web. Deze test bewaakt dat
//    geen Platform.is buiten een kIsWeb-guard wordt geëvalueerd.
// 2. Dashboard-overflow: de tijdchips liepen over op smalle schermen. Deze
//    test meet met echte fonts of de Row nog overloopt.
// 3. Dark-mode leesbaarheid: hardcoded donkere tekstkleuren zijn vervangen
//    door thema-helpers. Deze test rekent de contrasten door (WCAG 2.1).
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:ritme/database/hive_database_helper.dart';
import 'package:ritme/generated/l10n/app_localizations.dart';
import 'package:ritme/screens/dashboard_screen.dart';
import 'package:ritme/service_locator.dart';
import 'package:ritme/theme/app_theme.dart';

const _boxen = [
  'settings', 'daily_logs', 'srm_activities', 'mood_assessment',
  'medication_config', 'medication_intake', 'medication_schedule',
  'life_events', 'weight_logs', 'medical_appointments', 'crisis_plan',
  'prodromal_checklist', 'prodromal_logs', 'episode_logs', 'daily_dagboek',
];

/// Relatieve luminantie volgens WCAG 2.1.
double _kanaal(int v) {
  final s = v / 255.0;
  return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
}

double _luminantie(Color c) {
  final argb = c.toARGB32();
  final r = (argb >> 16) & 0xff;
  final g = (argb >> 8) & 0xff;
  final b = argb & 0xff;
  return 0.2126 * _kanaal(r) + 0.7152 * _kanaal(g) + 0.0722 * _kanaal(b);
}

double contrast(Color a, Color b) {
  final l1 = _luminantie(a);
  final l2 = _luminantie(b);
  final hi = math.max(l1, l2);
  final lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUpAll(() async {
    Hive.init('/tmp/hive_visueel');
    for (final n in _boxen) {
      if (!Hive.isBoxOpen(n)) await Hive.openBox(n);
    }
    setDbForTesting(HiveDatabaseHelper.instance);
    final f = File('/opt/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
    if (await f.exists()) {
      final l = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.view((await f.readAsBytes()).buffer)));
      await l.load();
    }
  });

  group('web-opstart', () {
    test('geen Platform.is zonder kIsWeb-guard in service_locator', () {
      final regels = File('lib/service_locator.dart').readAsStringSync().split('\n');
      for (var i = 0; i < regels.length; i++) {
        final r = regels[i];
        if (!r.contains('Platform.is')) continue;
        if (r.trimLeft().startsWith('//')) continue;
        if (r.trimLeft().startsWith('AppLogger.debug') && r.contains(r'${Platform')) {
          // Interpolatie wordt DIRECT geëvalueerd — mag alleen achter een guard.
          final ctx = regels.sublist(math.max(0, i - 4), i + 1).join('\n');
          expect(
            ctx.contains('kIsWeb'),
            isTrue,
            reason: 'regel ${i + 1} logt Platform.is zonder kIsWeb-guard: $r',
          );
          continue;
        }
        final ctx = regels.sublist(math.max(0, i - 4), i + 1).join('\n');
        expect(
          ctx.contains('kIsWeb') || ctx.contains('else'),
          isTrue,
          reason: 'regel ${i + 1} zonder kIsWeb-guard: $r',
        );
      }
    });
  });

  group('dashboard-overflow', () {
    Future<int> telOverflows(WidgetTester tester, Size size, double dpr) async {
      final meldingen = <String>[];
      final vorige = FlutterError.onError;
      FlutterError.onError = (d) {
        final s = d.exception.toString();
        if (s.contains('overflow')) meldingen.add(s.split('\n').first);
      };

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('nl'),
        theme: AppTheme.lightTheme,
        home: const DashboardScreen(),
      ));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      // HERSTEL vóór de assertie: anders klaagt de binding dat FlutterError.onError
      // nog overridden is terwijl er al een expect() loopt.
      FlutterError.onError = vorige;
      return meldingen.length;
    }

    testWidgets('geen overflow op een normaal toestel (412dp)', (tester) async {
      expect(await telOverflows(tester, const Size(1080, 2400), 2.625), 0,
          reason: 'dashboard loopt over op 412dp');
    });

    testWidgets('geen overflow op een smal toestel (320dp)', (tester) async {
      expect(await telOverflows(tester, const Size(640, 1280), 2.0), 0,
          reason: 'dashboard loopt over op 320dp');
    });
  });

  group('dark-mode leesbaarheid', () {
    test('primaryText haalt >=4.5:1 op donkere kaart en pagina', () {
      final k = AppTheme.primaryTextOn(Brightness.dark);
      expect(contrast(k, AppTheme.darkCard), greaterThanOrEqualTo(4.5));
      expect(contrast(k, AppTheme.darkBackground), greaterThanOrEqualTo(4.5));
    });

    test('mutedText haalt >=4.5:1 in beide modes', () {
      final d = AppTheme.mutedTextOn(Brightness.dark);
      expect(contrast(d, AppTheme.darkCard), greaterThanOrEqualTo(4.5));
      expect(contrast(d, AppTheme.darkBackground), greaterThanOrEqualTo(4.5));
      expect(contrast(AppTheme.mutedTextOn(Brightness.light), Colors.white),
          greaterThanOrEqualTo(4.5));
    });

    test('placeholderText blijft leesbaar (>=3:1)', () {
      expect(contrast(AppTheme.placeholderTextOn(Brightness.dark), AppTheme.darkCard),
          greaterThanOrEqualTo(3.0));
      expect(contrast(AppTheme.placeholderTextOn(Brightness.light), Colors.white),
          greaterThanOrEqualTo(3.0));
    });

    test('bewijs dat de oude hardcoded kleuren echt onleesbaar waren', () {
      expect(contrast(Colors.black, AppTheme.darkCard), lessThan(3.0),
          reason: 'was de oude kleur niet stuk, dan is de fix onnodig');
      expect(contrast(const Color(0xFF616161), AppTheme.darkCard), lessThan(3.0));
      expect(contrast(const Color(0xFF000000), AppTheme.darkBackground), lessThan(3.0));
    });
  });
}
