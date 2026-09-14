// Regressietest voor release-only R8/Gson-breuk (09-2026).
//
// Symptoom op het toestel (release-build): elke cancel() en elk uitlezen
// van geplande meldingen gooide
//   PlatformException(error, Missing type parameter ...)
//   at com.google.gson.reflect.TypeToken.<init>
//   at ...FlutterLocalNotificationsPlugin.loadScheduledNotifications
// met als gevolg "3 in DB, 0 ingepland" en geen enkele herinnering.
// Debug-builds hebben geen minify en tonen dit nooit — daarom een
// structuurtest: de ProGuard-keeps die R8 hiervan afhouden mogen nooit
// stilletjes verdwijnen.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Release-keeps voor de notificatieplugin', () {
    test('proguard bewaart plugin-klassen en Gson TypeToken', () {
      final regels =
          File('android/app/proguard-rules.pro').readAsStringSync();
      expect(
        regels.contains(
            '-keep class com.dexterous.flutterlocalnotifications.**'),
        isTrue,
        reason: 'zonder deze keep stript R8 de plugin-modellen',
      );
      expect(
        regels.contains('-keep class com.google.gson.reflect.TypeToken'),
        isTrue,
        reason: 'zonder deze keep faalt elke scheduled-cache read',
      );
      expect(
        regels.contains(
            '-keep class * extends com.google.gson.reflect.TypeToken'),
        isTrue,
        reason: 'anonieme TypeToken-subklasse verliest zijn signature',
      );
    });

    test('release-build shrinkt echt (de test is anders loos)', () {
      final gradle =
          File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle.contains('isMinifyEnabled = true'), isTrue,
          reason: 'zonder minify is er geen R8-risico om tegen te waken');
    });
  });
}
