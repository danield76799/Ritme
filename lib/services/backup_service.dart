import 'dart:convert';
import '../utils/notif_strings.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../utils/logger.dart';

class BackupService {
  static final DatabaseHelper _db = DatabaseHelper.instance;

  /// Export all data - SQLite AND Hive
  static Future<Map<String, dynamic>> exportAllData() async {
    final export = <String, dynamic>{
      'export_date': DateTime.now().toIso8601String(),
      'app_version': '1.0.0',
      'data': {},
    };

    // Export SQLite tables
    try {
      final dailyLogs = await _db.getDailyLogs();
      if (dailyLogs.isNotEmpty) {
        export['data']['sqlite_daily_logs'] = dailyLogs;
        debugPrint('BackupService: exported ${dailyLogs.length} daily logs from SQLite');
      }
    } catch (e) {
      debugPrint('BackupService: error exporting SQLite daily_logs - $e');
    }

    // Export appointments from Hive (not SQLite)
    try {
      if (Hive.isBoxOpen('medical_appointments')) {
        final box = Hive.box('medical_appointments');
        final appointments = <Map<String, dynamic>>[];
        for (final key in box.keys) {
          final value = box.get(key);
          if (value != null) {
            appointments.add(Map<String, dynamic>.from(value));
          }
        }
        if (appointments.isNotEmpty) {
          export['data']['medical_appointments'] = appointments;
          debugPrint('BackupService: exported ${appointments.length} appointments from Hive');
        }
      }
    } catch (e) {
      debugPrint('BackupService: error exporting Hive appointments - $e');
    }

    try {
      final srmActivities = await _db.getSrmActivities('');
      if (srmActivities.isNotEmpty) {
        export['data']['sqlite_srm_activities'] = srmActivities;
        debugPrint('BackupService: exported ${srmActivities.length} SRM activities from SQLite');
      }
    } catch (e) {
      debugPrint('BackupService: error exporting SQLite SRM activities - $e');
    }

    // Export SQLite settings (username, sleep times, etc.)
    try {
      final settings = await _db.getSettings();
      if (settings != null && settings.isNotEmpty) {
        export['data']['sqlite_settings'] = settings;
        debugPrint('BackupService: exported settings from SQLite: $settings');
      }
    } catch (e) {
      debugPrint('BackupService: error exporting SQLite settings - $e');
    }

    // Export Hive boxes
    final boxNames = [
      'settings',
      'daily_logs',
      'srm_activities',
      'medication_config',
      'medication_intake',
      'medication_schedule',
      'life_events',
      'weight_logs',
      'medical_appointments',
      'daily_dagboek',
    ];

    for (final boxName in boxNames) {
      try {
        if (!Hive.isBoxOpen(boxName)) {
          debugPrint('BackupService: box $boxName not open, skipping');
          continue;
        }
        final box = Hive.box(boxName);
        final boxData = <String, dynamic>{};
        for (final key in box.keys) {
          final value = box.get(key);
          if (value != null) {
            boxData[key.toString()] = value;
          }
        }
        if (boxData.isNotEmpty) {
          export['data'][boxName] = boxData;
          debugPrint('BackupService: exported ${boxData.length} items from Hive box $boxName');
        }
      } catch (e) {
        debugPrint('BackupService: skipping box $boxName - $e');
      }
    }

    return export;
  }

  /// Save backup to Downloads folder (direct, no share sheet)
  ///
  /// Met [auto] = true krijgt het bestand de weeknaam
  /// (`ritme_backup_auto_2026-W38.json`, zie [autoBackupBestandsnaam]) en
  /// wordt het bij elke run in die week overschreven. Handmatige backups
  /// houden hun timestamp-naam en blijven altijd staan.
  static Future<String> saveLocalBackup({bool auto = false}) async {
    final data = await exportAllData();
    final jsonString = jsonEncode(data);

    final bestandsnaam = auto
        ? autoBackupBestandsnaam(DateTime.now())
        : "ritme_backup_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0]}.json";

    // Schrijven naar Downloads lukt op moderne Android (scoped storage,
    // targetSdk 36) niet via een raw path — writeAsString gooit dan. Daarom:
    // eerst Downloads proberen, bij een schrijffout terugvallen op de
    // app-map (altijd schrijfbaar). Zonder deze terugval faalde de
    // automatische backup bij ELKE opstart stil (09-2026).
    final pogingen = <Directory>[];
    try {
      if (Platform.isAndroid) {
        final downloads = Directory('/storage/emulated/0/Download');
        if (downloads.existsSync()) {
          pogingen.add(downloads);
        } else {
          final sdcard = Directory('/sdcard/Download');
          if (sdcard.existsSync()) pogingen.add(sdcard);
        }
      }
    } catch (e) {
      debugPrint('BackupService: Downloads niet bereikbaar, terugval - $e');
    }
    pogingen.add(await getApplicationDocumentsDirectory());

    File? gelukt;
    Object? laatsteFout;
    for (final dir in pogingen) {
      try {
        final file = File('${dir.path}/$bestandsnaam');
        await file.writeAsString(jsonString);
        gelukt = file;
        break;
      } catch (e) {
        laatsteFout = e;
      }
    }
    if (gelukt == null) {
      throw Exception('Backup schrijven mislukt (ook terugval): $laatsteFout');
    }
    final file = gelukt;

    // Alleen bij auto: maximaal [behoud] automatische weekbestanden bewaren.
    // Handmatige backups blijven altijd staan. Opruimen gebeurt in BEIDE
    // mappen (oude weken kunnen nog in Downloads staan van vóór de terugval).
    if (auto) {
      for (final dir in pogingen) {
        await ruimOudeAutoBackupsOp(dir);
      }
    }

    return file.path;
  }

