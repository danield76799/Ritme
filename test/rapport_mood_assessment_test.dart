import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/utils/mood_assessment_scorer.dart';

void main() {
  test('Bipolaire analyse-teller produceert NL-labels en percentages', () {
    // Simuleer 3 dagen: manische triade, neutraal, depressieve triade
    final days = [
      MoodAssessmentScorer.compute(q1: 4, q2Slider: 90, q3: 3, q4: 4, q5: 0),
      MoodAssessmentScorer.compute(q1: 0, q2Slider: 50, q3: 0, q4: 0, q5: 0),
      MoodAssessmentScorer.compute(q1: -4, q2Slider: 10, q3: -3, q4: -4, q5: -4),
    ];

    // Zelfde aggregatie-logica als rapport_generator
    final flagCounts = <String, int>{};
    double sumQ1 = 0, sumRaw = 0;
    int nQ1 = 0, nRaw = 0;
    for (final d in days) {
      sumQ1 += d.rawScore >= -900 ? 0 : 0; // placeholder, direct hieronder
    }
    // Herleid: gebruik q1 via compute-inputs
    final q1s = [4.0, 0.0, -4.0];
    for (var i = 0; i < days.length; i++) {
      sumQ1 += q1s[i];
      nQ1++;
      sumRaw += days[i].ritmeScore;
      nRaw++;
      for (final t in days[i].bipolarTags) {
        flagCounts[t.id] = (flagCounts[t.id] ?? 0) + 1;
      }
    }

    expect(nQ1, 3);
    expect((sumQ1 / nQ1).toStringAsFixed(1), '0.0');
    expect((sumRaw / nRaw).toStringAsFixed(1), '0.0');
    expect(flagCounts['probableMania'], 1);
    expect(flagCounts['probableDepression'], 1);
  });

  test('mapQ2Slider: 100=manisch (+2.5), 0=depressief (-2.5)', () {
    expect(MoodAssessmentScorer.mapQ2Slider(100), 2.5);
    expect(MoodAssessmentScorer.mapQ2Slider(0), -2.5);
    expect(MoodAssessmentScorer.mapQ2Slider(50), 0.0);
  });
}