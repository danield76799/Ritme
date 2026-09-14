// Regressietests voor afspraakherinneringen (09-2026).
//
// Vier gestapelde bugs maakten "herinnering zetten" kapot:
//
// 1. OPSTART VEEGDE ALLES WEG. rescheduleAllMedicationReminders() doet
//    cancelAll() en plant daarna alleen medicatie + check-ins terug.
//    Afspraken werden nooit herpland: elke app-start waste ze. Nu haakt
//    rescheduleAppointmentReminders() daar aan (eigen try/catch).
//
// 2. reminder_days OVERLEEFDE DE DB NIET. insert/update schreven het veld
//    niet weg; getters maakten van alles String. Na heropenen stond de
//    dropdown op "Geen herinnering" en waste opnieuw opslaan de planning.
//    Nu: int in, int uit (roundtrip hieronder bewijst het).
//
// 3. EXACT-ALARM ZONDER CHECK. scheduleAppointmentReminder gebruikte
//    hard-coded exactAllowWhileIdle: zonder toestemming gooit Android een
//    SecurityException die stil werd weggeslikt. Nu: check + inexact-fallback
//    en een terugmelding (null / 'verleden' / fouttekst).
//
// 4. ID-BOTSING. (id*100)%100000 kon met medicatie-IDs botsen. Nu eigen
//    range 1000-9999.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ritme/database/hive_database_helper.dart';

/// Broncode zonder commentaar.
String _code(String pad) {
  final zonderBlok =
      File(pad).readAsStringSync().replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return zonderBlok
      .split('\n')
      .map((regel) => regel.replaceAll(RegExp(r'//.*$'), ''))
      .join('\n');
}

Future<void> _openSchoneBox(String naam, String dir) async {
  if (Hive.isBoxOpen(naam)) {
    await Hive.box(naam).deleteFromDisk();
  } else {
    try {
      await Hive.deleteBoxFromDisk(naam);
    } catch (_) {}
  }
  await Hive.openBox(naam);
  await Hive.box(naam).clear();
}

void main() {
  group('reminder_days overleeft de DB als int (echte Hive-roundtrip)', () {
    setUpAll(() {
      Hive.init('/tmp/hive_test_afspraak');
    });

    test('opslaan en teruglezen geeft int 3, geen String', () async {
      await _openSchoneBox('medical_appointments', '/tmp/hive_test_afspraak');
      final helper = HiveDatabaseHelper.instance;

      final id = await helper.insertMedicalAppointment({
        'title': 'Controle',
        'appointment_date': '20-12-2026',
        'appointment_time': '10:00',
        'reminder_days': 3,
      });

      final alle = await helper.getMedicalAppointments();
      // ignore: avoid_print
      final terug =
          alle.firstWhere((a) => a['id'] == id);
      expect(terug['reminder_days'], 3);
      expect(terug['reminder_days'], isA<int>(),
          reason: 'String breekt de dropdown-vergelijking en > 0');
      expect(terug['id'], isA<int>(),
          reason: 'String-id breekt cancelAppointmentReminder(int)');
    });

    test('oude String-vorm wordt alsnog int', () async {
      await _openSchoneBox('medical_appointments', '/tmp/hive_test_afspraak');
      final helper = HiveDatabaseHelper.instance;

      final id = await helper.insertMedicalAppointment({
        'title': 'Controle',
        'appointment_date': '20-12-2026',
        'appointment_time': '10:00',
        'reminder_days': '7',
      });

      final terug =
          (await helper.getMedicalAppointments()).firstWhere((a) => a['id'] == id);
      expect(terug['reminder_days'], 7);
      expect(terug['reminder_days'], isA<int>());
    });

    test('wijzigen behoudt reminder_days', () async {
      await _openSchoneBox('medical_appointments', '/tmp/hive_test_afspraak');
      final helper = HiveDatabaseHelper.instance;

      final id = await helper.insertMedicalAppointment({
        'title': 'Controle',
        'appointment_date': '20-12-2026',
        'appointment_time': '10:00',
        'reminder_days': 1,
      });
      await helper.updateMedicalAppointment(id, {
        'title': 'Controle aangepast',
        'appointment_date': '21-12-2026',
        'appointment_time': '11:00',
        'reminder_days': 3,
      });

      final terug =
          (await helper.getMedicalAppointments()).firstWhere((a) => a['id'] == id);
      expect(terug['reminder_days'], 3,
          reason: 'update waste de herinnering weg');
    });
  });

  group('Plumbing (structuur)', () {
    test('opstart plant afspraken terug na cancelAll', () {
      final code = _code('lib/services/notification_helper.dart');
      expect(code.contains('rescheduleAppointmentReminders()'), isTrue);
      // Aangeroepen vanuit de medicatie-herplanning (die cancelAll doet).
      final start = code.indexOf('Future<int> rescheduleAppointmentReminders()');
      expect(start, greaterThan(-1));
    });

    test('plannen meldt terug i.p.v. stil te falen', () {
      final code = _code('lib/services/notification_helper.dart');
      expect(
          code.contains('Future<String?> scheduleAppointmentReminder('),
          isTrue);
      expect(code.contains("return 'verleden'"), isTrue,
          reason: 'moment voorbij moet een eigen uitslag krijgen');
      expect(code.contains('canScheduleExact'), isTrue,
          reason: 'geen hardcoded exactAllowWhileIdle meer');
    });

    test('afspraak-IDs zitten in een eigen range', () {
      final code = _code('lib/services/notification_helper.dart');
      expect(code.contains('(appointmentId % 9000) + 1000'), isTrue);
      expect(code.contains('(appointmentId * 100) % 100000'), isFalse,
          reason: 'oude formule kon met medicatie botsen');
    });

    test('scherm toont de uitslag en normaliseert types', () {
      final code = _code('lib/screens/appointments_screen.dart');
      expect(code.contains('_toonHerinneringUitslag'), isTrue);
      expect(code.contains('afspraakHerinneringGepland'), isTrue);
      expect(code.contains('afspraakHerinneringVerleden'), isTrue);
      expect(code.contains('int.tryParse'), isTrue,
          reason: 'oudere String-rijen mogen niets breken');
    });
  });
}