  /// Share backup via email or other apps
  static Future<void> shareBackup() async {
    final data = await exportAllData();
    final jsonString = jsonEncode(data);
    
    // Try to save to Downloads folder first
    String filePath;
    try {
      final dir = await getExternalStorageDirectory();
      if (dir != null) {
        final downloadsPath = dir.path.replaceAll('/Android/data/com.danield.ritme/files', '/Download');
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
        final file = File('$downloadsPath/ritme_backup_$timestamp.json');
        await file.writeAsString(jsonString);
        filePath = file.path;
      } else {
        throw Exception('No external storage');
      }
    } catch (e) {
      // Fallback
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File('${dir.path}/ritme_backup_$timestamp.json');
      await file.writeAsString(jsonString);
      filePath = file.path;
    }
    
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Ritme Backup ${DateTime.now().toString().split(' ')[0]}',
      text: NotifStrings.backupText,
    );
  }

  /// Restore data from JSON map
  static Future<void> restoreFromData(Map<String, dynamic> data) async {
    final boxesData = data['data'] as Map<String, dynamic>?;
    if (boxesData == null) throw Exception('Invalid backup format');

    // Restore SQLite settings first (username, sleep times, etc.)
    if (boxesData.containsKey('sqlite_settings')) {
      try {
        final settingsData = boxesData['sqlite_settings'] as Map<String, dynamic>;
        await _db.updateSettingsMap(settingsData);
        debugPrint('BackupService: restored SQLite settings: $settingsData');
      } catch (e) {
        debugPrint('BackupService: error restoring SQLite settings - $e');
      }
    }

    // Restore SQLite tables
    if (boxesData.containsKey('sqlite_daily_logs')) {
      try {
        final logs = boxesData['sqlite_daily_logs'] as List<dynamic>;
        for (final log in logs) {
          await _db.upsertDailyLog(log as Map<String, dynamic>);
        }
        debugPrint('BackupService: restored ${logs.length} daily logs');
      } catch (e) {
        debugPrint('BackupService: error restoring daily logs - $e');
      }
    }

    // Restore appointments from Hive
    if (boxesData.containsKey('medical_appointments')) {
      try {
        if (Hive.isBoxOpen('medical_appointments')) {
          final box = Hive.box('medical_appointments');
          final appointments = boxesData['medical_appointments'] as List<dynamic>;
          await box.clear();
          for (final appt in appointments) {
            await box.put(appt['id'], appt);
          }
          debugPrint('BackupService: restored ${appointments.length} appointments to Hive');
        }
      } catch (e) {
        debugPrint('BackupService: error restoring appointments - $e');
      }
    }

    if (boxesData.containsKey('sqlite_srm_activities')) {
      try {
        final activities = boxesData['sqlite_srm_activities'] as List<dynamic>;
        for (final activity in activities) {
          await _db.insertSrmActivityMap(activity as Map<String, dynamic>);
        }
        debugPrint('BackupService: restored ${activities.length} SRM activities');
      } catch (e) {
        debugPrint('BackupService: error restoring SRM activities - $e');
      }
    }

    // Restore Hive boxes
    for (final entry in boxesData.entries) {
      final boxName = entry.key;
      // Skip SQLite entries already handled above
      if (boxName.startsWith('sqlite_')) continue;
      
      final boxData = entry.value as Map<String, dynamic>;
      
      try {
        // Check if box is open, skip if not
        if (!Hive.isBoxOpen(boxName)) {
          debugPrint('BackupService: box $boxName not open, skipping');
          continue;
        }
        final box = Hive.box(boxName);
        await box.clear();
        for (final item in boxData.entries) {
          await box.put(item.key, item.value);
        }
        debugPrint('BackupService: restored box $boxName');
      } catch (e) {
        debugPrint('BackupService: error restoring box $boxName - $e');
      }
    }
  }

  /// Restore from local file
  static Future<void> restoreFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('File not found');

    final jsonString = await file.readAsString();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    await restoreFromData(data);
  }

  // ===================
  // AUTOMATISCHE BACKUP
  // ===================

  /// Instelling-sleutels (vrije settings-map, zie HiveDatabaseHelper).
  static const autoBackupFreqKey = 'auto_backup_freq';
  static const lastAutoBackupKey = 'last_auto_backup';

  /// Toegestane frequenties. Standaard wekelijks: bij een verse installatie
  /// wordt er dan in ieder geval een backup gemaakt.
  static const freqStandaard = freqWeek;
  static const freqUit = 'uit';
  static const freqDagelijks = 'dagelijks';
  static const freq3Dagen = '3dagen';
  static const freqWeek = 'week';

  /// Aantal automatische weekbestanden dat bewaard blijft (oudste weken
  /// worden opgeruimd). Eén bestand per week, dus dit zijn weken.
  static const autoBackupBehoud = 4;

  /// Pure interval-logica, zonder DB — daarom direct unit-testbaar.
  ///
  /// Geeft true als er nog nooit een automatische backup was ([lastIso] null
  /// of onleesbaar) en de frequentie niet 'uit' staat, of als het interval
  /// sinds de laatste verstreken is.
  static bool autoBackupVerschuldigd(String freq, String? lastIso, DateTime now) {
    final interval = switch (freq) {
      freqDagelijks => const Duration(days: 1),
      freq3Dagen => const Duration(days: 3),
      freqWeek => const Duration(days: 7),
      _ => null,
    };
    if (interval == null) return false;
    if (lastIso == null || lastIso.isEmpty) return true;
    final last = DateTime.tryParse(lastIso);
    if (last == null) return true;
    return now.difference(last) >= interval;
  }

  /// Draait bij het opstarten (zie main): maakt een automatische backup als
  /// het interval verstreken is. Geeft true terug als er een backup gemaakt
  /// is. Gooit nooit — een mislukte backup mag de opstart niet breken.
  static Future<bool> maybeAutoBackup({DateTime? now}) async {
    try {
      final settings = await _db.getSettings();
      final freq = settings?[autoBackupFreqKey]?.toString() ?? freqStandaard;
      final last = settings?[lastAutoBackupKey]?.toString();
      if (!autoBackupVerschuldigd(freq, last, now ?? DateTime.now())) {
        return false;
      }
      await saveLocalBackup(auto: true);
      final merged = Map<String, dynamic>.from(settings ?? {});
      merged[lastAutoBackupKey] = (now ?? DateTime.now()).toIso8601String();
      await _db.updateSettingsMap(merged);
      debugPrint('BackupService: automatische backup gemaakt (freq=$freq)');
      return true;
    } catch (e, stackTrace) {
      // Nooit gooien (opstart!), maar wél loggen: stil falen kostte ons
      // weken ("nog nooit een backup") voordat iemand het zag.
      AppLogger.error('BackupService: automatische backup mislukt',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Bestandsnaam voor de automatische backup: één bestand per ISO-week
  /// (`ritme_backup_auto_2026-W38.json`), dat bij elke run in die week
  /// overschreven wordt. Zo hoopt Downloads nooit vol met timestamps.
  ///
  /// Het jaar is het ISO-weekjaar (de donderdag bepaalt): 29-12-2025 valt
  /// in week 1 van 2026 en heet dus `2026-W01`.
  static String autoBackupBestandsnaam(DateTime now) {
    final donderdag = now.add(Duration(days: 4 - now.weekday));
    final weekjaar = donderdag.year;
    final week = isoWeekNummer(now);
    return 'ritme_backup_auto_${weekjaar}-W${week.toString().padLeft(2, '0')}.json';
  }

  /// ISO-8601-weeknummer (1-53), zonder pakket nodig.
  ///
  /// Let op: gerekend in UTC-dagen. Met lokale middernachten sluipt de
  /// zomertijd-overgang erin (259 dagen − 1 uur → inDays = 258), waardoor
  /// het weeknummer van het tijdstip op de dag zou afhangen.
  static int isoWeekNummer(DateTime datum) {
    final donderdag = datum.add(Duration(days: 4 - datum.weekday));
    final d0 = DateTime.utc(donderdag.year, donderdag.month, donderdag.day);
    final j0 = DateTime.utc(donderdag.year, 1, 1);
    return (d0.difference(j0).inDays ~/ 7) + 1;
  }

  /// Ruimt oude automatische weekbestanden op tot [behoud] stuks (nieuwste
  /// weken blijven). Raakt handmatige backups (`ritme_backup_*.json` zonder
  /// `_auto`) niet aan.
  static Future<void> ruimOudeAutoBackupsOp(Directory dir, {int behoud = autoBackupBehoud}) async {
    try {
      if (!await dir.exists()) return;
      final autos = await dir
          .list()
          .where((e) => e is File && e.path.contains('ritme_backup_auto_') && e.path.endsWith('.json'))
          .cast<File>()
          .toList();
      if (autos.length <= behoud) return;
      final stats = <File, DateTime>{};
      for (final f in autos) {
        stats[f] = (await f.stat()).modified;
      }
      autos.sort((a, b) => stats[a]!.compareTo(stats[b]!));
      for (final oud in autos.take(autos.length - behoud)) {
        await oud.delete();
      }
      debugPrint('BackupService: ${autos.length - behoud} oude auto-backups opgeruimd');
    } catch (e) {
      debugPrint('BackupService: opruimen auto-backups mislukt (niet-fataal) - $e');
    }
  }
}
