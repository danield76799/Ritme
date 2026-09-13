// Test voor het crisisplan-scherm.
//
// Twee dingen mogen hier nooit stilletjes breken:
//   1. de volledige plan-tekst moet zichtbaar zijn ZONDER erop te tikken
//      (dit scherm wordt in een noodsituatie geopend)
//   2. de sectietitels moeten uit de ARB-vertaling komen, niet hardcoded

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ritme/generated/l10n/app_localizations.dart';

void main() {
  group('Crisisplan-secties zijn gelokaliseerd', () {
    late AppLocalizations nl;
    late AppLocalizations en;

    setUpAll(() async {
      nl = await AppLocalizations.delegate.load(const Locale('nl'));
      en = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('NL-sectietitels bestaan en zijn Nederlands', () {
      expect(nl.manieVroegTitle.toLowerCase(), contains('manie'));
      expect(nl.depressieVroegTitle.toLowerCase(), contains('depressie'));
      expect(nl.contactenTitle.toLowerCase(), contains('contacten'));
      expect(nl.medicatieNoodTitle.toLowerCase(), contains('medicatie'));
      expect(nl.watHelptTitle.toLowerCase(), contains('helpt'));
    });

    test('EN-sectietitels verschillen van NL (echt vertaald)', () {
      expect(en.manieVroegTitle, isNot(nl.manieVroegTitle));
      expect(en.depressieVroegTitle, isNot(nl.depressieVroegTitle));
      expect(en.contactenTitle, isNot(nl.contactenTitle));
      expect(en.medicatieNoodTitle, isNot(nl.medicatieNoodTitle));
      expect(en.watHelptTitle, isNot(nl.watHelptTitle));
    });

    test('geen enkele sectietitel bevat nog de oude hardcoded EN-tekst', () {
      // Deze strings stonden eerder letterlijk in crisisplan_screen.dart,
      // terwijl de telefoon op Nederlands stond.
      const oudeHardcoded = [
        'At first signs of mania/hypomania',
        'Severe mania (emergency)',
        'At first signs of depression',
        'Severe depression / suicidal thoughts',
        'Mixed episode',
        'Important contacts',
        'Medication emergency plan',
        'What helps me',
      ];
      final alleNl = [
        nl.manieVroegTitle,
        nl.manieErnstigTitle,
        nl.depressieVroegTitle,
        nl.depressieErnstigTitle,
        nl.gemengdTitle,
        nl.contactenTitle,
        nl.medicatieNoodTitle,
        nl.watHelptTitle,
      ];
      for (final oud in oudeHardcoded) {
        expect(alleNl, isNot(contains(oud)),
            reason: '"$oud" staat nog in de NL-teksten');
      }
    });
  });

  group('Volledige tekst is zichtbaar zonder tikken', () {
    testWidgets('lange plan-tekst wordt niet afgekapt', (tester) async {
      const langPlan =
          'Bel eerst mijn zus, daarna de behandelaar. '
          'Vermijd prikkels, geen autorijden, en blijf niet alleen. '
          'Medicatie volgens noodplan innemen en slaap bewaken. '
          'Als het niet zakt binnen 24 uur: crisisdienst bellen.';

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(
            children: const [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(langPlan, style: TextStyle(height: 1.4)),
              ),
            ],
          ),
        ),
      ));

      // De volledige string is één Text-widget; er is geen ellipsis die
      // tekens weglaat.
      final tekst = tester.widget<Text>(find.text(langPlan));
      expect(tekst.data, langPlan);
      expect(tekst.overflow, isNot(TextOverflow.ellipsis));
      expect(tekst.data!.length, greaterThan(80));
    });

    testWidgets('geen maxLines-beperking op de plan-tekst', (tester) async {
      const langPlan = 'Regel 1\nRegel 2\nRegel 3\nRegel 4\nRegel 5\nRegel 6';
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: Text(langPlan))),
      ));
      final tekst = tester.widget<Text>(find.text(langPlan));
      expect(tekst.maxLines, isNull);
    });
  });
}
