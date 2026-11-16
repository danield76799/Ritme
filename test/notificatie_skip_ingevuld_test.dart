// Regressietests:
// Wie zijn check-in of medicijn vandaag al heeft ingevuld/afgevinkt,
// hoort geen herinnering meer voor vandaag. De notificaties mogen pas
// weer van morgen af aan plannen — nooit vandaag alsnog pingen.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _bron(String pad) => File(pad).readAsStringSync();

void main() {
  late String helper;

  setUpAll(() {
    helper = _bron('lib/services/notification_helper.dart');
  });

  group('Check-in herinnering slaat een ingevulde dag over', () {
    test('de scheduling kijkt of de check-in van VANDAAG al is ingevuld', () {
      expect(helper, contains('CheckinStatus.voor(CheckinStatus.dateKey(now))'),
          reason: 'de planner moet de status van vandaag opvragen');
    });

    test('bij een ingevulde dag wordt de melding een dag opgeschoven', () {
      expect(helper, contains('vandaagGedaan'),
          reason: 'er moet op de vandaag-status getoetst worden');
      expect(helper, contains('if (scheduled.isBefore(now) || vandaagGedaan)'),
          reason: 'een ingevulde dag moet dezelfde voorkoming in de toekomst plannen');
    });
  });

  group('Medicatie-herinnering slaat een afgevinkte dag over', () {
    test('er is een helper die checkt of het medicijn vandaag afgevinkt is', () {
      expect(helper, contains('_medHandledToday'),
          reason: 'zonder deze check pingt de herinnering ook na afvinken');
    });

    test('de helper kijkt naar medication_intakes van vandaag', () {
      expect(helper, contains("db.getMedicationIntake(today)"),
          reason: 'afvinken schrijft naar medication_intakes');
    });

    test('de dagelijkse planning houdt rekening met afgevinkt', () {
      expect(helper, contains('scheduledDate.isBefore(now) || medHandled'),
          reason: 'een al afgevinkt medicijn mag vandaag niet meer pingen');
    });
  });

  group('Afvinken triggert een herplanning', () {
    test('notification action "taken"/"skip" plant medicatie-herinneringen opnieuw', () {
      expect(helper, contains("actionId == 'taken' || actionId == 'skip'"),
          reason: 'afvinken via de melding zelf moet de dag-reminder weghalen');
    });

    test('medicatiescherm herplant na in- en uitschakelen van een intake', () {
      final screen = _bron('lib/screens/medication_screen.dart');
      expect(screen, contains('rescheduleAllMedicationReminders'),
          reason: 'na het afvinken in het scherm moet vandaag niet meer pingen');
    });
  });

  group('Snooze overschrijft de dagelijkse melding niet', () {
    test('snooze gebruikt een eigen notificatie-id-bereik', () {
      // 5000000+ ligt buiten het bereik van de dagelijkse (10_000-99_999)
      // en de per-weekdag meldingen (×10). Voorheen hergebruikte snooze het
      // dagelijkse id en verdween de dagelijkse herhaling na één snooze.
      expect(helper, contains('5000000 + (medicationId % 400000)'),
          reason: 'snooze mag het id van de dagelijkse herinnering niet overschrijven');
    });
  });

  group('Check-in opslaan triggert een herplanning', () {
    test('ochtend-check-in herplant na succesvol opslaan', () {
      final screen = _bron('lib/screens/morning_checkin_screen.dart');
      expect(screen, contains('rescheduleCheckinReminders'),
          reason: 'na opslaan van de ochtend-check-in moet de herinnering van vandaag weg');
    });

    test('avond-check-in herplant na succesvol opslaan', () {
      final screen = _bron('lib/screens/evening_checkin_screen.dart');
      expect(screen, contains('rescheduleCheckinReminders'),
          reason: 'na opslaan van de avond-check-in moet de herinnering van vandaag weg');
    });
  });
}
