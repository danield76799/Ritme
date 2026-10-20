import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Maakt rapporttekst PDF-veilig: speciale tekens vervangen, emoji weg.
String sanitizeVoorPdf(String s) {
  var out = s;
  out = out.replaceAll('−', '-'); // U+2212 min-teken -> ASCII
  out = out.replaceAll('→', '->');
  out = out.replaceAll('✓', 'v');
  out = out.replaceAll(
      RegExp(
          '[\\u2190-\\u21FF\\u2600-\\u26FF\\u2700-\\u27BF\\u2B00-\\u2BFF\\uFE00-\\uFE0F'
          '\\u200D\\u2640\\u2642\\u2764\\u2705\\u274C\\u{1F000}-\\u{1FAFF}]',
          unicode: true),
      '');
  out = out.replaceAll(RegExp('  +'), ' ');
  return out;
}

pw.Widget _paragraaf(String regel, {double grootte = 11}) {
  final pat = RegExp(r'\*\*(.+?)\*\*');
  if (!pat.hasMatch(regel)) {
    return pw.Text(
      regel.replaceAll('**', ''),
      style: pw.TextStyle(fontSize: grootte),
    );
  }
  final kinderen = <pw.TextSpan>[];
  var pos = 0;
  for (final m in pat.allMatches(regel)) {
    if (m.start > pos) {
      kinderen.add(pw.TextSpan(text: regel.substring(pos, m.start)));
    }
    kinderen.add(pw.TextSpan(
      text: m.group(1),
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    ));
    pos = m.end;
  }
  if (pos < regel.length) {
    kinderen.add(pw.TextSpan(text: regel.substring(pos)));
  }
  return pw.RichText(
    text: pw.TextSpan(
      style: pw.TextStyle(fontSize: grootte),
      children: kinderen,
    ),
  );
}

List<String> _cellen(String rij) {
  var delen = rij.split('|');
  if (delen.isNotEmpty && delen.first.trim().isEmpty) {
    delen = delen.sublist(1);
  }
  if (delen.isNotEmpty && delen.last.trim().isEmpty) {
    delen = delen.sublist(0, delen.length - 1);
  }
  return delen.map((c) => c.trim().replaceAll('**', '')).toList();
}

bool _isScheiding(String regel) {
  final cellen = _cellen(regel);
  if (cellen.isEmpty) return false;
  return cellen.every((c) => RegExp(r'^:?-{3,}:?$').hasMatch(c));
}

pw.Widget _tabel(List<String> rijen) {
  final data =
      rijen.where((r) => !_isScheiding(r)).map(_cellen).toList();
  if (data.isEmpty) return pw.SizedBox();
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey300),
    columnWidths: {
      for (var i = 0; i < data.first.length; i++) i: const pw.FlexColumnWidth(),
    },
    children: [
      for (var ri = 0; ri < data.length; ri++)
        pw.TableRow(
          decoration: ri == 0
              ? const pw.BoxDecoration(color: PdfColors.teal50)
              : null,
          children: [
            for (final cel in data[ri])
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  cel,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: ri == 0
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                  ),
                ),
              ),
          ],
        ),
    ],
  );
}

List<pw.Widget> markdownNaarPdf(String markdown) {
  final widgets = <pw.Widget>[];
  final regels = sanitizeVoorPdf(markdown).split('\n');
  var i = 0;
  bool inCorrelationBox = false;
  final correlationBoxContent = <pw.Widget>[];

  while (i < regels.length) {
    final regel = regels[i].trimRight();
    final kaal = regel.trim();

    if (kaal.isEmpty) {
      if (inCorrelationBox) correlationBoxContent.add(pw.SizedBox(height: 5));
      i++;
      continue;
    }

    if (kaal.startsWith('## ')) {
      // If we were in a box, close it first
      if (inCorrelationBox) {
        widgets.add(pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.teal50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(color: PdfColors.teal200),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '🧬 Correlatie Analyse',
                style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
              ),
              pw.SizedBox(height: 8),
              ...correlationBoxContent,
            ],
          ),
        ));
        inCorrelationBox = false;
        correlationBoxContent.clear();
      }

      final title = kaal.substring(3).trim();
      if (title.contains('Correlatie') || title.contains('Correlation')) {
        inCorrelationBox = true;
        i++;
        continue;
      } else {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
          child: pw.Text(
            title,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800),
          ),
        ));
        i++;
        continue;
      }
    }

    // Process content
    pw.Widget? contentWidget;
    if (kaal == '---') {
      contentWidget = pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.Divider(color: PdfColors.grey300),
      );
    } else if (kaal.startsWith('|')) {
      final groep = <String>[];
      while (i < regels.length && regels[i].trim().startsWith('|')) {
        groep.add(regels[i].trim());
        i++;
      }
      contentWidget = pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _tabel(groep),
          pw.SizedBox(height: 8),
        ],
      );
      if (inCorrelationBox) correlationBoxContent.add(contentWidget);
      else widgets.add(contentWidget);
      continue;
    } else if (kaal.startsWith('- ') || kaal.startsWith('• ')) {
      contentWidget = pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('•  ', style: const pw.TextStyle(fontSize: 11)),
            pw.Expanded(child: _paragraaf(kaal.substring(2).trim())),
          ],
        ),
      );
    } else {
      contentWidget = pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: _paragraaf(kaal),
      );
    }

    if (contentWidget != null) {
      if (inCorrelationBox) correlationBoxContent.add(contentWidget);
      else widgets.add(contentWidget);
    }
    i++;
  }

  // Final close for box if it was the last section
  if (inCorrelationBox) {
    widgets.add(pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal50,
        borderRadius: const pw.BorderRadius.all(// laatst geredigeerd
        pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.teal200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '🧬 Correlatie Analyse',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
          ),
          pw.SizedBox(height: 8),
          ...correlationBoxContent,
        ],
      ),
    ));
  }

  return widgets;
}

/// Bouwt het complete rapport-PDF als bytes.
Future<Uint8List> bouwRapportPdf({
  required String titel,
  required String markdown,
  String? patientName,
}) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Text(
              titel,
              style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal900),
            ),
          ),
          if (patientName != null)
            pw.Text(
              'Patiënt: $patientName',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.teal200),
        ],
      ),
      footer: (pw.Context ctx) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Text(
          'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
      ),
      build: (pw.Context ctx) => markdownNaarPdf(markdown),
    ),
  );
  return pdf.save();
}
