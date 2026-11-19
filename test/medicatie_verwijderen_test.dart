// Regressietest: de verwijderknop op het medicatiescherm moet een
// medicatie echt verwijderen (en eerst een bevestigingsdialoog tonen).
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

Future<void> _leeg() async {
  for (final naam in ['medication_config', 'medication_intake', 'medication_schedule']) {
    await Hive.box(naam).clear();
  }
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('ritme_medicatie_test');
    Hive.init(tempDir.path);
    for (final naam in _boxen) {
      if (!Hive.isBoxOpen(naam)) await Hive.openBox(naam);
    }
    setDbForTesting(HiveDatabaseHelper.instance);
  });

  setUp(() async {
    await _leeg();
    await HiveDatabaseHelper.instance.insertMedicationConfig(
      'Testpil', '100', 'mg', reminderEnabled: false);
  });

  testWidgets('medicatie verwijderen via het scherm', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('nl'),
      theme: AppTheme.lightTheme,
      home: const MedicationScreen(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Testpil'), findsOneWidget);

    // Tik op de prullenbak.
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    // Bevestigingsdialoog met de naam van de medicatie.
    expect(find.text('Medicatie verwijderen?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verwijderen'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    // SnackBar bevestigt de verwijdering.
    expect(find.text('Medicijn verwijderd'), findsOneWidget);

    // Verdwijnt niet spoorloos: de kaart verhuist naar de sectie 'Gestopt'
    // (alleen-lezen), zodat de historie zichtbaar blijft.
    expect(find.text('Gestopt'), findsWidgets);
    expect(find.text('Testpil'), findsOneWidget);

    // En gemarkeerd als verwijderd in de database (soft-delete, historie bewaard).
    final configs = await tester.runAsync(
        () => HiveDatabaseHelper.instance.getMedicationConfigsAll());
    expect(configs!.length, 1);
    expect(configs.single['deleted'], anyOf(equals('1'), equals(1)));
  });
}
