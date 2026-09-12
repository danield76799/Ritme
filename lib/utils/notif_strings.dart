import 'dart:ui';

/// Locale-aware strings for notifications and background services that have
/// no BuildContext. Reads the platform locale directly.
class NotifStrings {
  static bool get _nl =>
      PlatformDispatcher.instance.locale.languageCode.toLowerCase() == 'nl';

  static String get medication => _nl ? 'Medicatie' : 'Medication';
  static String get medicationReminders =>
      _nl ? 'Medicatie Herinneringen' : 'Medication Reminders';
  static String get medicationRemindersDesc =>
      _nl ? 'Herinneringen voor medicatie inname' : 'Reminders for medication intake';
  static String get medicationReminder =>
      _nl ? 'Medicatie herinnering' : 'Medication reminder';
  static String get taken => _nl ? '✅ Ingenomen' : '✅ Taken';
  static String get skip => _nl ? '⏭ Sla over' : '⏭ Skip';
  static String get snooze => _nl ? '⏳ Snooze (15m)' : '⏳ Snooze (15m)';
  static String get open => _nl ? 'Openen' : 'Open';
  static String get medicationReminderShort => _nl ? '💊 Herinnering' : '💊 Reminder';
  static String get dailyReminders => _nl ? 'Dagelijkse Herinneringen' : 'Daily Reminders';
  static String get dailyRemindersDesc => _nl ? 'Dagelijkse herinneringen voor ritualen' : 'Daily reminders for rituals';
  static String get testNotification => _nl ? '🧪 Test Notificatie' : '🧪 Test Notification';
  static String get testNotificationBody => _nl ? 'Als je dit ziet, werken notificaties!' : 'If you see this, notifications work!';
  static String get testNotifications => _nl ? 'Test Notificaties' : 'Test Notifications';
  static String get testNotificationsDesc => _nl ? 'Test notificaties voor verifieren van instellingen' : 'Test notifications for verifying settings';
  static String get backupSubject => 'Ritme Backup';
  static String get backupText => _nl ? 'Hier is mijn Ritme app backup. Bewaar deze veilig!' : 'Here is my Ritme app backup. Keep it safe!';

  static List<String> get dayNames => _nl
      ? ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo']
      : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String get appointmentReminders =>
      _nl ? 'Afspraak herinneringen' : 'Appointment Reminders';
  static String get appointmentRemindersDesc =>
      _nl ? 'Herinneringen voor medische afspraken' : 'Reminders for medical appointments';
  static String get appointmentReminder =>
      _nl ? '📅 Afspraak herinnering' : '📅 Appointment reminder';

  static String timeToTakeMedication(String daysStr) => _nl
      ? 'Tijd om je medicatie in te nemen! ($daysStr)'
      : 'Time to take your medication! ($daysStr)';

  static String timeToTakeMedicationSnoozed() => _nl
      ? 'Tijd om je medicatie in te nemen! (Snoozed)'
      : 'Time to take your medication! (Snoozed)';

  static String appointmentBody(String title, String doctorName, int days) {
    final daysStr = days == 1
        ? (_nl ? '1 dag' : '1 day')
        : (_nl ? '$days dagen' : '$days days');
    final withDoctor = doctorName.isNotEmpty
        ? (_nl ? ' met $doctorName' : ' with $doctorName')
        : '';
    return _nl
        ? '$title$withDoctor over $daysStr'
        : '$title$withDoctor in $daysStr';
  }

  // Bipolar alert service
  static String get sleepWarning => _nl ? '⚠️ Slaapwaarschuwing' : '⚠️ Sleep warning';
  static String get lessSleep => _nl ? '💤 Minder slaap' : '💤 Less sleep';
  static String get muchSleep => _nl ? '🔵 Veel slaap' : '🔵 Much sleep';

  static String sleepWarningBody(double last, String dev, double baseline) => _nl
      ? 'Je sliep ${last.toStringAsFixed(1)}u — dat is $dev% minder dan je gemiddelde van ${baseline.toStringAsFixed(1)}u. Verminderde slaap is een belangrijk voorteken van manie.'
      : 'You slept ${last.toStringAsFixed(1)}h — that is $dev% less than your average of ${baseline.toStringAsFixed(1)}h. Reduced sleep is an important early sign of mania.';

  static String lessSleepBody(double last, String dev) => _nl
      ? 'Je sliep ${last.toStringAsFixed(1)}u, $dev% onder je gemiddelde. Houd je stemming extra in de gaten vandaag.'
      : 'You slept ${last.toStringAsFixed(1)}h, $dev% below your average. Keep an extra eye on your mood today.';

  static String muchSleepBody(double last, double baseline) => _nl
      ? 'Je sliep ${last.toStringAsFixed(1)}u — veel meer dan normaal (${baseline.toStringAsFixed(1)}u). Dit kan een teken zijn van depressie.'
      : 'You slept ${last.toStringAsFixed(1)}h — much more than usual (${baseline.toStringAsFixed(1)}h). This can be a sign of depression.';

  static String get srtDropped => _nl
      ? 'Je dagelijkse ritme (SRT score) is gedaald. Sociale ritme verstoring kan episodes uitlokken. Probeer je vaste tijden weer op te pakken.'
      : 'Your daily rhythm (SRT score) has dropped. Social rhythm disruption can trigger episodes. Try to pick up your regular times again.';

  static String warningCount3Days(int total, bool urgent) {
    if (_nl) {
      return urgent
          ? 'Je hebt in 3 dagen $total voortekenen gerapporteerd. Overweeg je crisisplan te raadplegen.'
          : 'Je rapporteert $total voortekenen in 3 dagen. Blijf monitoren.';
    }
    return urgent
        ? 'You have reported $total early warning signs in 3 days. Consider consulting your crisis plan.'
        : 'You are reporting $total early warning signs in 3 days. Keep monitoring.';
  }
}
