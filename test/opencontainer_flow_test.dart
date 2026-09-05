import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/generated/l10n/app_localizations.dart';
import 'package:ritme/screens/mood_assessment_screen.dart';

void main() {
  testWidgets('OpenContainer flow: Save & close closes the container', (tester) async {
    bool popped = false;
    bool? popResult;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('nl'),
      home: OpenContainer<bool>(
        transitionType: ContainerTransitionType.fadeThrough,
        closedBuilder: (context, openContainer) => TextButton(
          onPressed: openContainer,
          child: const Text('open'),
        ),
        openBuilder: (context, closeContainer) =>
            MoodAssessmentScreen(
              onClose: (saved) => closeContainer(returnValue: saved),
            ),
        onClosed: (data) {
          popped = true;
          popResult = data;
        },
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Vraag 1
    await tester.tap(find.text('Stabiel/Neutraal').last);
    await tester.pump();
    await tester.tap(find.text('Volgende'));
    await tester.pumpAndSettle();
    // Vraag 2
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

    expect(find.text('Stemming berekend'), findsOneWidget);
    await tester.tap(find.text('Opslaan & sluiten'));
    await tester.pumpAndSettle();
    print('POPPED: $popped, RESULT: $popResult');
    print('STILL SHOWS Q SCREEN: ${find.text('Stemming berekend').evaluate().isNotEmpty}');
    expect(popped, true, reason: 'closeContainer werd niet aangeroepen');
    expect(popResult, true);
  });
}