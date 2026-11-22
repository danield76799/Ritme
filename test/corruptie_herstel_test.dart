// Test voor het corruptie-vangnet: een beschadigd box-bestand mag de app
// niet crashen, en de app moet kunnen zien dat er herstel heeft plaatsgevonden
// (zodat de gebruiker een backup kan terugzetten).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:ritme/database/hive_database_helper.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ritme_corrupt');
    // Schrijf een "kapot" settings-bestand: willekeurige bytes, geen geldige frames.
    final kapot = File('${dir.path}/settings.hive');
    await kapot.writeAsBytes(List<int>.generate(512, (i) => (i * 37) % 256));
    Hive.init(dir.path);
    HiveDatabaseHelper.debugHiveDir = dir.path;
    HiveDatabaseHelper.recoveredBoxes.clear();
  });

  tearDown(() {
    HiveDatabaseHelper.debugHiveDir = null;
  });

  test('corrupte box crasht de app niet en wordt gedetecteerd', () async {
    await HiveDatabaseHelper.init();

    expect(Hive.isBoxOpen('settings'), isTrue);
    expect(HiveDatabaseHelper.recoveredBoxes, contains('settings'),
        reason: 'de UI moet weten dat er data verloren is gegaan');
    // De app kan verder met een (lege) settings-box.
    await Hive.box('settings').put('probe', 'ok');
    expect(Hive.box('settings').get('probe'), 'ok');
  });
}
