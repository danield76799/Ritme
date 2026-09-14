// Regressietest voor kapotte NL-placeholders (09-2026).
//
// 16 Nederlandse strings gebruikten `$var` (Dart-stijl) in plaats van
// `{var}` (ARB-stijl). gen-l10n zet `$` om naar letterlijke tekst, waardoor
// gebruikers "$count ingepland, $rescheduled in DB" te zien kregen in
// plaats van de echte getallen — precies de getallen die nodig zijn om een
// notificatieprobleem te diagnosticeren. Elf keys gebruikten bovendien een
// andere naam dan de EN-template ($e i.p.v. {error} etc.).
//
// Deze test faalt zodra er weer een `$var` in intl_nl.arb sluipt of een
// `{var}` niet in de EN-template bestaat.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String naam) => json.decode(
      File('lib/l10n/$naam').readAsStringSync(),
    ) as Map<String, dynamic>;

void main() {
  group('NL-placeholders zijn geldig ARB', () {
    test('geen dollar-var meer in intl_nl.arb', () {
      final nl = _arb('intl_nl.arb');
      final gevonden = <String>[];
      for (final entry in nl.entries) {
        if (entry.key.startsWith('@') || entry.value is! String) continue;
        final vars =
            RegExp(r'\$(\w+)').allMatches(entry.value as String).toList();
        if (vars.isNotEmpty) gevonden.add(entry.key);
      }
      expect(gevonden, isEmpty,
          reason: 'gebruik accolades: ${gevonden.join(', ')}');
    });

    test('elke NL-{var} bestaat in de EN-template', () {
      final nl = _arb('intl_nl.arb');
      final en = _arb('intl_en.arb');
      final fouten = <String>[];
      for (final entry in nl.entries) {
        if (entry.key.startsWith('@') || entry.value is! String) continue;
        final enTekst = en[entry.key];
        if (enTekst is! String) continue;
        final enVars = RegExp(r'\{(\w+)\}')
            .allMatches(enTekst)
            .map((m) => m.group(1))
            .toSet();
        for (final m
            in RegExp(r'\{(\w+)\}').allMatches(entry.value as String)) {
          if (!enVars.contains(m.group(1))) {
            fouten.add('${entry.key}: {${m.group(1)}}');
          }
        }
      }
      expect(fouten, isEmpty,
          reason: 'onbekende placeholders: ${fouten.join(', ')}');
    });

    test('de herplan-melding toont beide getallen', () {
      final nl = _arb('intl_nl.arb');
      final tekst = nl['herinneringenHerplantDbIngepland'] as String;
      expect(tekst.contains('{rescheduled}'), isTrue);
      expect(tekst.contains('{count}'), isTrue);
    });
  });
}
