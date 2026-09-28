import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bereidt de test-omgeving voor op de Manrope-themes.
///
/// De app-themes gebruiken Manrope via google_fonts (runtime-fetching). In
/// tests is er geen netwerk en soms geen binding; zonder deze helper crasht
/// de eerste `AppTheme.lightTheme`-aanmaak met
/// "Binding has not yet been initialized" of een font-fetch-fout.
///
/// Aanpak: binding initialiseren, runtime-fetching uitzetten, en de
/// Manrope-fonts uit de app-assets handmatig in de font-registry laden onder
/// de namen die google_fonts vraagt.
///
/// Synchroon voorwerk dat in de BODY van main() moet staan: sommige tests
/// maken hun theme al vóór setUpAll aan, en google_fonts heeft dan al een
/// geïnitialiseerde binding nodig.
void bereidManropeTestBindingVoor() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
}

Future<void> laadManropeVoorTests() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // Zelfde bestand als de app-assets; hoeft dus niet dubbel in de repo.
  final ttf = File(
    'assets/fonts/Manrope-Regular.ttf',
  ).readAsBytesSync();

  // google_fonts vraagt per stijl: "Manrope-Regular", "Manrope-Bold", enz.
  // Eén en dezelfde variable-font-bytes onder alle namen registreren is
  // voldoende voor metingen — de glyphvormen verschillen nauwelijks en de
  // contrasttests kijken alleen naar kleuren.
  final stijlen = <String>[
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
    'Light',
    'Thin',
  ];
  for (final stijl in stijlen) {
    final loader = FontLoader('Manrope-$stijl')
      ..addFont(Future<ByteData>.value(ByteData.view(Uint8List.fromList(ttf).buffer)));
    await loader.load();
  }
  // Ook de familienaam zelf (google_fonts valt hierop terug bij sommige
  // TextStyle-combinaties).
  final familyLoader = FontLoader('Manrope')
    ..addFont(Future<ByteData>.value(ByteData.view(Uint8List.fromList(ttf).buffer)));
  await familyLoader.load();
}