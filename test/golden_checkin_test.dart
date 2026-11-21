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
    final dir = await Directory.systemTemp.createTemp('ritme_golden');
    Hive.init(dir.path);
    for (final naam in _boxen) {
      if (!Hive.isBoxOpen(naam)) await Hive.openBox(naam);
    }
    setDbForTesting(HiveDatabaseHelper.instance);
  });

  testWidgets('ochtend golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(_app(const MorningCheckInScreen()));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MorningCheckInScreen), matchesGoldenFile('goldens/ochtend_pagina.png'));
  });

  testWidgets('avond golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(_app(const EveningCheckInScreen()));
    await tester.pumpAndSettle();
    await expectLater(find.byType(EveningCheckInScreen), matchesGoldenFile('goldens/avond_pagina.png'));
  });
}
