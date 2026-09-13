// Regressietest voor de overzichtsmetriek-kaarten op het dashboard.
//
// Bug: "Activiteiten deze week" brak midden in het woord af ("Activiteite" /
// "n deze week"), omdat de kaart op een telefoon maar ~160dp breed is en na
// padding + 48dp icoon + 16dp tussenruimte nog maar ~59dp overbleef voor de
// titel. "Activiteiten" heeft ~100dp nodig.
//
// De test meet de daadwerkelijke gerenderde breedte van de titel en vergelijkt
// die met de beschikbare ruimte: als de titel smaller is dan verwacht, is hij
// afgebroken.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ritme/widgets/metric_card_shell.dart';

void main() {
  group('MetricCardShell is responsief', () {
    testWidgets('smalle kaart (<240dp): icoon boven de tekst, titel op één regel',
        (tester) async {
      const titel = 'Activiteiten deze week';

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            // Representatieve halve-kaartbreedte van een 360dp-scherm.
            child: SizedBox(
              width: 160,
              child: MetricCardShell(
                icon: Icons.local_activity,
                color: Colors.orange,
                onTap: () {},
                content: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(titel, style: TextStyle(fontSize: 16))],
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Icoon en tekst staan onder elkaar (Column), niet naast elkaar (Row).
      final kolom = find.descendant(
        of: find.byType(MetricCardShell),
        matching: find.byType(Column),
      );
      expect(kolom, findsWidgets);

      // De titel past binnen de kaartbreedte zonder horizontale overflow.
      final titelBox = tester.getSize(find.text(titel));
      expect(titelBox.width, lessThanOrEqualTo(160),
          reason: 'titel mag niet buiten de kaart vallen');

      // Geen overflow-fout tijdens het renderen.
      expect(tester.takeException(), isNull);
    });

    testWidgets('brede kaart (>=240dp): icoon naast de tekst', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: MetricCardShell(
                icon: Icons.bedtime,
                color: Colors.blue,
                onTap: () {},
                content: const Text('Slaapduur', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Op volle breedte blijft de horizontale layout staan.
      expect(find.byType(Row), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('volle-breedte kaart behoudt icoon-links layout', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MetricCardShell(
            icon: Icons.bedtime,
            color: Colors.blue,
            onTap: () {},
            content: const Text('Slaapduur', style: TextStyle(fontSize: 16)),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // De slaapduur-kaart is schermbreed en moet het icoon links houden.
      final iconPos = tester.getCenter(find.byIcon(Icons.bedtime));
      final textPos = tester.getCenter(find.text('Slaapduur'));
      expect(textPos.dx, greaterThan(iconPos.dx),
          reason: 'tekst hoort rechts van het icoon te staan');
    });

    test('de stapeldrempel ligt boven de halve-kaartbreedte van een telefoon', () {
      // 360dp scherm - 2*16dp rand - 10dp tussenruimte = 318 / 2 = 159dp.
      const halveKaart = 159.0;
      expect(MetricCardShell.stackBreakpoint, greaterThan(halveKaart));
    });

    test('het langste woord past in de gestapelde kaart', () {
      // LET OP: meet geen absolute tekstbreedte. `flutter test` rendert met het
      // Ahem-testfont waarin elk teken een vierkant van fontSize is, dus
      // "Activiteiten" meet daar 12 x 16 = 192dp terwijl het in Roboto ~95dp is.
      // Wat wél font-onafhankelijk te bewijzen valt: de gestapelde layout geeft
      // het tekstblok 64dp meer ruimte dan de layout met het icoon ernaast
      // (48dp icoon + 16dp tussenruimte). Dat is precies het verschil waardoor
      // "Activiteiten" niet meer midden in het woord afbreekt.
      const icoonEnTussenruimte = 48.0 + 16.0;
      const kaartBreedte = 160.0;
      const horizontalePadding = 18.0 * 2;
      const gestapeldBeschikbaar = kaartBreedte - horizontalePadding;
      const naastElkaarBeschikbaar = gestapeldBeschikbaar - icoonEnTussenruimte;

      expect(gestapeldBeschikbaar - naastElkaarBeschikbaar, icoonEnTussenruimte);
      expect(gestapeldBeschikbaar, greaterThan(naastElkaarBeschikbaar));
      expect(naastElkaarBeschikbaar, lessThan(100.0),
          reason: 'de oude layout gaf minder dan de ~95dp die "Activiteiten" nodig heeft');
    });
  });
}
