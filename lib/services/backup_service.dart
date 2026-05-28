import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';

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

    try {
      final appointments = await _db.getMedicalAppointments();
      if (appointments.isNotEmpty) {
        export['data']['sqlite_appointments'] = appointments;
        debugPrint('BackupService: exported ${appointments.length} appointments from SQLite');
      }
    } catch (e) {
      debugPrint('BackupService: error exporting SQLite appointments - $e');
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
  static Future<String> saveLocalBackup() async {
    final data = await exportAllData();
    final jsonString = jsonEncode(data);
    
    // Try to save directly to Downloads
    Directory? downloadsDir;
    try {
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!downloadsDir.existsSync()) {
          downloadsDir = Directory('/sdcard/Download');
        }
      }
    } catch (e) {
      debugPrint('BackupService: Could not access Downloads, falling back');
    }
    
    final dir = downloadsDir ?? await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final file = File('${dir.path}/ritme_backup_$timestamp.json');
    await file.writeAsString(jsonString);
    
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
      text: 'Hier is mijn Ritme app backup. Bewaar deze veilig!',
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

    if (boxesData.containsKey('sqlite_appointments')) {
      try {
        final appointments = boxesData['sqlite_appointments'] as List<dynamic>;
        for (final appt in appointments) {
          await _db.insertMedicalAppointment(appt as Map<String, dynamic>);
        }
        debugPrint('BackupService: restored ${appointments.length} appointments');
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
}
