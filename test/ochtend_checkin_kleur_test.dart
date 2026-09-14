// Regressietests voor de ochtend-check-in opfris (09-2026).
//
// 1. KLEUR PER ANTWOORD. De q4-kaarten waren effen (één accent), waardoor de
//    flow kaal oogde. Nu toont elke score zijn eigen kleur gedempt
//    (badge-ring + tint; gevuld bij selectie). De klinische mapping
//    (slaapbehoefteColor) mag daarbij NOOIT verschuiven — vandaar pin-tests.
//
// 2. LEESBAARHEID. Gevulde badges krijgen donkere of witte tekst via
//    tekstOp(), zodat alle 9 scores + 5 kwaliteitsniveaus WCAG AA (≥4.5:1)
//    halen. Hier zelf uitgerekend, net als in morning_checkin_refinement_test.
//
// 3. NIEUWE STAP "HOE HEB JE GESLAPEN" (kwaliteit 1..5, puur log — stuurt
//    geen klinische drempels aan). Flow is nu 4 stappen; sleep_quality wordt
//    merge-preserving in daily_log bewaard en in het overzicht getoond.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/screens/morning_checkin_screen.dart' show kwaliteitKleur;
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

/// Broncode zonder commentaar: de uitleg bij een fix citeert bewust de oude
/// code, en daar mag een structuurtest niet op stuklopen.
String _code(String pad) {
  final zonderBlok =
      File(pad).readAsStringSync().replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return zonderBlok
      .split('\n')
      .map((regel) => regel.replaceAll(RegExp(r'//.*$'), ''))
      .join('\n');
}

void main() {
  group('Klinische q4-kleuren verschuiven nooit', () {
    test('alle 9 scores hebben hun vaste kleur', () {
      const verwacht = {
        -4: 0xFF616161,
        -3: 0xFF424242,
        -2: 0xFF42A5F5,
        -1: 0xFF90CAF9,
        0: 0xFF66BB6A,
        1: 0xFFFDD835,
        2: 0xFFFF9800,
        3: 0xFFF57C00,
        4: 0xFFE53935,
      };
      for (final e in verwacht.entries) {
        expect(
          MoodAssessmentScorerColors.slaapbehoefteColor(e.key.toDouble()),
          Color(e.value),
          reason: 'score ${e.key} moet zijn kleur houden (scorer-drempels)',
        );
      }
    });
  });

  group('Gevulde badges blijven leesbaar (WCAG AA)', () {
    test('tekstOp op vulling haalt ≥4.5:1 op alle 9 q4-kleuren', () {
      for (var v = -4; v <= 4; v++) {
        final kleur =
            MoodAssessmentScorerColors.slaapbehoefteColor(v.toDouble());
        final vulling = MoodAssessmentScorerColors.badgeVulling(kleur);
        final tekst = MoodAssessmentScorerColors.tekstOp(vulling);
        expect(_contrast(tekst, vulling), greaterThanOrEqualTo(4.5),
            reason: 'score $v onleesbaar op eigen badge');
      }
    });

    test('tekstOp op vulling haalt ≥4.5:1 op alle 5 kwaliteitskleuren', () {
      for (var v = 1; v <= 5; v++) {
        final kleur = kwaliteitKleur(v);
        final vulling = MoodAssessmentScorerColors.badgeVulling(kleur);
        final tekst = MoodAssessmentScorerColors.tekstOp(vulling);
        expect(_contrast(tekst, vulling), greaterThanOrEqualTo(4.5),
            reason: 'kwaliteit $v onleesbaar op eigen badge');
      }
    });

    test('alleen te lichte vullingen worden verdiept', () {
      // Blauw (-2) en geel: donkere tekst haalt het direct — vulling blijft
      // de echte klinische kleur.
      expect(
        MoodAssessmentScorerColors.badgeVulling(
            MoodAssessmentScorerColors.slaapbehoefteColor(-2)),
        MoodAssessmentScorerColors.slaapbehoefteColor(-2),
      );
      // Rood haalt het met geen enkele tekst — vulling wordt verdiept,
      // ring en kaart-tint tonen de echte kleur.
      final rood = MoodAssessmentScorerColors.slaapbehoefteColor(4);
      final vulling = MoodAssessmentScorerColors.badgeVulling(rood);
      expect(vulling, isNot(rood));
      expect(
        _contrast(MoodAssessmentScorerColors.tekstOp(vulling), vulling),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('Kwaliteitskleuren lopen van rood naar groen', () {
    test('1..5 hebben elk een eigen kleur', () {
      final kleuren = [for (var v = 1; v <= 5; v++) kwaliteitKleur(v)];
      expect(kleuren.toSet().length, 5);
      expect(kwaliteitKleur(1), const Color(0xFFE53935));
      expect(kwaliteitKleur(5), const Color(0xFF2E7D32));
    });
  });

  group('Flow is 4 stappen met kwaliteit (structuur)', () {
    test('stapteller en klaar-stap rekenen met 4', () {
      final code = _code('lib/screens/morning_checkin_screen.dart');
      expect(code.contains('ochtendStapVan(_step + 1, 4)'), isTrue);
      expect(code.contains('_step = 4'), isTrue);
      expect(code.contains('(_step + 1) / 4'), isTrue);
    });

    test('kwaliteit wordt gevraagd, bewaard en getoond', () {
      final code = _code('lib/screens/morning_checkin_screen.dart');
      expect(code.contains('ochtendHoeGeslapen'), isTrue);
      expect(code.contains("log['sleep_quality']"), isTrue,
          reason: 'merge-preserving in daily_log bewaren');
      expect(code.contains('_opgeslagenKwaliteit'), isTrue);
      expect(code.contains('_KwaliteitOpties('), isTrue);
    });

    test('zonder kwaliteit geen afronding', () {
      final code = _code('lib/screens/morning_checkin_screen.dart');
      expect(code.contains('_kwaliteit == null'), isTrue);
    });

    test('q4-kaart gebruikt de scorekleur, niet het actie-accent', () {
      final code = _code('lib/screens/morning_checkin_screen.dart');
      expect(code.contains('slaapbehoefteColor(option.score'), isTrue);
      expect(code.contains('tekstOp(vulling)'), isTrue,
          reason: 'badgetekst op de (zo nodig verdiepte) vulling');
    });

    test('overzicht toont kwaliteit en kleurt antwoorden', () {
      final code = _code('lib/screens/morning_checkin_screen.dart');
      expect(code.contains('kwaliteitLabel('), isTrue);
      expect(code.contains('accent:'), isTrue,
          reason: 'OverzichtRij kleurt het antwoord mee');
    });
  });
}
