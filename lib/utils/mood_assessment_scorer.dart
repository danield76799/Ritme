/// Berekening voor de stemming-vragenlijst (5 vragen, gewogen) met
/// bipolaire-screeningslogica.
///
/// Brondata: `q1_stemming` (-4..+4, gewicht 3), `q2_energie_slider`
/// (0..100, zachtere mapping), `q3_energie_detail` (-3..+3, gewicht 2),
/// `q4_slaapbehoefte` (-4..+4, gewicht 2), `q5_gebeurtenis`
/// (-4..+4, gewicht 1).
///
/// Resultaat:
///  - Ritme-waarde -5..+5 (bestaande schaal, onveranderd)
///  - Continue rawScore (voor trendanalyse)
///  - Aanbeveling voor gesplitste stemming
///  - Diagnostische tags (bv. "Mogelijke manische shift",
///    "Gemengde episode")
class MoodAssessmentScorer {
  /// Weegfactoren per vraag.
  static const _w1 = 3.0; // stemming
  static const _w2 = 1.0; // energie slider
  static const _w3 = 2.0; // energie detail
  static const _w4 = 2.0; // slaapbehoefte
  static const _w5 = 1.0; // gebeurtenis

  static double _sumWeights = _w1 + _w2 + _w3 + _w4 + _w5; // 9.0

  /// Map q2 (0..100 slider, 100=manisch, 0=depressief) naar de Ritme-schaal.
  /// Zachtere variant: de slider meet een *globaal* energiegevoel, niet een
  /// scherpe manie/depressie-meting — andere vragen vangen de extremen op.
  static double mapQ2Slider(double sliderValue) {
    final clamped = sliderValue.clamp(0.0, 100.0);
    return (clamped - 50.0) / 20.0; // [-2.5..+2.5]
  }

  /// Berekent het gewogen gemiddelde van de 5 antwoorden, vóór clamp/round.
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
  /// Houdt rekening met conditionele boosts uit [applyBipolarBoosts].
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

  // ============================
  // BIPOLAIRE-SCREENING (A + B)
  // ============================

  /// Berekent bipolaire-specifieke boosts en tags op basis van de 5
  /// antwoorden. Boost = extra gewicht in de rawScore; tag = diagnostische
  /// markering die de gebruiker kan zien (zonder Ritme-waarde te beïnvloeden
  /// als de boost leidt tot een verkeerde classificatie).
  static BipolarAnalysis analyzeBipolar({
    required double q1,
    required double q3,
    required double q4,
    required double q5,
  }) {
    final tags = <BipolarTag>[];
    var bonus = 0.0;

    // ---- MANIE-POOL ----
    // Klassieke triade: stemming + energie + verminderde slaapbehoefte
    if (q1 >= 3 && q4 >= 3) {
      bonus += 0.5; // stemming + slaap = manie-signaal
      tags.add(BipolarTag.maniaShift);
    }
    if (q1 >= 3 && q3 >= 2 && q4 >= 2) {
      bonus += 0.7; // triade: stemming + energie + slaap
      tags.add(BipolarTag.probableMania);
    }
    // Verlaagde slaapbehoefte alleen al is een vroeg manie-signaal
    if (q4 >= 3 && (q1 >= 1 || q3 >= 1)) {
      tags.add(BipolarTag.sleepReductionAlone);
    }

    // ---- DEPRESSIE-POOL ----
    if (q1 <= -3 && q4 <= -2) {
      bonus -= 0.5; // stemming + slaapstoornis (vroeg wakker) = depressie-signaal
      tags.add(BipolarTag.depressionShift);
    }
    if (q1 <= -3 && q3 <= -2 && q4 <= -2) {
      bonus -= 0.7; // triade: stemming + energie + slaap
      tags.add(BipolarTag.probableDepression);
    }

    // ---- LIFE-EVENT TRIGGERS ----
    if (q5 >= 3 && q1 >= 2) {
      bonus += 0.3;
      tags.add(BipolarTag.positiveLifeEventTrigger);
    }
    if (q5 <= -3 && q1 <= -2) {
      bonus -= 0.3;
      tags.add(BipolarTag.negativeLifeEventTrigger);
    }

    // ---- GEMENGDE EPISODE ----
    // Tegenstrijdige signalen: stemming hoog + energie laag, of andersom
    final maniaSignsHigh = (q1 >= 2) || (q3 >= 2) || (q4 >= 2);
    final depressionSignsHigh = (q1 <= -2) || (q3 <= -2) || (q4 <= -2);
    if (maniaSignsHigh && depressionSignsHigh) {
      tags.add(BipolarTag.mixedEpisode);
    }
    // Sterke variant: q1 en q3 op tegenpolen
    if ((q1 >= 2 && q3 <= -2) || (q1 <= -2 && q3 >= 2)) {
      tags.add(BipolarTag.opposingSignals);
    }

    // Dedup-tags (houd ze uniek op id)
    final unique = <String, BipolarTag>{};
    for (final t in tags) {
      unique[t.name] = t;
    }

    return BipolarAnalysis(bonus: bonus, tags: unique.values.toList());
  }

