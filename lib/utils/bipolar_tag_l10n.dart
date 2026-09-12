import '../generated/l10n/app_localizations.dart';
import 'mood_assessment_scorer.dart';

/// Localized label for a [BipolarTag]. Shared between the mood assessment
/// screen and the check-in screens (the enum's own `label` is Dutch-only).
extension BipolarTagL10n on BipolarTag {
  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case BipolarTag.maniaShift:
        return l10n.tagManiaShift;
      case BipolarTag.probableMania:
        return l10n.tagProbableMania;
      case BipolarTag.sleepReductionAlone:
        return l10n.tagSleepReductionAlone;
      case BipolarTag.depressionShift:
        return l10n.tagDepressionShift;
      case BipolarTag.probableDepression:
        return l10n.tagProbableDepression;
      case BipolarTag.positiveLifeEventTrigger:
        return l10n.tagPositiveLifeEventTrigger;
      case BipolarTag.negativeLifeEventTrigger:
        return l10n.tagNegativeLifeEventTrigger;
      case BipolarTag.mixedEpisode:
        return l10n.tagMixedEpisode;
      case BipolarTag.opposingSignals:
        return l10n.tagOpposingSignals;
    }
  }
}
