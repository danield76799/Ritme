import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/utils/mood_assessment_scorer.dart';

void main() {
  test('menstruatie + afwijkende stemming → menstruationMoodSwing-tag', () {
    // Menstruatie + depressieve stemming
    final dep = MoodAssessmentScorer.compute(
      q1: -3, q2Slider: 80, q3: -2, q4: -2, q5: 0, menstruatie: true,
    );
    expect(dep.bipolarTags.any((t) => t.id == 'menstruationMoodSwing'), true,
        reason: 'menstruatie + depressieve stemming moet de tag geven');

    // Menstruatie + manische stemming
    final man = MoodAssessmentScorer.compute(
      q1: 3, q2Slider: 10, q3: 2, q4: 3, q5: 0, menstruatie: true,
    );
    expect(man.bipolarTags.any((t) => t.id == 'menstruationMoodSwing'), true);

    // Menstruatie + NEUTRALE stemming → geen tag
    final neutral = MoodAssessmentScorer.compute(
      q1: 0, q2Slider: 50, q3: 0, q4: 0, q5: 0, menstruatie: true,
    );
    expect(neutral.bipolarTags.any((t) => t.id == 'menstruationMoodSwing'), false,
        reason: 'neutrale stemming is geen omslag-signaal');

    // Zonder menstruatie → nooit de tag
    final noMenstr = MoodAssessmentScorer.compute(
      q1: -3, q2Slider: 80, q3: -2, q4: -2, q5: 0, menstruatie: false,
    );
    expect(noMenstr.bipolarTags.any((t) => t.id == 'menstruationMoodSwing'), false);

    // Menstruatie beïnvloedt de score NIET (alleen tag)
    final withMenstr = MoodAssessmentScorer.compute(
      q1: -3, q2Slider: 80, q3: -2, q4: -2, q5: 0, menstruatie: true,
    );
    final withoutMenstr = MoodAssessmentScorer.compute(
      q1: -3, q2Slider: 80, q3: -2, q4: -2, q5: 0, menstruatie: false,
    );
    expect(withMenstr.ritmeScore, withoutMenstr.ritmeScore,
        reason: 'menstruatie is een signaal, geen score-weging');
    expect(withMenstr.rawScore, withoutMenstr.rawScore);
  });
}