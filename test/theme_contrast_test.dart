// Borgt de WCAG-contrastfixes in het thema.
//
// Aanleiding: de AppBar gebruikte op ~20 schermen `onPrimary` op `primary`.
// In light mode was dat wit op #4FB2C1 = 2.48:1 — onder de norm, op vrijwel
// elk scherm. In dark mode was het in orde (9.3:1), waardoor het onopgemerkt
// bleef zolang je de telefoon in dark mode had.
//
// Deze test rekent de WCAG 2.1-relatieve luminantie zelf uit, zodat een
// toekomstige kleurwijziging niet stil de norm kan breken.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/theme/app_theme.dart';
import 'package:ritme/widgets/tile_accent.dart';

/// Relatieve luminantie volgens WCAG 2.1.
double _luminance(Color c) {
  double channel(double v) {
    final s = v;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// Contrastverhouding tussen twee kleuren (1.0 - 21.0).
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Mengt [fg] over [bg] met de gegeven alpha, zoals Flutter dat rendert.
Color blend(Color fg, Color bg, double alpha) => Color.from(
      alpha: 1,
      red: fg.r * alpha + bg.r * (1 - alpha),
      green: fg.g * alpha + bg.g * (1 - alpha),
      blue: fg.b * alpha + bg.b * (1 - alpha),
    );

void main() {
  group('Light mode: AppBar-titel is leesbaar', () {
    // De AppBar op ~20 schermen: titel in onPrimary op colorScheme.primary.
    // 20sp w700 is "large text" -> WCAG eist 3.0:1.
    test('wit op primary haalt minstens 4.5:1', () {
      final theme = AppTheme.lightTheme;
      final v = contrast(theme.colorScheme.onPrimary, theme.colorScheme.primary);
      expect(v, greaterThanOrEqualTo(4.5),
          reason: 'AppBar-titel/icoon moet AA-norm halen, niet alleen large-text 3.0');
    });

    test('het oude #4FB2C1 zou hier gefaald hebben (regressiedrempel)', () {
      // Vastleggen waarom de wijziging nodig was: 2.48:1.
      final v = contrast(Colors.white, AppTheme.medicalTeal);
      expect(v, lessThan(3.0),
          reason: 'documenteert dat medicalTeal onbruikbaar is op wit');
    });

    test('accenttekst op een witte kaart haalt 4.5:1', () {
      final theme = AppTheme.lightTheme;
      final v = contrast(theme.colorScheme.primary, AppTheme.surfaceColor);
      expect(v, greaterThanOrEqualTo(4.5),
          reason: 'links, text-buttons en outlined buttons gebruiken deze kleur');
    });

    test('accenttekst op de scaffold-achtergrond haalt 4.5:1', () {
      final theme = AppTheme.lightTheme;
      final v = contrast(theme.colorScheme.primary, AppTheme.backgroundColor);
      expect(v, greaterThanOrEqualTo(4.5));
    });
  });

  group('Dark mode: AppBar-titel is leesbaar', () {
    test('onPrimary op primary haalt 4.5:1', () {
      final theme = AppTheme.darkTheme;
      final v = contrast(theme.colorScheme.onPrimary, theme.colorScheme.primary);
      expect(v, greaterThanOrEqualTo(4.5));
    });

    test('accent op de donkere kaart haalt 3:1 (non-text)', () {
      final theme = AppTheme.darkTheme;
      final v = contrast(theme.colorScheme.primary, AppTheme.darkCard);
      expect(v, greaterThanOrEqualTo(3.0));
    });
  });

  group('Accent-helper kiest de juiste variant', () {
    test('light gebruikt de donkere teal', () {
      expect(AppTheme.accentOn(Brightness.light), AppTheme.medicalTealDeep);
    });

    test('dark gebruikt de lichte teal', () {
      expect(AppTheme.accentOn(Brightness.dark), AppTheme.medicalTealLight);
    });

    test('beide varianten zijn zelf leesbaar op hun eigen ondergrond', () {
      final opWit = contrast(AppTheme.medicalTealDeep, AppTheme.surfaceColor);
      final opDonker = contrast(AppTheme.medicalTealLight, AppTheme.darkCard);
      expect(opWit, greaterThanOrEqualTo(4.5));
      expect(opDonker, greaterThanOrEqualTo(4.5));
    });

    test('de helper komt overeen met colorScheme.primary in beide themes', () {
      // Zo blijft de sweep (primaryTeal -> colorScheme.primary) consistent met
      // de helper: beide wijzen naar dezelfde brightness-aware kleur.
      expect(AppTheme.accentOn(Brightness.light), AppTheme.lightTheme.colorScheme.primary);
      expect(AppTheme.accentOn(Brightness.dark), AppTheme.darkTheme.colorScheme.primary);
    });
  });

  group('Gedempte accenten op de tegels blijven leesbaar (non-text, 3:1)', () {
    final accenten = {
      'ochtend': TileAccent.morning,
      'avond': TileAccent.evening,
      'medicatie': TileAccent.medication,
      'dagboek': TileAccent.journal,
      'rapport': TileAccent.report,
      'afspraken': TileAccent.appointments,
    };

    accenten.forEach((naam, accent) {
      test('$naam: light-variant haalt 3:1 op wit', () {
        expect(contrast(accent.light, AppTheme.surfaceColor),
            greaterThanOrEqualTo(3.0));
      });

      test('$naam: dark-variant haalt 3:1 op de donkere kaart', () {
        expect(contrast(accent.dark, AppTheme.darkCard),
            greaterThanOrEqualTo(3.0));
      });
    });
  });

  group('Rood is leesbaar in beide modes', () {
    test('danger() op de eigen kaart: tekst haalt 4.5:1', () {
      expect(contrast(AppTheme.dangerOn(Brightness.light), AppTheme.surfaceColor),
          greaterThanOrEqualTo(4.5));
      expect(contrast(AppTheme.dangerOn(Brightness.dark), AppTheme.darkCard),
          greaterThanOrEqualTo(4.5));
    });

    test('het oude error-rood zakte op de donkere kaart (regressiedrempel)', () {
      // #D32F2F op #223236 = 3.15:1 — onleesbaar precies bij een foutmelding.
      expect(contrast(AppTheme.error, AppTheme.darkCard), lessThan(4.5));
    });

    test('error als achtergrond met witte tekst haalt 4.5:1', () {
      expect(contrast(Colors.white, AppTheme.error), greaterThanOrEqualTo(4.5));
    });

    test('Colors.red zou hier gefaald hebben (regressiedrempel)', () {
      // Colors.red (#F44336) met witte knoptekst = 3.68:1.
      expect(contrast(Colors.white, Colors.red), lessThan(4.5));
    });

    test('AppTheme.success haalt 4.5:1 met witte snackbar-tekst', () {
      expect(contrast(Colors.white, AppTheme.success), greaterThanOrEqualTo(4.5));
    });

    test('green[700] zou hier gefaald hebben (regressiedrempel)', () {
      expect(contrast(Colors.white, Colors.green[700]!), lessThan(4.5));
    });
  });

  group('Rode iconen op de AppBar (non-text, 3:1)', () {
    // De AppBar is in dark mode LICHT en in light mode DONKER — omgekeerd aan
    // de rest van het scherm. De reset-knop (wist de database) was
    // Colors.red.shade300 en haalde op beide balken <2:1: onzichtbaar.
    test('dark: tint haalt 3:1 op de lichte AppBar', () {
      expect(
          contrast(
              AppTheme.dangerOnAppBar(Brightness.dark), AppTheme.darkTheme.colorScheme.primary),
          greaterThanOrEqualTo(3.0));
    });

    test('light: tint haalt 3:1 op de donkere AppBar', () {
      expect(
          contrast(
              AppTheme.dangerOnAppBar(Brightness.light), AppTheme.lightTheme.colorScheme.primary),
          greaterThanOrEqualTo(3.0));
    });

    test('red.shade300 zakte op beide balken (regressiedrempel)', () {
      expect(contrast(Colors.red.shade300, AppTheme.darkTheme.colorScheme.primary),
          lessThan(3.0));
      expect(contrast(Colors.red.shade300, AppTheme.lightTheme.colorScheme.primary),
          lessThan(3.0));
    });
  });

  group('Begroetingskaart: tekst op de gradient blijft leesbaar', () {
    // De kaart gebruikt in beide modes onSurface als tekstkleur, met de datum
    // op 85% alpha. Beide uiteinden van de gradient moeten de norm halen.
    test('light: titel en datum op beide gradientuiteinden', () {
      final colors = AppTheme.brandGradient.colors;
      final tekst = AppTheme.textCharcoal;
      for (final bg in colors) {
        expect(contrast(tekst, bg), greaterThanOrEqualTo(4.5),
            reason: 'titel 28sp w800 is large text, maar 4.5 is veiliger');
        expect(contrast(blend(tekst, bg, 0.85), bg), greaterThanOrEqualTo(4.5),
            reason: 'datumregel staat op 85% opacity');
      }
    });
  });
}
