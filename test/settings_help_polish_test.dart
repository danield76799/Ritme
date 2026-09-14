// Regressietests voor de Ritme-polish (09-2026): de vier overgebleven
// reviewpunten.
//
// 1. ÉÉN OPSLAGMODEL. Het instellingenscherm had twee modellen: naam en
//    tijden via een Opslaan-knop, notificaties direct. Wie de naam wijzigde
//    en wegliep zonder op te slaan verloor hem stil. Nu wordt alles direct
//    bewaard (naam met debounce, tijden bij kiezen) en is de knop weg.
//
// 2. MINUTENKIEZER. Ging per kwartier (step: 15), waardoor 19:35 niet in te
//    stellen was. Nu per minuut. De dialoog was bovendien hard wit, ook in
//    dark mode — nu volgt hij het thema.
//
// 3. EÉN TESTKNOP. "Test notificatie" en "Test check-in melding" deden bijna
//    hetzelfde. Nu één knop die de echte check-in melding toont. "Herplan
//    herinneringen" (diagnostiek) staat onder Overige.
//
// 4. HELP VOLGT DE APP. Help had een eigen NL/EN-schakelaar (op basis van
//    Platform.localeName), waardoor Help in een andere taal kon staan dan
//    de app. Nu volgt hij de app-locale.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/generated/l10n/app_localizations.dart';
import 'package:ritme/screens/help_screen.dart';

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

Widget _metTaal(Widget kind, Locale taal) {
  return MaterialApp(
    locale: taal,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: kind,
  );
}

void main() {
  group('Eén opslagmodel in Instellingen', () {
    test('geen Opslaan-knop en geen _saveSettings meer', () {
      final code = _code('lib/screens/settings_screen.dart');
      expect(code.contains('_saveSettings'), isFalse,
          reason: 'alles wordt direct bewaard; een losse save is een tweede model');
      expect(code.contains('onPressed: _saveSettings'), isFalse);
    });

    test('gebruikersnaam wordt automatisch bewaard', () {
      final code = _code('lib/screens/settings_screen.dart');
      expect(code.contains('_usernameSaveTimer'), isTrue);
      expect(code.contains('_usernameGewijzigd'), isTrue);
      expect(code.contains('_usernameNuOpslaan'), isTrue,
          reason: 'bij Enter of wegklikken meteen bewaren, niet op de debounce wachten');
      expect(code.contains('onChanged: _usernameGewijzigd'), isTrue);
    });

    test('alle tijdvelden slaan direct op', () {
      final code = _code('lib/screens/settings_screen.dart');
      // 5 slaapschema/doel-rijen + 2 check-in-rijen geven onSaved mee.
      expect(RegExp(r'onSaved:').allMatches(code).length, greaterThanOrEqualTo(7));
      expect(code.contains('_directOpslaan'), isTrue);
    });

    test('het scherm zegt dat alles direct bewaard wordt', () {
      final code = _code('lib/screens/settings_screen.dart');
      expect(code.contains('wijzigingenDirectOpgeslagen'), isTrue);
    });
  });

  group('Minutenkiezer en dialoog', () {
    test('minuten per één, niet per kwartier', () {
      final code = _code('lib/screens/settings_screen.dart');
      expect(code.contains('step: 15'), isFalse,
          reason: 'tijden als 19:35 moeten in te stellen zijn');
    });

    test('dialoog volgt het thema (geen hard wit)', () {
      final code = _code('lib/screens/settings_screen.dart');
      expect(code.contains('backgroundColor: Colors.white'), isFalse);
      expect(code.contains('colorScheme.surface'), isTrue);
    });
  });

  group('Eén testknop, herplannen onder Overige', () {
    test('nog maar één testknop, met de echte melding', () {
      final code = _code('lib/screens/settings_screen.dart');
      expect(code.contains('testNotificatieNu'), isFalse);
      expect(code.contains('testCheckinNotificatie'), isFalse);
      expect(
        RegExp(r'testMeldingVersturen').allMatches(code).length,
        1,
        reason: 'precies één testknop',
      );
      expect(code.contains('showCheckinPreview'), isTrue,
          reason: 'de knop toont de echte check-in melding');
    });

    test('herplannen staat onder Overige, niet bij Notificaties', () {
      final code = _code('lib/screens/settings_screen.dart');
      final herplan = code.indexOf('herplanMedicatieHerinneringen');
      final overige = code.indexOf('.overige');
      expect(herplan, greaterThan(-1));
      expect(overige, greaterThan(-1));
      expect(herplan, greaterThan(overige),
          reason: 'diagnostiek hoort bij Overige');
      // De notificatiesectie houdt alleen de herinneringen + testknop over.
      final notificaties = code.indexOf('_buildCheckinReminders()');
      final testknop = code.indexOf('testMeldingVersturen');
      expect(testknop, greaterThan(notificaties));
      expect(herplan, greaterThan(testknop));
    });
  });

  group('Help volgt de app-taal', () {
    test('geen eigen taalschakelaar meer (structuur)', () {
      final code = _code('lib/screens/help_screen.dart');
      expect(code.contains('_toggleLanguage'), isFalse);
      expect(code.contains('Platform.localeName'), isFalse);
      expect(code.contains('dart:io'), isFalse);
      expect(code.contains('localeOf(context)'), isTrue);
    });

    testWidgets('Nederlandse app toont Nederlandse help', (tester) async {
      await tester.pumpWidget(_metTaal(const HelpScreen(), const Locale('nl')));
      await tester.pumpAndSettle();
      expect(find.text('Gebruiksaanwijzing'), findsOneWidget);
      expect(find.text('Stemming bijhouden'), findsOneWidget);
    });

    testWidgets('Engelse app toont Engelse help', (tester) async {
      await tester.pumpWidget(_metTaal(const HelpScreen(), const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.text('User Guide'), findsOneWidget);
      expect(find.text('Track Mood'), findsOneWidget);
    });
  });
}
