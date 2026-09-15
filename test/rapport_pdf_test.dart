// Tests voor de rapport-PDF (09-2026): het LCM-rapport (markdown) gaat als
// ECHTE pdf mee (behandelaar/archief), naast tekst + .md. Puur Dart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:ritme/services/rapport_pdf.dart';

/// Leest de platte tekst uit een pdf-widget (Padding > RichText/Text).
String _pdfTekst(pw.Widget w) {
  if (w is pw.Padding) {
    final kind = w.child;
    if (kind == null) return '';
    return _pdfTekst(kind);
  }
  if (w is pw.RichText) return _spanTekst(w.text);
  return '';
}

String _spanTekst(pw.InlineSpan s) {
  if (s is! pw.TextSpan) return '';
  return (s.text ?? '') + (s.children?.map(_spanTekst).join() ?? '');
}

String _celTekst(pw.TableRow r, int i) => _pdfTekst(r.children[i]);

void main() {
  group('sanitizeVoorPdf: WinAnsi-veilig', () {
    test('min-teken en pijl worden ASCII', () {
      expect(sanitizeVoorPdf('(−4..+4)'), '(−4..+4)'.replaceAll('−', '-'));
      expect(sanitizeVoorPdf('a → b'), 'a -> b');
    });

    test('emoji verdwijnt, woord blijft', () {
      // Voorloopspatie is ok: markdownNaarPdf trimt elke regel zelf.
      expect(sanitizeVoorPdf('✅ Blijf zo doorgaan').trim(),
          'Blijf zo doorgaan');
      expect(sanitizeVoorPdf('## 📈 Samenvatting'), '## Samenvatting');
      expect(sanitizeVoorPdf('  ✅ 2026-09-10'), ' 2026-09-10');
    });

    test('gewone Nederlandse tekst blijft heel', () {
      const tekst = 'Patiënt: slaapbehoefte, medicatie-inname, beïnvloeden';
      expect(sanitizeVoorPdf(tekst), tekst);
    });
  });

  group('markdownNaarPdf: constructies van de generator', () {
    test('headers worden koppen, geen hekjes', () {
      final widgets = markdownNaarPdf('## Stemming\n# Titel\n');
      expect(widgets.length, 2);
      expect(_pdfTekst(widgets[0]).contains('##'), isFalse);
      expect(_pdfTekst(widgets[0]).contains('Stemming'), isTrue);
    });

    test('tabel: scheidingsrij weg, eerste rij vet', () {
      final widgets = markdownNaarPdf(
          '| A | B |\n|---|---|\n| **x** | 1 |\n');
      final tabellen = widgets.whereType<pw.Table>();
      expect(tabellen.length, 1);
      final rijen = tabellen.first.children;
      expect(rijen.length, 2); // header + 1 datarij
      expect(_celTekst(rijen[0], 0), 'A');
      expect(_celTekst(rijen[1], 0), 'x'); // ** eraf
    });

    test('bold-paragraaf wordt RichText', () {
      final widgets = markdownNaarPdf('**Patiënt:** Jan\n');
      final rijken = widgets
          .whereType<pw.Padding>()
          .where((p) => p.child is pw.RichText)
          .toList();
      expect(rijken.length, 1);
      expect(_pdfTekst(rijken.first).contains('Patiënt:'), isTrue);
      expect(_pdfTekst(rijken.first).contains('**'), isFalse);
    });

    test('--- wordt een scheidingslijn', () {
      final widgets = markdownNaarPdf('a\n---\nb\n');
      expect(widgets.whereType<pw.Padding>().length, greaterThanOrEqualTo(1));
      final heeftDivider = widgets.any((w) =>
          w is pw.Padding && (w).child is pw.Divider);
      expect(heeftDivider, isTrue);
    });
  });

  group('bouwRapportPdf: echte bytes', () {
    test('levert een PDF-document', () async {
      const md = '## Overzicht\n\n**Patiënt:** Jan\n\n| A | B |\n|---|---|\n| x | 1 |\n\n---\n\nKlaar\n';
      final bytes = await bouwRapportPdf(
          titel: 'Ritme Rapport', markdown: md);
      expect(bytes.length, greaterThan(500));
      final kop = String.fromCharCodes(bytes.take(5));
      expect(kop, '%PDF-');
    });
  });

  group('Rapport-scherm: tekst én PDF (structuur)', () {
    test('deelknop vraagt tekst of PDF', () {
      final code = File('lib/screens/rapport_screen.dart').readAsStringSync();
      expect(code.contains('_kiesDeelvorm'), isTrue);
      expect(code.contains("_deelPdf"), isTrue);
      expect(code.contains('alsTekstDelen'), isTrue);
      expect(code.contains('alsPdfDelen'), isTrue);
      // Oude tekst-deel blijft bestaan als optie.
      expect(code.contains('_deelRapport'), isTrue);
    });
  });
}
