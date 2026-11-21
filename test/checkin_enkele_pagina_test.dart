// De ochtend/avond check-in is nu één scrollbare pagina i.p.v. een wizard.
// Deze tests bewaken die vorm: alles staat er, en "Afronden" zonder de
// verplichte vragen toont een fout i.p.v. op te slaan.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:ritme/database/hive_database_helper.dart';
import 'package:ritme/generated/l10n/app_localizations.dart';
import 'package:ritme/screens/evening_checkin_screen.dart';
import 'package:ritme/screens/morning_checkin_screen.dart';
import 'package:ritme/service_locator.dart';
import 'package:ritme/theme/app_theme.dart';

const _boxen = [
  'settings', 'daily_logs', 'srm_activities', 'mood_assessment',
  'medication_config', 'medication_intake', 'medication_schedule',
  'life_events', 'weight_logs', 'medical_appointments', 'crisis_plan',
  'prodromal_checklist', 'prodromal_logs', 'episode_logs', 'daily_dagboek',
];

Widget _app(Widget screen) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('nl'),
      theme: AppTheme.lightTheme,
      home: screen,
    );

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('ritme_checkin_test');
    Hive.init(dir.path);
    for (final naam in _boxen) {
      if (!Hive.isBoxOpen(naam)) await Hive.openBox(naam);
    }
    setDbForTesting(HiveDatabaseHelper.instance);
  });

  setUp(() async {
    for (final naam in ['daily_logs', 'mood_assessment', 'srm_activities', 'mood_activities']) {
      if (Hive.isBoxOpen(naam)) await Hive.box(naam).clear();
    }
  });

  testWidgets('ochtend: alle secties op één pagina, geen stap-wizard', (tester) async {
    await tester.pumpWidget(_app(const MorningCheckInScreen()));
    await tester.pumpAndSettle();

    // Alle vragen tegelijk zichtbaar op één pagina (gescrolld is prima,
    // maar er mag geen "Volgende"/"Vorige"-wizardknop zijn).
    expect(find.text('Hoe laat stond je op?'), findsOneWidget);
    expect(find.text('Hoe heb je geslapen?'), findsOneWidget);
    expect(find.text('Als je gisteren opstond of ging slapen, hoe ging het?'), findsNothing); // bestaat niet als losse stap
    expect(find.widgetWithText(ElevatedButton, 'Afronden'), findsOneWidget);
    expect(find.text('Volgende'), findsNothing);
    expect(find.text('Vorige'), findsNothing);
  });

  testWidgets('ochtend: afronden zonder verplichte vragen toont melding', (tester) async {
    await tester.pumpWidget(_app(const MorningCheckInScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Afronden'));
    await tester.pumpAndSettle();
    expect(find.text('Vul de verplichte vragen in'), findsOneWidget);
    expect(find.text('Verplicht'), findsWidgets);
  });

  testWidgets('avond: alle secties op één pagina, afronden zonder invoer geeft melding', (tester) async {
    await tester.pumpWidget(_app(const EveningCheckInScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Hoe is uw stemming vandaag?'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Afronden'), findsOneWidget);
    expect(find.text('Volgende'), findsNothing);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Afronden'));
    await tester.pumpAndSettle();
    expect(find.text('Vul de verplichte vragen in'), findsOneWidget);
  });
}
