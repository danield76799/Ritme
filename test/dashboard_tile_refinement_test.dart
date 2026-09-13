// Test voor de dashboardtegel-verfijningen.
//
// Dekt de twee dingen die stil kunnen breken:
//   1. de WCAG-contrastbeloftes van de accentkleuren en secundaire tekst
//   2. dat `isCompleted` echt het vinkje toont en weglaten ook echt weglaat
//
// De contrastcheck rekent zelf (relatieve luminantie volgens WCAG 2.1) in
// plaats van een kleur te vertrouwen: zo faalt de test zodra iemand een
// accenttint verandert naar iets dat op de kaart onleesbaar wordt.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ritme/theme/app_theme.dart';
import 'package:ritme/widgets/tile_accent.dart';

/// Relatieve luminantie volgens WCAG 2.1.
double _luminance(Color c) {
  final r = c.r, g = c.g, b = c.b; // Flutter 3.27+: 0..1 doubles
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
}

/// Contrastratio tussen twee kleuren.
double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Zet een kleur met alpha over een achtergrond (alpha-compositing).
Color _over(Color fg, Color bg, double alpha) => Color.fromARGB(
      255,
      ((fg.r * alpha + bg.r * (1 - alpha)) * 255).round(),
      ((fg.g * alpha + bg.g * (1 - alpha)) * 255).round(),
      ((fg.b * alpha + bg.b * (1 - alpha)) * 255).round(),
    );

void main() {
  const darkCard = AppTheme.darkCard;
  const lightCard = Color(0xFFFFFFFF);
  const darkBg = AppTheme.darkBackground;

  group('Tegel-accenten halen non-text contrast (>=3:1) op hun eigen kaart', () {
    const accenten = {
      'ochtend': TileAccent.morning,
      'avond': TileAccent.evening,
      'medicatie': TileAccent.medication,
      'dagboek': TileAccent.journal,
      'rapport': TileAccent.report,
      'afspraken': TileAccent.appointments,
    };

    accenten.forEach((naam, accent) {
      test('$naam (dark)', () {
        expect(_contrast(accent.dark, darkCard), greaterThanOrEqualTo(3.0),
            reason: '$naam dark faalt op de donkere kaart');
      });
      test('$naam (light)', () {
        expect(_contrast(accent.light, lightCard), greaterThanOrEqualTo(3.0),
            reason: '$naam light faalt op de witte kaart');
      });
    });

    test('dark en light variant zijn daadwerkelijk verschillend', () {
      accenten.forEach((naam, accent) {
        expect(accent.dark, isNot(accent.light),
            reason: '$naam heeft geen aparte light-variant');
      });
    });

    test('colorFor kiest de juiste variant', () {
      expect(TileAccent.morning.colorFor(Brightness.dark), TileAccent.morning.dark);
      expect(TileAccent.morning.colorFor(Brightness.light), TileAccent.morning.light);
    });
  });

  group('Secundaire tekst haalt WCAG AA (>=4.5:1)', () {
    test('darkTextSecondary op donkere achtergrond en kaart', () {
      expect(_contrast(AppTheme.darkTextSecondary, darkBg), greaterThanOrEqualTo(4.5));
      expect(_contrast(AppTheme.darkTextSecondary, darkCard), greaterThanOrEqualTo(4.5));
    });

    test('textMedium op witte kaart en lichte achtergrond', () {
      expect(_contrast(AppTheme.textMedium, lightCard), greaterThanOrEqualTo(4.5));
      expect(_contrast(AppTheme.textMedium, AppTheme.backgroundColor),
          greaterThanOrEqualTo(4.5));
    });

    test('de oude alpha-varianten waren echt te zwak (regressiewacht)', () {
      // Documenteert waarom de alpha-gedimde varianten vervangen zijn.
      final zwakDark = _over(AppTheme.darkTextSecondary, darkCard, 0.60);
      expect(_contrast(zwakDark, darkCard), lessThan(4.5),
          reason: 'als deze nu WEL slaagt is de kleur gewijzigd — check de swap');
    });
  });

  group('Statuskleuren', () {
    test('successOn haalt >=3:1 op de donkere kaart', () {
      expect(_contrast(AppTheme.successOn(Brightness.dark), darkCard),
          greaterThanOrEqualTo(3.0));
    });

    test('het oude donkere success (#2E7D32) faalde op de donkere kaart', () {
      expect(_contrast(const Color(0xFF2E7D32), darkCard), lessThan(3.0));
    });

    test('streakText haalt AA op zijn chip', () {
      // De chip is Colors.orange op 15% over de scaffoldBackground, dus de
      // effectieve achtergrond verschilt per theme.
      const darkChipBg = Color(0xFF332D19); // orange 15% over #0F1A1D
      const lightChipBg = Color(0xFFF8EAD4); // orange 15% over #F7F9FA
      expect(_contrast(AppTheme.streakText(Brightness.dark), darkChipBg),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(AppTheme.streakText(Brightness.light), lightChipBg),
          greaterThanOrEqualTo(4.5));
    });

    test('het oude orange.shade700 faalde op de chip', () {
      const darkChipBg = Color(0xFF332D19);
      expect(_contrast(const Color(0xFFE65100), darkChipBg), lessThan(4.5));
    });
  });

  group('TileIconBadge rendert de voltooiingsstatus', () {
    Widget wrap(Widget child) => MaterialApp(
          home: Scaffold(body: Center(child: child)),
        );

    testWidgets('toont een vinkje wanneer isCompleted true is', (tester) async {
      await tester.pumpWidget(wrap(const TileIconBadge(
        icon: Icons.wb_sunny,
        accent: TileAccent.morning,
        isCompleted: true,
      )));

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
    });

    testWidgets('toont géén vinkje wanneer isCompleted false is', (tester) async {
      await tester.pumpWidget(wrap(const TileIconBadge(
        icon: Icons.wb_sunny,
        accent: TileAccent.morning,
      )));

      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
    });

    testWidgets('isCompleted zet ook een accentrand', (tester) async {
      await tester.pumpWidget(wrap(const TileIconBadge(
        icon: Icons.menu_book,
        accent: TileAccent.journal,
        isCompleted: true,
      )));

      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byIcon(Icons.menu_book),
          matching: find.byType(Container),
        ).first,
      );
      final deco = container.decoration as BoxDecoration;
      expect(deco.border, isNotNull);
    });
  });
}