  /// Past bipolaire boosts toe op de rawScore. Resultaat is een
  /// aangepaste continue score die de Ritme-mapping ingaat.
  static double applyBipolarBoosts({
    required double raw,
    required double bonus,
  }) {
    return raw + bonus;
  }

  /// Berekent zowel de continue score, de Ritme-mapping, aanbeveling voor
  /// gesplitste stemming, én bipolaire diagnostische tags.
  static MoodScoreResult compute({
    required double q1,
    required double q2Slider,
    required double q3,
    required double q4,
    required double q5,
  }) {
    final rawBase = rawWeightedScore(
      q1: q1,
      q2Slider: q2Slider,
      q3: q3,
      q4: q4,
      q5: q5,
    );
    final analysis = analyzeBipolar(
      q1: q1,
      q3: q3,
      q4: q4,
      q5: q5,
    );
    final rawWithBoosts = applyBipolarBoosts(
      raw: rawBase,
      bonus: analysis.bonus,
    );
    final ritme = toRitmeScale(rawWithBoosts);
    final recommendSplit = (q1 - q3).abs() >= 4.0;
    return MoodScoreResult(
      rawScore: rawWithBoosts,
      ritmeScore: ritme,
      recommendSplit: recommendSplit,
      bipolarTags: analysis.tags,
    );
  }
}

class BipolarAnalysis {
  final double bonus;
  final List<BipolarTag> tags;

  const BipolarAnalysis({
    required this.bonus,
    required this.tags,
  });
}

enum BipolarTag {
  maniaShift('maniaShift', 'Mogelijke manische shift'),
  probableMania('probableMania', 'Waarschijnlijke manie (triade)'),
  sleepReductionAlone(
    'sleepReductionAlone',
    'Verminderde slaapbehoefte — vroeg manie-signaal',
  ),
  depressionShift('depressionShift', 'Mogelijke depressieve shift'),
  probableDepression(
    'probableDepression',
    'Waarschijnlijke depressie (triade)',
  ),
  positiveLifeEventTrigger(
    'positiveLifeEventTrigger',
    'Positieve gebeurtenis als mogelijke manie-trigger',
  ),
  negativeLifeEventTrigger(
    'negativeLifeEventTrigger',
    'Negatieve gebeurtenis als mogelijke depressie-trigger',
  ),
  mixedEpisode('mixedEpisode', 'Mogelijke gemengde episode'),
  opposingSignals(
    'opposingSignals',
    'Tegenstrijdige signalen — controleer handmatig',
  );

  final String id;
  final String label;
  const BipolarTag(this.id, this.label);
}

class MoodScoreResult {
  final double rawScore;
  final int ritmeScore;
  final bool recommendSplit;
  final List<BipolarTag> bipolarTags;

  const MoodScoreResult({
    required this.rawScore,
    required this.ritmeScore,
    required this.recommendSplit,
    this.bipolarTags = const [],
  });
}
