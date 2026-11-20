// Regressietest: toevoegen van een medicijn met een naam die al bestaat
// mag geen stille dubbele kaart maken. De gebruiker krijgt een keuze:
// bestaande openen / herstarten, of toch apart toevoegen.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:ritme/database/hive_database_helper.dart';
import 'package:ritme/generated/l10n/app_localizations.dart';
import 'package:ritme/screens/medication_screen.dart';
import 'package:ritme/service_locator.dart';
import 'package:ritme/theme/app_theme.dart';

const _boxen = [
  'settings', 'daily_logs', 'srm_activities', 'mood_assessment',
  'medication_config', 'medication_intake', 'medication_schedule',
  'life_events', 'weight_logs', 'medical_appointments', 'crisis_plan',
  'prodromal_checklist', 'prodromal_logs', 'episode_logs', 'daily_dagboek',
];


Future<void> _typeIntoField(WidgetTester tester, Finder field, String value) async {
  // Direct call to onChanged instead of IME simulation: deterministic in tests.
  final widget = tester.widget<TextField>(field);
  widget.onChanged?.call(value);
  await tester.pump();
}

Widget _app() => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('nl'),
      theme: AppTheme.lightTheme,
      home: const MedicationScreen(),
    );

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('ritme_duplicaat_test');
    Hive.init(tempDir.path);
    for (final naam in _boxen) {
      if (!Hive.isBoxOpen(naam)) await Hive.openBox(naam);
    }
    setDbForTesting(HiveDatabaseHelper.instance);
  });

  setUp(() async {
    for (final naam in ['medication_config', 'medication_intake', 'medication_schedule']) {
      await Hive.box(naam).clear();
    }
    await HiveDatabaseHelper.instance.insertMedicationConfig(
        'Oudepil', '100', 'mg', reminderEnabled: false);
  });

  testWidgets('dubbele naam bij toevoegen vraagt om bevestiging', (tester) async {
    await _pump(tester);

    // Open het toevoeg-scherm en typ dezelfde naam (ander hoofdlettergebruik).
    await tester.tap(find.byTooltip('Nieuwe Medicatie'));
    await tester.pumpAndSettle();
    await _typeIntoField(tester, find.byType(TextField).first, ' OUDEPIL ');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Opslaan'));
    await tester.pumpAndSettle();

    // Waarschuwing verschijnt i.p.v. stil een dubbele kaart te maken.
    expect(find.textContaining('staat al in je lijst'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Bestaande bewerken'), findsOneWidget);

    // 'Toch apart toevoegen' maakt een tweede kaart (expliciete keuze).
    await tester.tap(find.text('Toch apart toevoegen'));
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('Oudepil'), findsOneWidget);
    expect(find.text('OUDEPIL'), findsOneWidget);
  });

}
