// Borgt dat de tijdchips op het dashboard nooit tekst afkappen.
//
// SYMPTOOM (gemeld): "eerst chips" — in de begroetingskaart stond
// "Opstaan 08…" in plaats van "Opstaan 08:00". De tijd, precies de informatie
// die de chip moet geven, viel weg.
//
// OORZAAK: twee chips in een Row met `Expanded` kregen elk de helft van de
// beschikbare breedte. GEMETEN: "Opstaan 08:00" vraagt 236px (inclusief icoon
// en padding) en "Slapen 23:00" 222px, samen 466px. In de kaart is zelfs op
// 412dp maar 339px beschikbaar, op 320dp 248px. Twee chips naast elkaar MET
// label passen dus op geen enkele telefoonbreedte — afkapping was onvermijdelijk.
//
// FIX: Wrap in plaats van Row+Expanded, en de chip houdt zijn natuurlijke
// breedte (geen Flexible/ellipsis meer). Past het niet naast elkaar, dan
// schuift de tweede chip naar de volgende regel. Op een tablet of in landscape
// passen ze wél naast elkaar.
//
// Deze test meet ECHTE truncatie: hij vergelijkt de breedte die de tekst nodig
// heeft met de breedte die hij gerenderd krijgt. Tekst die netjes omwikkelt
// telt niet als afgekapt — alleen horizontaal afgesneden tekst.

import 'dart:io';

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

Future<void> _laadFonts() async {
  // Zonder de echte fonts rendert elke tekst als een effen balk en meet je
  // niets. De gewichten zijn nodig omdat de chips fontWeight.w600 gebruiken.
  for (final f in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ]) {
    final file = File('/opt/flutter/bin/cache/artifacts/material_fonts/$f');
    if (await file.exists()) {
      final l = FontLoader('Roboto')
        ..addFont(
          Future.value(ByteData.view((await file.readAsBytes()).buffer)),
        );
      await l.load();
    }
  }
  final icons = File(
    '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (await icons.exists()) {
    final l = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(ByteData.view((await icons.readAsBytes()).buffer)),
      );
    await l.load();
  }
}

Future<void> _bouwDashboard(WidgetTester t, Size size, double dpr) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = dpr;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('nl'),
      theme: AppTheme.lightTheme,
      home: const DashboardScreen(),
    ),
  );
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  while (t.takeException() != null) {}
}

/// Geeft per chip de gerenderde breedte en de breedte die de tekst nodig heeft.
List<({String tekst, double gerenderd, double nodig})> _meetChips(
  WidgetTester t,
) {
  final uit = <({String tekst, double gerenderd, double nodig})>[];
  for (final e in find.byType(Text).evaluate()) {
    final w = e.widget as Text;
    final data = w.textSpan?.toPlainText() ?? w.data ?? '';
    if (data.isEmpty) continue;
    if (!(data.contains('Opstaan') || data.contains('Slapen'))) continue;
    final rp = e.renderObject;
    if (rp is! RenderBox) continue;
    final volledig = TextPainter(
      text: TextSpan(text: data, style: w.style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);
    uit.add((
      tekst: data,
      gerenderd: rp.size.width,
      nodig: volledig.width,
    ));
  }
  return uit;
}

void main() {
  setUpAll(() async {
    Hive.init('/tmp/hive_chipfix');
    for (final n in _boxen) {
      if (!Hive.isBoxOpen(n)) await Hive.openBox(n);
    }
    setDbForTesting(HiveDatabaseHelper.instance);
    await _laadFonts();
  });

  for (final cfg in [
    ('412dp', const Size(1080, 2400), 2.625),
    ('360dp', const Size(1080, 1920), 3.0),
    ('320dp', const Size(640, 1280), 2.0),
  ]) {
    testWidgets('tijdchips kappen niets af op ${cfg.$1}', (t) async {
      await _bouwDashboard(t, cfg.$2, cfg.$3);
      final chips = _meetChips(t);

      expect(
        chips,
        isNotEmpty,
        reason: 'geen tijdchips gevonden — dan meet deze test niets',
      );

      for (final c in chips) {
        expect(
          c.gerenderd + 0.5,
          greaterThanOrEqualTo(c.nodig),
          reason: '"${c.tekst}" krijgt ${c.gerenderd.toStringAsFixed(0)}px '
              'maar heeft ${c.nodig.toStringAsFixed(0)}px nodig — dit is de '
              'afkapping waarbij de TIJD wegvalt',
        );
      }
    });
  }

  testWidgets('de twee chips staan niet meer in een Expanded-Row', (
    t,
  ) async {
    // Structurele borging: Expanded deelde de breedte in tweeën, waardoor
    // krimp onvermijdelijk was. Wrap laat de natuurlijke breedte intact.
    final bron = File('lib/screens/dashboard_screen.dart').readAsStringSync();
    final zonderCommentaar = bron
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
        .split('\n')
        .map((r) => r.replaceAll(RegExp(r'//.*$'), ''))
        .join('\n');
    final idx = zonderCommentaar.indexOf('_buildTimeChip(');
    expect(idx, greaterThan(-1));
    final rondom = zonderCommentaar.substring(
      (idx - 600).clamp(0, zonderCommentaar.length),
      idx,
    );
    expect(
      rondom.contains('Wrap('),
      isTrue,
      reason: 'de chips moeten in een Wrap staan, niet in een Row met Expanded',
    );
  });

  testWidgets('de chip zelf krimpt niet meer met ellipsis', (t) async {
    final bron = File('lib/screens/dashboard_screen.dart').readAsStringSync();
    final zonderCommentaar = bron
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
        .split('\n')
        .map((r) => r.replaceAll(RegExp(r'//.*$'), ''))
        .join('\n');
    final start = zonderCommentaar.indexOf('Widget _buildTimeChip');
    expect(start, greaterThan(-1));
    final einde = zonderCommentaar.indexOf('Widget _buildActionCard', start);
    final chip = zonderCommentaar.substring(start, einde);
    expect(
      chip.contains('TextOverflow.ellipsis'),
      isFalse,
      reason: 'ellipsis in de chip is precies wat de tijd wegkapte',
    );
    expect(
      chip.contains('Flexible'),
      isFalse,
      reason: 'Flexible liet de chip krimpen; de Wrap regelt de plaatsing nu',
    );
  });
}
