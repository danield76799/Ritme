// Sync-test voor de ARB-bestanden: NL en EN moeten exact dezelfde keys
// (en dezelfde placeholders) bevatten, anders crasht of wijst gen-l10n
// de app stilletjes naar fallback-teksten. Faalt zodra iemand in één
// bestand een key toevoegt of een placeholder hernoemt zonder de ander.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String naam) => json.decode(
      File('lib/l10n/$naam').readAsStringSync(),
    ) as Map<String, dynamic>;

Set<String> _berichtKeys(Map<String, dynamic> arb) => arb.keys
    .where((k) => !k.startsWith('@'))
    .toSet();

Set<String> _placeholders(String waarde) =>
    RegExp(r'\{(\w+)\}').allMatches(waarde).map((m) => m.group(1)!).toSet();

void main() {
  final nl = _arb('intl_nl.arb');
  final en = _arb('intl_en.arb');

  test('zelfde berichtkeys in NL en EN', () {
    final alleenNl = _berichtKeys(nl).difference(_berichtKeys(en));
    final alleenEn = _berichtKeys(en).difference(_berichtKeys(nl));
    expect(alleenNl, isEmpty,
        reason: 'keys alleen in NL: ${alleenNl.join(', ')}');
    expect(alleenEn, isEmpty,
        reason: 'keys alleen in EN: ${alleenEn.join(', ')}');
  });

  test('zelfde placeholders per key in NL en EN', () {
    final fouten = <String>[];
    for (final key in _berichtKeys(nl).intersection(_berichtKeys(en))) {
      final nlWaarde = nl[key];
      final enWaarde = en[key];
      if (nlWaarde is! String || enWaarde is! String) continue;
      final nlVars = _placeholders(nlWaarde);
      final enVars = _placeholders(enWaarde);
      if (nlVars.difference(enVars).isNotEmpty ||
          enVars.difference(nlVars).isNotEmpty) {
        fouten.add('$key: nl=$nlVars en=$enVars');
      }
    }
    expect(fouten, isEmpty, reason: fouten.join('\n'));
  });

  test('aangegeven @metadata-placeholders bestaan in de tekst', () {
    // gen-l10n leidt ontbrekende metadata zelf af, dus niet alle sleutels
    // hóeven @metadata te hebben. Maar als het er wél is, mag het niet
    // naar parameters verwijzen die niet in de tekst staan (stale metadata).
    final fouten = <String>[];
    for (final arb in [nl, en]) {
      for (final key in _berichtKeys(arb)) {
        final waarde = arb[key];
        if (waarde is! String) continue;
        final meta = arb['@$key'];
        if (meta is! Map) continue;
        final metaPlaceholders = meta['placeholders'];
        if (metaPlaceholders is! Map) continue;
        final vars = _placeholders(waarde);
        for (final naam in metaPlaceholders.keys.cast<String>()) {
          if (!vars.contains(naam)) {
            fouten.add('$key: @placeholder $naam staat niet in de tekst');
          }
        }
      }
    }
    expect(fouten, isEmpty, reason: fouten.join('\n'));
  });

  test('geen lege berichten', () {
    final leeg = _berichtKeys(nl)
        .where((k) => (nl[k] as String?)?.trim().isEmpty ?? true)
        .toList()
      ..addAll(_berichtKeys(en)
          .where((k) => (en[k] as String?)?.trim().isEmpty ?? true)
          .toList());
    expect(leeg, isEmpty, reason: 'lege waarden: ${leeg.join(', ')}');
  });
}
