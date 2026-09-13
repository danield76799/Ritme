import 'package:flutter/material.dart';

/// Kleurpalet voor het Ritme Stabiliteit-scherm.
///
/// De dark-waarden zijn exact zoals aangeleverd in het ontwerp. Omdat de app op
/// [ThemeMode.system] staat, bestaat light mode ook: de ontworpen accent- en
/// statuskleuren halen op wit maar 1.67–2.77:1 en zijn daar dus onleesbaar.
/// Daarom heeft elke kleur een light-variant die >=4.5:1 haalt.
class StabilityPalette {
  StabilityPalette._();

  // ---------------------------------------------------------------- dark
  /// Canvas / scaffold.
  static const Color darkCanvas = Color(0xFF0F141A);

  /// Kaart-oppervlak.
  static const Color darkCard = Color(0xFF1A222D);

  /// Filterchips en secundaire vlakken.
  static const Color darkChip = Color(0xFF1E2836);

  /// Primair accent (cyaan/teal). 9.9:1 op canvas, 8.6:1 op kaart.
  static const Color darkAccent = Color(0xFF4FD1C5);

  /// Donkere tekst óp het accent — wit haalt daar maar 1.79:1.
  static const Color onAccent = Color(0xFF0F1A1D);

  // --------------------------------------------------------------- light
  static const Color lightCanvas = Color(0xFFF7F9FA);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightChip = Color(0xFFEEF3F5);

  /// 4.95:1 op wit.
  static const Color lightAccent = Color(0xFF2C7A87);

  // -------------------------------------------------------------- status
  static const Color darkSuccess = Color(0xFF34D399);
  static const Color darkWarning = Color(0xFFFBBF24);
  static const Color darkAlert = Color(0xFFF87171);

  /// Op wit: 5.48:1 / 5.02:1 / 6.47:1.
  static const Color lightSuccess = Color(0xFF047857);
  static const Color lightWarning = Color(0xFFB45309);
  static const Color lightAlert = Color(0xFFB91C1C);

  // ------------------------------------------------------------ helpers
  static bool _dark(Brightness b) => b == Brightness.dark;

  static Color canvas(Brightness b) => _dark(b) ? darkCanvas : lightCanvas;
  static Color card(Brightness b) => _dark(b) ? darkCard : lightCard;
  static Color chip(Brightness b) => _dark(b) ? darkChip : lightChip;
  static Color accent(Brightness b) => _dark(b) ? darkAccent : lightAccent;

  /// Primaire tekst: fel op donker, bijna-zwart op licht.
  static Color primaryText(Brightness b) =>
      _dark(b) ? Colors.white : AppTheme.textCharcoal;

  /// Secundaire tekst met >=4.5:1 op zowel canvas als kaart.
  static Color secondaryText(Brightness b) =>
      _dark(b) ? const Color(0xFF9FB0B8) : AppTheme.textMedium;

  /// Scorekleur per p-score.
  ///
  /// De app hanteert vier p-score-niveaus (5 = Perfect, 3-4 = Op tijd,
  /// 1-2 = Enigszins, 0 = Gemist). Het ontwerp noemt drie pillen; het
  /// kleurgedrag komt overeen (groen / amber / rood) zonder een bestaand
  /// niveau weg te gooien.
  static Color status(Brightness b, int pScore) {
    if (pScore >= 3) return _dark(b) ? darkSuccess : lightSuccess;
    if (pScore >= 1) return _dark(b) ? darkWarning : lightWarning;
    return _dark(b) ? darkAlert : lightAlert;
  }
}
