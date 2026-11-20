// Regressietest: een soft-deleted medicatie blijft zichtbaar in de lijst
// (als grijze "Gestopt"-kaart, alleen-lezen) zodat de historie van
// ingenomen dagen niet uit het zicht verdwijnt.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

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

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('ritme_gestopt_test');
    Hive.init(dir.path);
    for (final naam in _boxen) {
      if (!Hive.isBoxOpen(naam)) await Hive.openBox(naam);
    }
    setDbForTesting(HiveDatabaseHelper.instance);
  });

  setUp(() async {
    for (final naam in ['medication_config', 'medication_intake', 'medication_schedule']) {
      await Hive.box(naam).clear();
    }
    // Een verdwenen medicatie: eerst toevoegen (met inname vandaag),
    // dan verwijderen -> moet als 'gestopt' zichtbaar blijven.
    final db = HiveDatabaseHelper.instance;
    final id = await db.insertMedicationConfig('Oudepil', '5', 'mg', reminderEnabled: false);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await db.insertMedicationIntake(today, id, 1);
    await db.deleteMedicationConfig(id);
  });

  testWidgets('gestopte medicatie blijft zichtbaar met inname-status', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('nl'),
      theme: AppTheme.lightTheme,
      home: const MedicationScreen(),
    ));
    await tester.pumpAndSettle();

    // De gestopte medicatie staat er nog, als grijze kaart met status.
    expect(find.text('Oudepil'), findsOneWidget);
    expect(find.textContaining('Gestopt'), findsWidgets);
    expect(find.text('Genomen'), findsOneWidget);
  });

  testWidgets('heractiveren zet een gestopte medicatie terug als actief', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('nl'),
      theme: AppTheme.lightTheme,
      home: const MedicationScreen(),
    ));
    await tester.pumpAndSettle();

    // Staat in de Gestopt-sectie
    expect(find.text('Oudepil'), findsOneWidget);
    expect(find.textContaining('Gestopt'), findsWidgets);

    // Tik op Heractiveer
    await tester.tap(find.widgetWithText(TextButton, 'Heractiveer'));
    await tester.pump(); // start de DB-operatie
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    // Terug in de actieve lijst (niet meer in Gestopt)
    expect(find.text('Heractiveer'), findsNothing);
    expect(find.text('Oudepil'), findsOneWidget);

    // Database: niet meer soft-deleted
    final configs = await tester.runAsync(
        () => HiveDatabaseHelper.instance.getMedicationConfigs());
    expect(configs!.any((c) => c['naam'] == 'Oudepil'), isTrue);
  });
}
