import '../generated/l10n/app_localizations.dart';

/// Localized display label for an SRM activity type.
///
/// The database stores the Dutch activity names ("Opstaan", "Eerste contact",
/// "Werk / Hobby", "Avondeten", "Naar bed") as stable keys. They must NOT be
/// changed — existing rows and backups depend on them. Only the *display*
/// is translated here.
extension ActivityTypeL10n on String {
  String localizedActivityType(AppLocalizations l10n) {
    switch (trim().toLowerCase()) {
      case 'opstaan':
      case 'wakker':
        return l10n.rhythmOpstaan;
      case 'slapen':
      case 'naar bed':
      case 'bed':
        return l10n.rhythmNaarBed;
      case 'eten':
      case 'maaltijd':
      case 'avondeten':
        return l10n.rhythmAvondeten;
      case 'werk':
      case 'werken':
      case 'werk / hobby':
        return l10n.rhythmWerkHobby;
      case 'sociaal contact':
      case 'contact':
      case 'eerste contact':
        return l10n.rhythmEersteContact;
      default:
        return this;
    }
  }
}
