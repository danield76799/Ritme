import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/generated/l10n/app_localizations.dart';
import 'package:ritme/screens/mood_assessment_screen.dart';

void main() {
  testWidgets('Result step buttons pop with true', (tester) async {
    bool popped = false;
    bool? popResult;
    late BuildContext hostCtx;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('nl'),
      home: Builder(builder: (ctx) {
        hostCtx = ctx;
        return TextButton(
          onPressed: () async {
            popResult = await Navigator.push<bool>(
              ctx,
              MaterialPageRoute(builder: (_) => const MoodAssessmentScreen()),
            );
            popped = true;
          },
          child: const Text('open'),
        );
      }),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Vraag 1
    await tester.tap(find.text('Stabiel/Neutraal').last);
    await tester.pump();
    await tester.tap(find.text('Volgende'));
    await tester.pumpAndSettle();
    // Vraag 2 (slider default)
    await tester.tap(find.text('Volgende'));
    await tester.pumpAndSettle();
    // Vraag 3
    await tester.tap(find.text('Meer energie dan normaal').last);
    await tester.pump();
    await tester.tap(find.text('Volgende'));
    await tester.pumpAndSettle();
    // Vraag 4
    await tester.tap(find.text('Helemaal geen behoefte aan slaap').last);
    await tester.pump();
    await tester.tap(find.text('Volgende'));
    await tester.pumpAndSettle();
    // Vraag 5
    await tester.ensureVisible(find.text('Neutraal').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neutraal').last);
    await tester.pump();
    await tester.tap(find.text('Afronden'));
    await tester.pumpAndSettle();
    // Resultaat-stap verschijnt DIRECT (opslaan op achtergrond)
    expect(find.text('Stemming berekend'), findsOneWidget);
    // Opslaan & sluiten
    await tester.tap(find.text('Opslaan & sluiten'));
    await tester.pumpAndSettle();
    expect(popped, true, reason: 'Navigator.pop(true) vond niet plaats');
    expect(popResult, true);
  });
}