// Borgt de dark-mode-sweep van de "lange staart" (09-2026):
// voortekenen, gewicht, login-foutkaart en help-legenda.
//
// vaste light-tinten (orange.shade50, blue.shade50, red[50], white,
// grey.shade700) vielen in dark mode uit elkaar. Nu brightness-aware
// helpers (streakText, infoOn, dangerOn, successOn) met alpha-tinten.
//
// De contrasten hieronder zijn met de WCAG 2.1-formule nagerekend voor
// de ECHTE achtergronden (surface / surfaceContainerHighest), beide modes.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/theme/app_theme.dart';

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

/// Broncode zonder commentaar.
String _code(String pad) {
  final zonderBlok =
      File(pad).readAsStringSync().replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return zonderBlok
      .split('\n')
      .map((regel) => regel.replaceAll(RegExp(r'//.*$'), ''))
      .join('\n');
}

void main() {
  group('Nieuwe helpers halen AA in beide modes', () {
    test('infoOn haalt 4.5:1 op de kaartkleuren', () {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        final b = theme.brightness;
        expect(
          _contrast(AppTheme.infoOn(b), theme.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('streakText en dangerOn blijven boven AA op surface', () {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        final b = theme.brightness;
        expect(
          _contrast(AppTheme.streakText(b), theme.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(AppTheme.dangerOn(b), theme.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  });

  group('Voortekenen is dark-proof', () {
    test('geen vaste light-tinten meer in checkitems en kaarten', () {
      final code = _code('lib/screens/voortekenen_screen.dart');
      expect(code.contains('Colors.orange.shade50'), isFalse);
      expect(code.contains('Colors.blue.shade50'), isFalse);
      expect(code.contains('Colors.white,'), isFalse,
          reason: 'witte checkitem-kaart in dark mode');
      expect(code.contains('Colors.red.shade100'), isFalse);
      expect(code.contains('Colors.orange.shade100'), isFalse);
      expect(code.contains('Colors.green.shade100'), isFalse);
    });

    test('snackbars gebruiken themakleuren', () {
      final code = _code('lib/screens/voortekenen_screen.dart');
      expect(code.contains('AppTheme.warning'), isTrue);
      expect(code.contains('backgroundColor: AppTheme.error'), isTrue);
      expect(code.contains('backgroundColor: Colors.red'), isFalse);
      expect(code.contains('backgroundColor: Colors.orange'), isFalse);
    });
  });

  group('Gewicht en login volgen het thema', () {
    test('gewicht: geen Colors.red/green snackbars meer', () {
      final code = _code('lib/screens/weight_screen.dart');
      expect(code.contains('backgroundColor: Colors.red'), isFalse);
      expect(code.contains('backgroundColor: Colors.green'), isFalse);
    });

    test('login: foutkaart gebruikt dangerOn, geen red[50]', () {
      final code = _code('lib/screens/login_screen.dart');
      expect(code.contains("Colors.red[50]"), isFalse);
      expect(code.contains('dangerOn'), isTrue);
      expect(code.contains('backgroundColor: Colors.white'), isFalse,
          reason: 'biometrie-knop was wit in dark mode');
    });

    test('login: destructieve knoppen via errorContainer', () {
      final code = _code('lib/screens/login_screen.dart');
      expect(code.contains('errorContainer'), isTrue);
    });
  });

  group('Help-teksten en legenda', () {
    test('geen grey.shade700-teksten meer', () {
      final code = _code('lib/screens/help_screen.dart');
      expect(code.contains('Colors.grey.shade700'), isFalse);
    });

    test('legenda-kleuren zijn brightness-aware', () {
      final code = _code('lib/screens/help_screen.dart');
      expect(code.contains('Colors.indigo.shade900'), isFalse);
      expect(code.contains('Colors.red.shade600'), isFalse);
      expect(code.contains('AppTheme.dangerOn'), isTrue);
      expect(code.contains('AppTheme.infoOn'), isTrue);
    });
  });
}
