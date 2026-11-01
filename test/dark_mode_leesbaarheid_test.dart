// Dark-mode leesbaarheid: hardcoded kleuren die het thema niet volgen.
//
// HET PROBLEEM (audit 01-11-2026):
//   Op twee plekken werd `AppTheme.textCharcoal` (0xFF222222, bijna zwart)
//   RECHTSTREEKS als tekstkleur gebruikt — zonder dark-mode-variant. Op de
//   donkere achtergrond gaf dat ~1.3:1: onleesbaar. Hetzelfde gold voor de
//   bleke slaapkaartkleur 0xFF88B0C7, die als icoon op een witte kaart
//   wegviel.
//
//   De fix: tekst gebruikt `colorScheme.onSurface`, de slaapkaart gebruikt
//   `AppTheme.accentOn(brightness)` (mode-bewust teal), en de grafiek-
//   rasterlijnen volgen `colorScheme.outlineVariant`.
//
// Dit meet de echte contrastverhoudingen van de vervangende kleuren, zodat
// de bewering niet op broncode alleen rust.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ritme/theme/app_theme.dart';

double _kanaal(int v) {
  final s = v / 255.0;
  return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
}

double _luminantie(Color c) {
  final a = c.toARGB32();
  return 0.2126 * _kanaal((a >> 16) & 0xff) +
      0.7152 * _kanaal((a >> 8) & 0xff) +
      0.0722 * _kanaal(a & 0xff);
}

double _contrast(Color a, Color b) {
  final l1 = _luminantie(a), l2 = _luminantie(b);
  final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('contrast van de mode-bewuste kleuren', () {
    test('tekst op donkere achtergrond haalt AA (4.5)', () {
      final tekst = AppTheme.primaryTextOn(Brightness.dark);
      final c = _contrast(tekst, AppTheme.darkSurface);
      expect(c, greaterThanOrEqualTo(4.5), reason: 'gemeten $c');
    });

    test('tekst op lichte achtergrond haalt AA (4.5)', () {
      final tekst = AppTheme.primaryTextOn(Brightness.light);
      final c = _contrast(tekst, AppTheme.surfaceColor);
      expect(c, greaterThanOrEqualTo(4.5), reason: 'gemeten $c');
    });

    test('de slaapkaart-accent is leesbaar in donker (>=3, icoon)', () {
      final c = _contrast(
        AppTheme.accentOn(Brightness.dark),
        AppTheme.darkSurface,
      );
      expect(c, greaterThanOrEqualTo(3.0), reason: 'gemeten $c');
    });

    test('de slaapkaart-accent is leesbaar in licht (>=3, icoon)', () {
      final c = _contrast(
        AppTheme.accentOn(Brightness.light),
        AppTheme.surfaceColor,
      );
      expect(c, greaterThanOrEqualTo(3.0), reason: 'gemeten $c');
    });

    test('textCharcoal rechtstreeks op donker was het probleem (< 4.5)', () {
      final c = _contrast(AppTheme.textCharcoal, AppTheme.darkSurface);
      expect(c, lessThan(4.5), reason: 'dit is precies waarom direct gebruik '
          'onleesbaar was (gemeten $c)');
    });
  });

  group('broncode', () {
    test('statistieken gebruikt textCharcoal niet meer rechtstreeks', () {
      final inhoud = File(
        'lib/screens/statistics_screen.dart',
      ).readAsStringSync();
      expect(inhoud.contains('color: AppTheme.textCharcoal'), isFalse);
    });

    test('episodes gebruikt textCharcoal niet meer rechtstreeks', () {
      final inhoud = File(
        'lib/screens/episodes_screen.dart',
      ).readAsStringSync();
      expect(inhoud.contains('color: AppTheme.textCharcoal'), isFalse);
    });

    test('de slaapkaart gebruikt de mode-bewuste accentkleur', () {
      final inhoud = File(
        'lib/screens/dashboard_screen.dart',
      ).readAsStringSync();
      expect(inhoud.contains('0xFF88B0C7'), isFalse);
      expect(
        inhoud.contains('AppTheme.accentOn(Theme.of(context).brightness)'),
        isTrue,
      );
    });

    test('de grafiek-rasterlijnen volgen het thema', () {
      final inhoud = File(
        'lib/screens/statistics_screen.dart',
      ).readAsStringSync();
      expect(
        inhoud.contains('getDrawingHorizontalLine'),
        isTrue,
        reason: 'de rasterlijnen krijgen nu een themakleur in plaats van de '
            'fl_chart-standaard',
      );
    });
  });
}
