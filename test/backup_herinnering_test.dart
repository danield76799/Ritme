// De backup-herinnering plant zichzelf 14 dagen na de laatste backup,
// om 10:00 lokale tijd, en schuift zichzelf op als de datum in het verleden ligt.

import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/services/notification_helper.dart';

void main() {
  final nu = DateTime(2026, 11, 22, 12, 0); // zondag 22 nov 2026, 12:00

  test('zonder eerdere backup: 14 dagen vanaf nu, om 10:00', () {
    final next = NotificationHelper.volgendeBackupHerinnering(nu, null);
    expect(next, DateTime(2026, 12, 6, 10));
  });

  test('backup 10 dagen geleden: herinnering op dag 14 na die backup', () {
    final laatste = DateTime(2026, 11, 12, 18, 30);
    final next = NotificationHelper.volgendeBackupHerinnering(nu, laatste);
    expect(next, DateTime(2026, 11, 26, 10));
  });

  test('backup 20 dagen geleden: herinnering schuift door naar de toekomst', () {
    final laatste = DateTime(2026, 11, 2, 9, 0);
    final next = NotificationHelper.volgendeBackupHerinnering(nu, laatste);
    // 11-16 is de eerste 14d-stap na 11-02 die nog in het verleden ligt;
    // 11-30 10:00 is de eerste die in de toekomst ligt t.o.v. 22-11 12:00.
    expect(next.isAfter(nu), isTrue);
    expect(next, DateTime(2026, 11, 30, 10));
  });

  test('exacte vervaldatum om 10:00 telt als verlopen, niet als "nu"', () {
    final laatste = DateTime(2026, 11, 8, 10); // +14d == nu (22 nov 10:00 < nu)
    final next = NotificationHelper.volgendeBackupHerinnering(nu, laatste);
    expect(next, DateTime(2026, 12, 6, 10));
  });
}
