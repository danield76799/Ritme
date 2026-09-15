// Borgt de dagboek-exportkeuze (09-2026): tekst (WhatsApp/Gemini) én
// echte PDF (behandelaar/archief), beide over dezelfde 30-dagen-range.
// Geen sterren/emoji in het PDF-pad: het standaard PDF-font mist die glyphs.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Broncode zonder commentaar.
String _code(String pad) {
  final zonderBlok =
      File(pad).readAsStringSync().replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return zonderBlok
      .split('\n')
      .map((regel) => regel.replaceAll(RegExp(r'//.*$'), ''))
      .join('\n');
}

void main() {
  group('Dagboek-export: tekst én PDF', () {
    test('keuzemenu biedt tekst en PDF', () {
      final code = _code('lib/screens/dagboek_screen.dart');
      expect(code.contains('alsTekstDelen'), isTrue);
      expect(code.contains('alsPdfDelen'), isTrue);
      expect(code.contains("if (keuze == 'pdf')"), isTrue);
    });

    test('PDF gaat via Printing.layoutPdf (echte PDF, geen markdown)', () {
      final code = _code('lib/screens/dagboek_screen.dart');
      expect(code.contains('Printing.layoutPdf'), isTrue);
      expect(code.contains('pw.MultiPage'), isTrue);
    });

    test('beide exports delen één 30-dagen-range', () {
      final code = _code('lib/screens/dagboek_screen.dart');
      expect(
        RegExp(r'_dagboekenLaatste30Dagen').allMatches(code).length,
        greaterThanOrEqualTo(3),
        reason: 'helper + twee aanroepen (tekst, PDF)',
      );
      expect(code.contains('Duration(days: 30)'), isTrue);
    });

    test('PDF-pad bevat geen sterren of emoji', () {
      final code = _code('lib/screens/dagboek_screen.dart');
      final start = code.indexOf('_exporteerAlsPdf');
      expect(start, greaterThan(-1));
      // Alleen de PDF-methode zelf (tot de _pdfDatum-definitie);
      // _scoreLabel daarna houdt bewust sterren voor de TEKST-export.
      final stop = code.indexOf('String _pdfDatum', start);
      expect(stop, greaterThan(start));
      final blok = code.substring(start, stop);
      expect(blok.contains('★'), isFalse,
          reason: 'standaard PDF-font mist de glyph');
      expect(blok.contains('Score: '), isTrue,
          reason: 'score als "4/5 – Goed"');
    });
  });
}
