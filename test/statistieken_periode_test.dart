// Regressietests voor het scherm Statistieken (Life Chart).
//
// Bug 1 - slaapgrafiek: de balken werden compact geteld (dataCount), maar de
// datumlabels onder de balkjes kwamen uit _logs[index]. Zodra er dagen
// zonder slaapdata tussen zaten, schoven de datums naar voren en toonde elke
// balk de verkeerde dag.
//
// Bug 2 - PDF-periode: de periode in het rapport stond omgekeerd (nieuw ->
// oud) en de tabel toonde de 14 OUDSTE dagen in plaats van de 14 meest
// recente. Het rapport moest altijd over de volle historie gaan, los van de
// periode die op het scherm gekozen is.
//
// Bug 3 - geen periodekiezer: met jaren aan historie werd de grafiek
// onleesbaar. Het scherm moest 7/14/30 dagen + 'alle' kunnen tonen.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ritme/generated/l10n/app_localizations.dart';
import 'package:ritme/screens/statistics_screen.dart';

void main() {
  group('Statistieken: periode en datums', () {
    testWidgets('scherm biedt 7/14/30 dagen en "alle" aan', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StatistiekenScherm(),
        ),
      );
      await tester.pump();

      // De periodekiezer is een SegmentedButton met vier segmenten.
      final segmented = find.byType(SegmentedButton<int>);
      expect(segmented, findsOneWidget);

      final button = tester.widget<SegmentedButton<int>>(segmented);
      final waarden = button.segments.map((s) => s.value).toList();
      expect(waarden, containsAll(<int>[7, 14, 30, 0]));
    });

    testWidgets('slaapgrafijk gebruikt barDatums voor de labels', (tester) async {
      // Broncode-assertie: de datumlabels van de slaapgrafiek moeten uit de
      // aparte barDatums-lijst komen, niet uit _logs[index]. Anders schuiven
      // de datums op zodra er dagen zonder slaapdata zijn.
      final bron = File(
        'lib/screens/statistics_screen.dart',
      ).readAsStringSync();

      expect(
        bron,
        contains('final List<String> barDatums = [];'),
        reason: 'De slaapgrafiek moet een aparte lijst met datumlabels bijhouden',
      );
      expect(
        bron,
        contains('if (index >= 0 && index < barDatums.length) {'),
        reason:
            'De x-as-labels van de slaapgrafiek moeten uit barDatums komen, '
            'niet uit _logs (anders kloppen de datums niet bij ontbrekende '
            'slaapdata)',
      );
    });

    testWidgets('PDF gebruikt de volle historie, niet de gekozen periode',
        (tester) async {
      final bron = File(
        'lib/screens/statistics_screen.dart',
      ).readAsStringSync();

      expect(
        bron,
        contains('final rapportLogs = _alleLogs;'),
        reason:
            'De PDF-export moet over de volle historie gaan, ongeacht de '
            'gekozen periode op het scherm',
      );
      expect(
        bron,
        contains('dateStart = rapportLogs.first'),
        reason: 'De periode in het rapport loopt van oud naar nieuw',
      );
      expect(
        bron,
        contains('dateEnd = rapportLogs.last'),
        reason: 'De periode in het rapport loopt van oud naar nieuw',
      );
      expect(
        bron,
        contains('.reversed.take(14).toList().reversed'),
        reason:
            'De PDF-tabel toont de 14 meest recente dagen, oplopend gesorteerd',
      );
    });
  });
}
