// Regressietest: geen hardcoded Nederlandse gebruikersteksten meer in de
// schermen.
//
// De app is tweetalig (nl + en). Teksten die rechtstreeks in de Dart-code
// staan, blijven altijd Nederlands, ook als de gebruiker de Engelse taal
// kiest. Vooral het onboarding-scherm was een probleem: de hele flow stond
// in het Nederlands.
//
// De test scant de schermen op de bekende Nederlandse fragmenten en faalt
// zodra er weer een hardcoded tekst bijkomt.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Fragmenten die in de schermen hardcoded stonden.
  final verboden = <String>[
    'Welkom bij Ritme',
    'Ochtend & avond check-in',
    'Crisisplan binnen handbereik',
    'Overslaan',
    'Aan de slag',
    'Voeg je eerste meting toe',
    'Geen voortekenen geregistreerd',
    'Test automatische backup',
  ];

  test('schermen bevatten geen hardcoded Nederlandse gebruikersteksten', () {
    final schermen = Directory('lib/screens')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    expect(schermen, isNotEmpty, reason: 'geen schermen gevonden');

    final treffers = <String>[];
    for (final scherm in schermen) {
      final inhoud = scherm.readAsStringSync();
      for (final fragment in verboden) {
        if (inhoud.contains(fragment)) {
          treffers.add('${scherm.path}: "$fragment"');
        }
      }
    }

    expect(
      treffers,
      isEmpty,
      reason:
          'Deze teksten staan hardcoded in de code en blijven dus altijd '
          'Nederlands. Zet ze in lib/l10n/intl_nl.arb en intl_en.arb en '
          'gebruik AppLocalizations.of(context).\n${treffers.join('\n')}',
    );
  });

  test('schermen gebruiken geen isDutch-schakelaar meer', () {
    // Een `isDutch ? '…' : '…'`-blok negeert de taalinstelling van de app:
    // alleen Nederlands en Engels bestaan, en de tekst staat buiten de
    // arb-bestanden. Alle schermen gebruiken AppLocalizations.
    final schermen = Directory('lib/screens')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    final treffers = <String>[];
    for (final scherm in schermen) {
      final inhoud = scherm.readAsStringSync();
      if (inhoud.contains('isDutch ?')) {
        treffers.add(scherm.path);
      }
    }

    expect(
      treffers,
      isEmpty,
      reason:
          'Deze schermen kiezen zelf tussen NL en EN in plaats van de '
          'taalinstelling van de app te volgen. Zet de teksten in '
          'lib/l10n/intl_nl.arb en intl_en.arb.\n${treffers.join('\n')}',
    );
  });
}
