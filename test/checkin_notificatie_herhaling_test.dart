// Reproduceert de "ik kom terug op het invulscherm"-bug op het
// OCHTEND- en AVONDscherm.
//
// KETEN (alle schakels los verifieerbaar):
//
//  1. initialize() in notification_helper.dart leest de launch-details van de
//     plugin. Bij een koude start vanuit een notificatie zet dat
//     _pendingCheckinRoute op /morning-checkin of /evening-checkin.
//  2. initialize() heeft GEEN idempotentie-guard en wordt twee keer
//     aangeroepen: main.dart:58 en dashboard_screen.dart:375
//     (_setupNotifications, vanuit initState).
//  3. De plugin bepaalt `didNotificationLaunchApp` uit
//     mainActivity.getIntent(). Die intent BLIJFT de notificatie-intent, dus
//     de tweede aanroep leest dezelfde payload opnieuw en zet de route nóg
//     eens klaar.
//  4. consumePendingCheckinRoute() wist de route bij het lezen, maar die
//     tweede initialize() zet hem daarna gewoon weer terug.
//  5. _openPendingCheckin() draait bij elke AppLifecycleState.resumed, dus de
//     volgende resume pusht het check-in scherm opnieuw — een leeg scherm
//     (Stap 1 van 6) met een terug-pijl.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _bron(String pad) => File(pad).readAsStringSync();

/// Body van initialize(), tot de volgende methode op hetzelfde niveau.
String _initBody(String helper) {
  final start = helper.indexOf('Future<void> initialize()');
  if (start < 0) return '';
  final rest = helper.substring(start + 1);
  final match = RegExp(r'\n  Future<').firstMatch(rest);
  final eind = match == null ? helper.length : start + 1 + match.start;
  return helper.substring(start, eind);
}

void main() {
  group('initialize() is idempotent', () {
    test('er is een guard die een tweede aanroep kortsluit', () {
      final body = _initBody(_bron('lib/services/notification_helper.dart'));
      expect(body, isNotEmpty, reason: 'initialize() niet gevonden');
      expect(
        RegExp(r'if \(_initialized\) return;').hasMatch(body),
        isTrue,
        reason: 'zonder guard leest een tweede initialize() de launch-details '
            'opnieuw en zet de check-in route nog eens klaar',
      );
      expect(body.contains('_initialized = true'), isTrue);
    });

    test('de launch-payload wordt maar één keer verwerkt', () {
      // De guard moet VÓÓR het lezen van de launch-details staan, anders is
      // de tweede aanroep alsnog schadelijk.
      final body = _initBody(_bron('lib/services/notification_helper.dart'));
      final guard = body.indexOf('if (_initialized) return;');
      final launch = body.indexOf('getNotificationAppLaunchDetails');
      expect(guard, greaterThan(-1));
      expect(launch, greaterThan(-1));
      expect(
        guard,
        lessThan(launch),
        reason: 'de guard hoort vóór het lezen van de launch-details',
      );
    });
  });

  group('de keten die de bug veroorzaakte is nog intact', () {
    test('main.dart en het dashboard initialiseren allebei — de guard vangt '
        'de tweede af', () {
      expect(
        _bron('lib/main.dart').contains('NotificationHelper.instance.initialize()'),
        isTrue,
        reason: 'koude start moet de launch-payload kunnen lezen',
      );
      expect(
        _bron('lib/screens/dashboard_screen.dart')
            .contains('NotificationHelper.instance.initialize()'),
        isTrue,
        reason: 'het dashboard moet notificaties kunnen opzetten (bv. na '
            'inloggen), maar de guard maakt de tweede keer een no-op',
      );
    });

    test('een resume pikt nog steeds een wachtende check-in op', () {
      final dash = _bron('lib/screens/dashboard_screen.dart');
      expect(dash.contains('_openPendingCheckin()'), isTrue);
      expect(
        RegExp(r'AppLifecycleState\.resumed').hasMatch(dash),
        isTrue,
        reason: 'de notificatie-tik moet blijven werken',
      );
    });

    test('de route wordt nog steeds verbruikt (niet blijven hangen)', () {
      final helper = _bron('lib/services/notification_helper.dart');
      expect(helper.contains('consumePendingCheckinRoute'), isTrue);
      expect(
        RegExp(r'_pendingCheckinRoute = null').hasMatch(helper),
        isTrue,
        reason: 'lezen moet wissen, anders herhaalt de navigatie zich',
      );
    });
  });
}
