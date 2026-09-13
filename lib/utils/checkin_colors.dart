import 'package:flutter/material.dart';

/// Kleuren voor de bipolaire score-schalen (-4..+4).
///
/// Stond eerder in `screens/morning_checkin_screen.dart`, maar het
/// avondscherm importeerde die via `show MoodAssessmentScorerColors` — een
/// widgetbestand als kleurenbron is fragiel. Hier hoort het thuis.
class MoodAssessmentScorerColors {
  MoodAssessmentScorerColors._();

  /// Kleur voor de slaapbehoefte-/stemmingsschaal.
  ///
  /// LET OP: dit is bewust een stoplicht-gradient. De ochtend-check-in toont
  /// deze kleuren NIET meer in de keuzekaarten (daar is één rustige accentkleur
  /// leidend), maar het avondscherm en de overzichten gebruiken ze nog wel om
  /// de ernst van een score te duiden.
  static Color slaapbehoefteColor(double v) {
    if (v <= -4) return const Color(0xFF616161);
    if (v <= -3) return const Color(0xFF424242);
    if (v <= -2) return const Color(0xFF42A5F5);
    if (v <= -1) return const Color(0xFF90CAF9);
    if (v == 0) return const Color(0xFF66BB6A);
    if (v <= 1) return const Color(0xFFFDD835);
    if (v <= 2) return const Color(0xFFFF9800);
    if (v <= 3) return const Color(0xFFF57C00);
    return const Color(0xFFE53935);
  }

  /// Geselecteerde score → leesbare romeinse weergave (+2, 0, —3).
  /// Gebruikt het typografische minteken (—) zoals de rest van de app.
  static String scoreLabel(double score) {
    final i = score.toInt();
    if (i == 0) return '0';
    return i > 0 ? '+$i' : '—${i.abs()}';
  }
}

// De kleuren van de nachtmodus-check-in

/// Eén rustige accentkleur voor de ochtend-check-in in plaats van de
/// stoplicht-gradient per optie.
class CheckinAccent {
  CheckinAccent._();

  /// Primair accent (cyaan/teal). Haalt 9.9:1 op de donkere achtergrond en
  /// 7.4:1 op de donkere kaart — ruim boven WCAG AA.
  static const Color teal = Color(0xFF64D2D7);

  /// Donkere tekst óp het accent (gevulde knop/badge).
  /// Wit op dit accent is maar 1.79:1 en dus onleesbaar; deze kleur haalt 9.9:1.
  static const Color onAccent = Color(0xFF0F1A1D);

  /// Kaartachtergrond van een niet-geselecteerde optie.
  static const Color unselectedDark = Color(0xFF162226);

  /// Rustige rand van een niet-geselecteerde optie in dark mode.
  static Color unselectedBorder(Brightness brightness) =>
      brightness == Brightness.dark
          ? Colors.white12
          : const Color(0x1F000000);
}
