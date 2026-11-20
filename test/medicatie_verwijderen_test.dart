// Regressietest: de stopknop op het medicatiescherm stopt een medicijn
// (soft-stop), zonder de inname-historie te wissen.
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

  testWidgets('medicatie stoppen via het scherm', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('nl'),
      theme: AppTheme.lightTheme,
      home: const MedicationScreen(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Testpil'), findsOneWidget);

    // Tik op de stopknop (stop-icoon).
    await tester.tap(find.byIcon(Icons.stop_circle_outlined));
    await tester.pumpAndSettle();

    // Bevestigingsdialoog.
    expect(find.text('Medicatie stoppen?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Stoppen'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    // SnackBar bevestigt het stoppen.
    expect(find.textContaining('is gestopt'), findsOneWidget);

    // De kaart verhuist naar de sectie 'Gestopt' (alleen-lezen).
    expect(find.textContaining('Gestopt'), findsWidgets);
    expect(find.text('Testpil'), findsOneWidget);

    // En is gemarkeerd als gestopt (deleted + stopped_at), NIET hard verwijderd.
    final configs = await tester.runAsync(
        () => HiveDatabaseHelper.instance.getMedicationConfigsAll());
    expect(configs!.length, 1);
    expect(configs.single['deleted'], anyOf(equals('1'), equals(1)));
    expect(configs.single['stopped_at'], isNotNull);
  });
}
