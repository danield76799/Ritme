import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupService {
  /// Export all Hive boxes to a JSON map (runs in isolate)
  static Future<Map<String, dynamic>> exportAllData() async {
    return await compute(_exportDataInIsolate, null);
  }
  
  static Map<String, dynamic> _exportDataInIsolate(void _) {
    // List of all possible box names
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
    
    final export = <String, dynamic>{
      'export_date': DateTime.now().toIso8601String(),
      'app_version': '1.0.0',
      'data': {},
    };

    for (final boxName in boxNames) {
      try {
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
        }
      } catch (e) {
        debugPrint('BackupService: skipping box $boxName - $e');
      }
    }

    return export;
  }

  /// Save backup to local file
  static Future<String> saveLocalBackup() async {
    final data = await exportAllData();
    final jsonString = jsonEncode(data);
    
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/ritme_backup_$timestamp.json');
    
    await file.writeAsString(jsonString);
    return file.path;
  }

  /// Share backup via email or other apps
  static Future<void> shareBackup() async {
    final data = await exportAllData();
    final jsonString = jsonEncode(data);
    
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/ritme_backup_$timestamp.json');
    
    await file.writeAsString(jsonString);
    
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Ritme Backup ${DateTime.now().toString().split(' ')[0]}',
      text: 'Hier is mijn Ritme app backup. Bewaar deze veilig!',
    );
  }

  /// Restore data from JSON map
  static Future<void> restoreFromData(Map<String, dynamic> data) async {
    final boxesData = data['data'] as Map<String, dynamic>?;
    if (boxesData == null) throw Exception('Invalid backup format');

    for (final entry in boxesData.entries) {
      final boxName = entry.key;
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
