// Borgt de look-and-feel-sweep (09-2026): destructive knoppen, radius- en
// typeschaal, thema-veilige kleuren.
//
// 1. DESTRUCTIEF: oranje/rode knoppen met witte tekst haalden 2.8-3.7:1.
//    Nu errorContainer/onErrorContainer (thema-gegarandeerd) en dangerOn
//    voor de tekstlink. Hier nagerekend in beide modes.
// 2. RADIUS: 10 verschillende stralen teruggebracht naar 12/16/24 (+999 pil
//    en 2/4/6 functioneel). Deze test faalt bij een nieuwe uitschieter.
// 3. TYPE: 10/11/15/17/22 afgerond naar de schaal (grafiekassen en PDF
//    uitgezonderd).
// 4. FALLBACKS: geen `?? Colors.white/black` meer; geen wit-op-primary.

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

List<String> _dartBestanden(String map) => Directory(map)
    .listSync(recursive: true)
    .map((e) => e.path)
    .where((p) => p.endsWith('.dart'))
    .toList();

void main() {
  group('Destructieve knoppen halen de norm', () {
    test('onErrorContainer op errorContainer haalt 4.5:1 (beide modes)',
        () {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        expect(
          _contrast(theme.colorScheme.onErrorContainer,
              theme.colorScheme.errorContainer),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('dangerOn-tekst op surface haalt 4.5:1 (beide modes)', () {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final theme = brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme;
        expect(
          _contrast(AppTheme.dangerOn(brightness), theme.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
          reason: 'verwijder-link in $brightness mode',
        );
      }
    });

    test('oranje/rood met wit zou hier falen (regressiedrempel)', () {
      expect(_contrast(Colors.white, Colors.orange), lessThan(3.0));
      expect(_contrast(Colors.white, Colors.red), lessThan(4.5));
    });
  });

  group('Hoekenschaal blijft bij 12/16/24', () {
    test('geen nieuwe radius-uitschieters in schermen/widgets', () {
      const toegestaan = {'2', '4', '6', '12', '16', '24', '999'};
      final fout = <String>[];
      for (final pad in [
        ..._dartBestanden('lib/screens'),
        ..._dartBestanden('lib/widgets'),
      ]) {
        for (final regel in File(pad).readAsLinesSync()) {
          if (regel.contains('pw.BorderRadius')) continue; // PDF, geen UI
          for (final m
              in RegExp(r'circular\((\d+)\)').allMatches(regel)) {
            if (!toegestaan.contains(m.group(1))) {
              fout.add('$pad: radius ${m.group(1)}');
            }
          }
        }
      }
      expect(fout, isEmpty, reason: fout.take(5).join('\n'));
    });

    test('smallRadius is gedocumenteerd en 12', () {
      expect(AppTheme.smallRadius, 12.0);
    });
  });

  group('Typeschaal zonder uitschieters', () {
    test('geen 10/11/15/17/22 buiten grafieken, PDF en themadefinities',
        () {
      final fout = <String>[];
      for (final pad in [
        ..._dartBestanden('lib/screens'),
        ..._dartBestanden('lib/widgets'),
      ]) {
        if (pad.endsWith('weekly_mood_chart.dart')) continue; // grafiekassen
        for (final regel in File(pad).readAsLinesSync()) {
          if (regel.contains('pw.TextStyle')) continue; // PDF
          for (final m in RegExp(r'fontSize: (10|11|15|17|22)\b')
              .allMatches(regel)) {
            fout.add('$pad: fontSize ${m.group(1)}');
          }
        }
      }
      expect(fout, isEmpty, reason: fout.take(5).join('\n'));
    });
  });

  group('Thema-veilige kleuren', () {
    test('geen harde wit/zwart-fallbacks meer', () {
      final fout = <String>[];
      for (final pad in [
        ..._dartBestanden('lib/screens'),
        ..._dartBestanden('lib/widgets'),
      ]) {
        final code = _code(pad);
        if (code.contains('?? Colors.white') ||
            code.contains('?? Colors.black')) {
          fout.add(pad);
        }
      }
      expect(fout, isEmpty, reason: fout.join('\n'));
    });

    test('geen wit-op-primary meer (wel onPrimary)', () {
      for (final pad in [
        ..._dartBestanden('lib/screens'),
        ..._dartBestanden('lib/widgets'),
      ]) {
        final regels = File(pad).readAsLinesSync();
        for (var i = 0; i < regels.length; i++) {
          if (!regels[i].contains('foregroundColor: Colors.white')) continue;
          final context =
              regels.sublist(i - 3 < 0 ? 0 : i - 3, i).join('\n');
          expect(
            context.contains(
                'backgroundColor: Theme.of(context).colorScheme.primary'),
            isFalse,
            reason: '$pad:${i + 1} wit op primary — gebruik onPrimary',
          );
        }
      }
    });
  });
}
