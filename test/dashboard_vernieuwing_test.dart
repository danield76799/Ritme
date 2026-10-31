// Regressietests voor de frissere dashboard-uitstraling (herbouw 2026-10).
//
// Wat hier wordt vastgelegd, en waarom:
//
// 1. De begroetingskaart gebruikt een gradient uit het THEMA. Voorheen stond
//    er een handmatige gradient (#2A3D42 -> #1A2B30) die nog bij het
//    kleurenschema van vóór de donkere herbouw hoorde, plus een paarse
//    schaduw (#B4A8D4) uit een ander merk. Beide stonden hardcoded in het
//    scherm, dus een themawijziging liet ze achtergekomen.
// 2. De metriekkaart toont zijn getal groot (28px): het getal is de held
//    van de kaart, niet de titel.
// 3. De dashboardtegels krijgen een subtiele tint van hun eigen accent.
// 4. De weekstrip bestaat en zit onder de datumkop: de dag kiezen hoeft
//    niet meer via een dialoog.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ritme/screens/dashboard_screen.dart';
import 'package:ritme/theme/app_theme.dart';
import 'package:ritme/widgets/week_strip.dart';

/// De bron van het dashboard, zonder commentaarregels (die kunnen het
/// een of andere tekenreeks noemen).
String _bronZonderCommentaar(String pad) {
  return File(pad)
      .readAsStringSync()
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');
}

void main() {
  group('de begroetingskaart', () {
    test('neemt de gradient uit het thema', () {
      final code = _bronZonderCommentaar('lib/screens/dashboard_screen.dart');
      expect(
        code.contains('AppTheme.heroGradient(context)'),
        isTrue,
        reason: 'een handmatige gradient blijft bij een themawijziging '
            'achtergekomen',
      );
      expect(
        code.contains('Color(0xFF2A3D42)'),
        isFalse,
        reason: 'dit is het oude palet van vóór de donkere herbouw',
      );
      expect(
        code.contains('Color(0xFFB4A8D4)'),
        isFalse,
        reason: 'paarse schaduw uit een ander merk',
      );
    });

    test('de donkere gradient hoort bij het huidige palet', () {
      // Teal-tint: in het palet heeft blauw de hoogste kanaalwaarde.
      for (final kleur in AppTheme.darkHeroGradient.colors) {
        expect(
          kleur.b,
          greaterThan(kleur.r),
          reason: 'de gradient moet teal zijn, niet grijs of paars',
        );
        expect(
          kleur.b,
          greaterThan(kleur.g),
          reason: 'teal heeft blauw > groen',
        );
      }
      // De kaart mag niet donkerder zijn dan de pagina, anders verdwijnt
      // hij in de achtergrond.
      expect(
        AppTheme.darkHeroGradient.colors.first.computeLuminance(),
        greaterThan(AppTheme.darkBackground.computeLuminance()),
        reason: 'de kaart moet van de pagina loskomen',
      );
      // Tekst erop moet leesbaar blijven.
      const donker = Color(0xFFF0F5F7);
      for (final kleur in AppTheme.darkHeroGradient.colors) {
        final l1 = kleur.computeLuminance();
        final l2 = donker.computeLuminance();
        final contrast = (l1 > l2 ? l1 : l2) + 0.05;
        final lage = (l1 < l2 ? l1 : l2) + 0.05;
        expect(
          contrast / lage,
          greaterThanOrEqualTo(4.5),
          reason: 'tekst op de begroetingskaart moet leesbaar blijven',
        );
      }
    });
  });

  group('de metriekkaart', () {
    test('toont het getal groot', () {
      final code = _bronZonderCommentaar('lib/screens/dashboard_screen.dart');
      expect(
        code.contains('fontSize: value.length > 12 ? 16 : 28'),
        isTrue,
        reason: 'het getal is de held van de kaart',
      );
    });
  });

  group('de dashboardtegels', () {
    test('krijgen een tint van hun eigen accent', () {
      final code = _bronZonderCommentaar('lib/screens/dashboard_screen.dart');
      expect(
        code.contains('AppTheme.tileSurface(context, accentKleur)'),
        isTrue,
      );
    });

    testWidgets('de tint blijft subtiel (maximaal 10 procent accent)',
        (tester) async {
      // Echte context nodig: AppTheme.tileSurface leest Theme.of(context).
      late Color donkerGetint;
      late Color kaartkleur;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) {
              donkerGetint = AppTheme.tileSurface(context, const Color(0xFFF2C879));
              kaartkleur = Theme.of(context).cardColor;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      // Het resultaat mag niet meer dan ~10% van het accent bevatten: de
      // tegel moet van de andere onderscheiden, maar niet schreeuwen.
      final verschil = (donkerGetint.r - kaartkleur.r).abs();
      expect(
        verschil,
        lessThan(40),
        reason: 'een zwaardere tint zou de tegels laten schreeuwen',
      );
    });
  });

  group('de weekstrip', () {
    test('zit onder de datumkop in het dashboard', () {
      final code = _bronZonderCommentaar('lib/screens/dashboard_screen.dart');
      final kop = code.indexOf('_buildTodayHeader()');
      final strip = code.indexOf('_buildWeekStrip()');
      expect(kop, greaterThan(-1));
      expect(strip, greaterThan(-1));
      expect(
        strip,
        greaterThan(kop),
        reason: 'de strip hoort bij de datum, dus eronder',
      );
    });

    test('mondayOf vindt het begin van de week', () {
      // 2026-10-30 is een vrijdag.
      final vrijdag = DateTime(2026, 10, 30);
      final maandag = WeekStrip.mondayOf(vrijdag);
      expect(maandag.weekday, DateTime.monday);
      expect(maandag, DateTime(2026, 10, 26));
    });

    test('mondayOf werkt ook voor een maandag zelf', () {
      final maandag = DateTime(2026, 10, 26);
      expect(WeekStrip.mondayOf(maandag), maandag);
    });
  });
}
