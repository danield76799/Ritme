// Regressietest voor AppBar-consistentie.
//
// AANLEIDING: de AppBar liep uit elkaar in drie families — 3 schermen
// transparant (dashboard, ochtend check-in, ritme-detail), 16 met een eigen
// `colorScheme.primary`-vlak, en 1 via de scaffold. In dark mode gaf dat een
// fel-lichte balk (#7AC8D3) naast bijna-zwarte schermen: 9.30:1 verschil.
//
// WAT DEZE TEST MEET: de EFFECTIEVE balkkleur zoals Flutter hem resolveert
// (widget-override ?? appBarTheme ?? colorScheme.surface) uit de GERENDERDE
// tree. Niet de broncode — een scherm dat de override terugzet moet hier
// rood worden, ook als de tekst in het bestand er onschuldig uitziet.
//
// Op de oude code: de 16 primary-schermen geven colorScheme.primary en falen.
// Op de nieuwe code: alles transparant en groen.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:ritme/database/hive_database_helper.dart';
import 'package:ritme/generated/l10n/app_localizations.dart';
import 'package:ritme/service_locator.dart';
import 'package:ritme/theme/app_theme.dart';

import 'package:ritme/screens/activities_detail_screen.dart';
import 'package:ritme/screens/activity_screen.dart';
import 'package:ritme/screens/appointments_screen.dart';
import 'package:ritme/screens/crisisplan_screen.dart';
import 'package:ritme/screens/dagboek_screen.dart';
import 'package:ritme/screens/dashboard_screen.dart';
import 'package:ritme/screens/episodes_screen.dart';
import 'package:ritme/screens/help_screen.dart';
import 'package:ritme/screens/medication_screen.dart';
import 'package:ritme/screens/mood_assessment_screen.dart';
import 'package:ritme/screens/voortekenen_screen.dart';
import 'package:ritme/screens/weight_screen.dart';

const _boxen = [
  'settings',
  'daily_logs',
  'srm_activities',
  'mood_assessment',
  'medication_config',
  'medication_intake',
  'medication_schedule',
  'life_events',
  'weight_logs',
  'medical_appointments',
  'crisis_plan',
  'prodromal_checklist',
  'prodromal_logs',
  'episode_logs',
  'daily_dagboek',
];

/// Relatieve luminantie volgens WCAG. `Color.r/g/b` zijn in deze
/// Flutter-versie al 0..1, dus geen deling door 255.
double _lum(Color c) {
  double k(double s) =>
      s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * k(c.r) + 0.7152 * k(c.g) + 0.0722 * k(c.b);
}

double _contrast(Color a, Color b) {
  final la = _lum(a);
  final lb = _lum(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// De kleur die de AppBar ECHT krijgt, met Flutter's eigen precedentie.
Color _effectieveBalkKleur(WidgetTester t, ThemeData thema) {
  final bar = t.widget<AppBar>(find.byType(AppBar).first);
  return bar.backgroundColor ??
      thema.appBarTheme.backgroundColor ??
      thema.colorScheme.surface;
}

final _schermen = <String, Widget Function()>{
  'activity': () => const ActivityScreen(),
  'appointments': () => const AppointmentsScreen(),
  'crisisplan': () => const CrisisPlanScreen(),
  'dagboek': () => const DagboekScreen(),
  'dashboard': () => const DashboardScreen(),
  'episodes': () => const EpisodesScreen(),
  'help': () => const HelpScreen(),
  'medication': () => const MedicationScreen(),
  'mood_assessment': () => const MoodAssessmentScreen(),
  'voortekenen': () => const VoortekenenScreen(),
  'weight': () => const WeightScreen(),
  'activities_detail': () => const ActivitiesDetailScreen(),
};

void main() {
  setUpAll(() async {
    Hive.init('/tmp/hive_appbar_test');
    for (final n in _boxen) {
      if (!Hive.isBoxOpen(n)) await Hive.openBox(n);
    }
    setDbForTesting(HiveDatabaseHelper.instance);
  });

  for (final mode in [Brightness.light, Brightness.dark]) {
    final label = mode == Brightness.light ? 'LIGHT' : 'DARK';
    final thema =
        mode == Brightness.light ? AppTheme.lightTheme : AppTheme.darkTheme;

    group('$label: elke AppBar volgt het thema', () {
      _schermen.forEach((naam, bouw) {
        testWidgets('$naam: balk is transparant', (t) async {
          await t.pumpWidget(MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('nl'),
            theme: thema,
            home: bouw(),
          ));
          for (var i = 0; i < 6; i++) {
            await t.pump(const Duration(milliseconds: 50));
          }
          while (t.takeException() != null) {}

          if (find.byType(AppBar).evaluate().isEmpty) {
            // geen balk op dit scherm; niets te borgen
            return;
          }
          final kleur = _effectieveBalkKleur(t, thema);
          expect(
            kleur,
            Colors.transparent,
            reason: '$naam zet een eigen balkkleur ($kleur) in plaats van het '
                'thema te volgen. Dat is precies de divergentie die is '
                'opgeruimd: 3 transparant, 16 vol teal, 1 via scaffold.',
          );
        });
      });
    });

    test('$label: de balktekst is leesbaar op de pagina-achtergrond', () {
      // De balk is transparant, dus de titel staat op de pagina-achtergrond.
      final bg = mode == Brightness.light
          ? AppTheme.backgroundColor
          : AppTheme.darkBackground;
      final fg = thema.appBarTheme.foregroundColor!;
      expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5),
          reason: 'titel/iconen op de balk halen geen 4.5:1 op de pagina');
    });

    test('$label: het thema draagt de balk, niet de schermen', () {
      expect(thema.appBarTheme.backgroundColor, Colors.transparent);
      expect(thema.appBarTheme.surfaceTintColor, Colors.transparent,
          reason: 'zonder dit legt Material 3 een paarse tint over de '
              'transparante balk zodra er onder wordt doorgescrolld');
      expect(thema.appBarTheme.scrolledUnderElevation, 0);
    });
  }

  test('de oude situatie: een primary-balk wijkt zichtbaar af van de pagina',
      () {
    // Regressiedrempel: dit is waarom de inconsistentie opviel. In dark mode
    // was het verschil tussen de teal balk en de donkere pagina 9.30:1.
    for (final mode in [Brightness.light, Brightness.dark]) {
      final thema =
          mode == Brightness.light ? AppTheme.lightTheme : AppTheme.darkTheme;
      final bg = mode == Brightness.light
          ? AppTheme.backgroundColor
          : AppTheme.darkBackground;
      final verschil = _contrast(thema.colorScheme.primary, bg);
      expect(verschil, greaterThan(4.5),
          reason: 'de oude balkkleur viel juist wel op — anders was dit geen '
              'probleem geweest');
    }
  });
}
