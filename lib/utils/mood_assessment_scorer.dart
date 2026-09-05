/// Berekening voor de stemming-vragenlijst (5 vragen, gewogen).
///
/// Brondata: `q1_stemming` (-4..+4, gewicht 3), `q2_energie_slider`
/// (0..100, zachtere mapping), `q3_energie_detail` (-3..+3, gewicht 2),
/// `q4_slaapbehoefte` (-4..+4, gewicht 2), `q5_gebeurtenis`
/// (-4..+4, gewicht 1).
///
/// Resultaat: een waarde op de Ritme-schaal -5..+5 (afgerond naar gehele
/// waarde) en een optioneel voorschrift voor `gesplitste_stemming` als de
/// q3 en q1 te ver uit elkaar lopen.
class MoodAssessmentScorer {
  /// Weegfactoren per vraag.
  static const _w1 = 3.0; // stemming
  static const _w2 = 1.0; // energie slider
  static const _w3 = 2.0; // energie detail
  static const _w4 = 2.0; // slaapbehoefte
  static const _w5 = 1.0; // gebeurtenis

  static double _sumWeights = _w1 + _w2 + _w3 + _w4 + _w5; // 9.0

  /// Map q2 (0..100 slider, 0=manisch, 100=depressief) naar de Ritme-schaal.
  /// Zachtere variant: de slider meet een *globaal* energiegevoel, niet een
  /// scherpe manie/depressie-meting — andere vragen vangen de extremen op.
  static double mapQ2Slider(double sliderValue) {
    final clamped = sliderValue.clamp(0.0, 100.0);
    return (50.0 - clamped) / 20.0; // [-2.5..+2.5]
  }

  /// Berekent het gewogen gemiddelde van de 5 antwoorden, vóór clamp/round.
  /// Geeft een continue waarde terug (kan buiten -5..+5 vallen).
  static double rawWeightedScore({
    required double q1,
    required double q2Slider,
    required double q3,
    required double q4,
    required double q5,
  }) {
    final q2 = mapQ2Slider(q2Slider);
    return (_w1 * q1 +
            _w2 * q2 +
            _w3 * q3 +
            _w4 * q4 +
            _w5 * q5) /
        _sumWeights;
  }

  /// Map een continue score naar een gehele Ritme-waarde (-5..+5).
  static int toRitmeScale(double raw) {
    if (raw <= -3.5) return -4;
    if (raw <= -2.5) return -3;
    if (raw <= -1.5) return -2;
    if (raw <= -0.5) return -1;
    if (raw <= 0.5) return 0;
    if (raw <= 1.5) return 1;
    if (raw <= 2.5) return 2;
    if (raw <= 3.5) return 3;
    return 4;
  }

  /// Berekent zowel de continue score als de Ritme-mapping.
  /// Geeft ook aan of `gesplitste_stemming` aanbevolen wordt (als q1 en
  /// q3 meer dan 4 punten uit elkaar liggen).
  static MoodScoreResult compute({
    required double q1,
    required double q2Slider,
    required double q3,
    required double q4,
    required double q5,
  }) {
    final raw = rawWeightedScore(
      q1: q1,
      q2Slider: q2Slider,
      q3: q3,
      q4: q4,
      q5: q5,
    );
    final ritme = toRitmeScale(raw);
    final recommendSplit = (q1 - q3).abs() >= 4.0;
    return MoodScoreResult(
      rawScore: raw,
      ritmeScore: ritme,
      recommendSplit: recommendSplit,
    );
  }
}

class MoodScoreResult {
  final double rawScore;
  final int ritmeScore;
  final bool recommendSplit;

  const MoodScoreResult({
    required this.rawScore,
    required this.ritmeScore,
    required this.recommendSplit,
  });
}
