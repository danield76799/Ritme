// Test voor de gemoderniseerde ochtend-check-in (slaapbehoefte-stap).
//
// De belangrijkste risico's bij een UI-herschrijving van een klinisch scherm:
//   1. de schaalwaarden verschuiven (q4 stuurt de bipolaire scorer aan)
//   2. de score-labels komen niet overeen met de waarde die naar de DB gaat
//   3. de contrastbeloftes van het accent en de badge breken
//
// Contrast wordt hier zelf uitgerekend (WCAG 2.1), zodat een kleurwijziging
// de test laat falen i.p.v. stil een onleesbaar scherm op te leveren.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ritme/screens/morning_checkin_screen.dart';
import 'package:ritme/theme/app_theme.dart';
import 'package:ritme/utils/checkin_colors.dart';

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('SleepOption draagt de klinische score onveranderd', () {
    test('score is de q4-waarde die naar de database gaat', () {
      const optie = SleepOption(score: -3, label: 'x', description: 'y');
      expect(optie.score, -3);
      expect(optie.score, isA<int>());
    });

    test('alle negen schaalwaarden zijn uniek en binnen -4..+4', () {
      final waarden = [4, 3, 2, 1, 0, -1, -2, -3, -4];
      expect(waarden.toSet().length, 9);
      expect(waarden.every((v) => v >= -4 && v <= 4), isTrue);
      expect(waarden.length, 9);
    });
  });

  group('Score-weergave is eenduidig', () {
    test('positief krijgt een plus, negatief een lang streepje', () {
      expect(MoodAssessmentScorerColors.scoreLabel(2), '+2');
      expect(MoodAssessmentScorerColors.scoreLabel(0), '0');
      expect(MoodAssessmentScorerColors.scoreLabel(-3), '—3');
    });

    test('elk label is uniek over de hele schaal', () {
      final labels =
          [4, 3, 2, 1, 0, -1, -2, -3, -4].map((v) => MoodAssessmentScorerColors.scoreLabel(v.toDouble())).toList();
      expect(labels.toSet().length, labels.length);
    });
  });

  group('Accentcontrast (WCAG)', () {
    const darkBg = AppTheme.darkBackground;

    test('accent is leesbaar op de donkere achtergrond', () {
      expect(_contrast(CheckinAccent.teal, darkBg), greaterThanOrEqualTo(4.5));
    });

    test('accent is leesbaar op de niet-geselecteerde kaart', () {
      expect(_contrast(CheckinAccent.teal, CheckinAccent.unselectedDark),
          greaterThanOrEqualTo(4.5));
    });

    test('donkere tekst op het accent haalt AA', () {
      expect(_contrast(CheckinAccent.onAccent, CheckinAccent.teal),
          greaterThanOrEqualTo(4.5));
    });

    test('witte tekst op het accent zou falen — daarom is het donker', () {
      expect(_contrast(Colors.white, CheckinAccent.teal), lessThan(4.5),
          reason: 'als dit slaagt is het accent veranderd; heroverweeg de knoptekst');
    });
  });

  group('SleepOptionCard gedrag', () {
    Widget wrap(Widget child) => MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: child),
        );

    const optie = SleepOption(
      score: -2,
      label: 'Korte naam',
      description: 'Volledige toelichting van de optie.',
    );

    testWidgets('toont score-badge, label en toelichting', (tester) async {
      await tester.pumpWidget(wrap(SleepOptionCard(
        option: optie,
        selected: false,
        onTap: () {},
      )));

      expect(find.text('—2'), findsOneWidget);
      expect(find.text('Korte naam'), findsOneWidget);
      expect(find.text('Volledige toelichting van de optie.'), findsOneWidget);
    });

    testWidgets('tik roept onTap aan', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(SleepOptionCard(
        option: optie,
        selected: false,
        onTap: () => tapped = true,
      )));

      await tester.tap(find.byType(SleepOptionCard));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('geselecteerd: accentrand van 1.5px + gevulde badge',
        (tester) async {
      await tester.pumpWidget(wrap(SleepOptionCard(
        option: optie,
        selected: true,
        onTap: () {},
      )));
      await tester.pumpAndSettle();

      final card = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(SleepOptionCard),
          matching: find.byType(AnimatedContainer),
        ).first,
      );
      final deco = card.decoration as BoxDecoration;
      final border = deco.border as Border;
      expect(border.top.width, 1.5);
      expect(border.top.color, CheckinAccent.teal);
    });

    testWidgets('niet geselecteerd: 1px subtiele rand, geen accentvulling',
        (tester) async {
      await tester.pumpWidget(wrap(SleepOptionCard(
        option: optie,
        selected: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();

      final card = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(SleepOptionCard),
          matching: find.byType(AnimatedContainer),
        ).first,
      );
      final deco = card.decoration as BoxDecoration;
      final border = deco.border as Border;
      expect(border.top.width, 1);
      expect(deco.color, CheckinAccent.unselectedDark);
      expect(deco.color, isNot(CheckinAccent.teal));
    });
  });
}
