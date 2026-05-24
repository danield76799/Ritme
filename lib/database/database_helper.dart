import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_repository.dart';
import '../utils/security_helper.dart';

class DatabaseHelper implements DatabaseRepository {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ritme_clean.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dbDir = Directory(p.join(appDir.path, 'databases'));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    final path = p.join(dbDir.path, filePath);
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      readOnly: false,
      singleInstance: true,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE daily_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        uren_slaap REAL,
        bed_time TEXT,
        wake_time TEXT,
        awake_minutes INTEGER DEFAULT 0,
        sleep_hours REAL,
        stemming_hoog REAL DEFAULT 0,
        stemming_laag REAL DEFAULT 0,
        gesplitste_stemming INTEGER DEFAULT 0,
        ontstemde_manie INTEGER DEFAULT 0,
        stemmingsomslagen INTEGER DEFAULT 0,
        daglicht INTEGER DEFAULT 0,
        sociale_contacten INTEGER DEFAULT 0,
        alcohol_middelen INTEGER DEFAULT 0,
        menstruatie INTEGER DEFAULT 0,
        gewicht REAL,
        medication TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE srm_activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        activity_type TEXT NOT NULL,
        actual_time TEXT,
        target_time TEXT,
        p_score INTEGER DEFAULT 1,
        srt_point INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE medication_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        naam TEXT NOT NULL,
        dosering TEXT,
        eenheid TEXT,
        reminder_enabled INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE medication_schedule (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medication_id INTEGER NOT NULL,
        reminder_time TEXT,
        days_of_week TEXT DEFAULT '1,2,3,4,5,6,7',
        enabled INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE medication_intake (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medication_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        aantal_ingenomen INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        username TEXT PRIMARY KEY,
        password_hash TEXT,
        target_opstaan TEXT,
        target_slapen TEXT,
        target_contact TEXT,
        target_werk TEXT,
        target_eten TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  // ===================
  // SETTINGS
  // ===================
  
  @override
  Future<Map<String, dynamic>?> getSettings() async {
    final db = await database;
    final results = await db.query('settings', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  @override
  Future<int> updateSettings(Map<String, dynamic> settings) async {
    final db = await database;
    final existing = await getSettings();
    if (existing != null) {
      return await db.update('settings', settings, where: 'username = ?', whereArgs: [existing['username']]);
    } else {
      return await db.insert('settings', settings);
    }
  }

  // ===================
  // DAILY LOGS - CLEAN
  // ===================
  
  @override
  Future<int> insertDailyLog(String date, Map<String, dynamic> data) async {
    final db = await database;
    data['date'] = date;
    return await db.insert('daily_logs', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<Map<String, dynamic>>> getDailyLogs() async {
    final db = await database;
    final logs = await db.query('daily_logs', orderBy: 'date DESC');
    
    // Return only the most recent entry per date
    Map<String, Map<String, dynamic>> latestByDate = {};
    for (var log in logs) {
      final date = log['date']?.toString();
      if (date != null && !latestByDate.containsKey(date)) {
        latestByDate[date] = log;
      }
    }
    return latestByDate.values.toList();
  }

  @override
  Future<Map<String, dynamic>?> getDailyLog(String date) async {
    final db = await database;
    final results = await db.query('daily_logs', where: 'date = ?', whereArgs: [date], orderBy: 'id DESC', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  @override
  Future<int> upsertDailyLog(Map<String, dynamic> data) async {
    final db = await database;
    final date = data['date'] as String;
    final existing = await db.query('daily_logs', where: 'date = ?', whereArgs: [date], orderBy: 'id DESC', limit: 1);
    
    if (existing.isNotEmpty) {
      final id = existing.first['id'];
      return await db.update('daily_logs', data, where: 'id = ?', whereArgs: [id]);
    } else {
      return await db.insert('daily_logs', data);
    }
  }

  // ===================
  // SLEEP - CLEAN
  // ===================
  
  @override
  Future<int> insertSleepLog(String date, String bedTime, String wakeTime, int awakeMinutes) async {
    final db = await database;
    
    // Calculate sleep hours
    final bedParts = bedTime.split(':');
    final wakeParts = wakeTime.split(':');
    int bedMin = int.parse(bedParts[0]) * 60 + int.parse(bedParts[1]);
    int wakeMin = int.parse(wakeParts[0]) * 60 + int.parse(wakeParts[1]);
    if (wakeMin < bedMin) wakeMin += 24 * 60;
    final sleepHours = (wakeMin - bedMin - awakeMinutes) / 60.0;
    
    final data = {
      'date': date,
      'bed_time': bedTime,
      'wake_time': wakeTime,
      'awake_minutes': awakeMinutes,
      'sleep_hours': sleepHours > 0 ? sleepHours : 0,
      'uren_slaap': sleepHours > 0 ? sleepHours : 0,
    };
    
    return await upsertDailyLog(data);
  }

  @override
  Future<Map<String, dynamic>?> getSleepLog(String date) async {
    final db = await database;
    final results = await db.query('daily_logs', where: 'date = ? AND bed_time IS NOT NULL', whereArgs: [date], orderBy: 'id DESC', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  // ===================
  // SRM ACTIVITIES
  // ===================
  
  @override
  Future<int> insertSrmActivity(String date, String activityType, String actualTime, int pScore, int? srtPoint) async {
    final db = await database;
    return await db.insert('srm_activities', {
      'date': date,
      'activity_type': activityType,
      'actual_time': actualTime,
      'p_score': pScore,
      'srt_point': srtPoint,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getSrmActivities(String date) async {
    final db = await database;
    return await db.query('srm_activities', where: 'date = ?', whereArgs: [date]);
  }

  // ===================
  // MEDICATION
  // ===================
  
  @override
  Future<int> insertMedicationConfig(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('medication_config', data);
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationConfigs() async {
    final db = await database;
    return await db.query('medication_config');
  }

  @override
  Future<int> insertMedicationSchedule(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('medication_schedule', data);
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationSchedules() async {
    final db = await database;
    return await db.query('medication_schedule');
  }

  @override
  Future<int> confirmMedicationIntake(String date, int medicationId, int confirmed) async {
    final db = await database;
    return await db.insert('medication_intake', {
      'medication_id': medicationId,
      'date': date,
      'aantal_ingenomen': confirmed,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakes(String date) async {
    final db = await database;
    return await db.query('medication_intake', where: 'date = ?', whereArgs: [date]);
  }

  // ===================
  // IMPORT / EXPORT
  // ===================
  
  @override
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('daily_logs');
    await db.delete('srm_activities');
    await db.delete('medication_config');
    await db.delete('medication_schedule');
    await db.delete('medication_intake');
    await db.delete('settings');
  }

  @override
  Future<Map<String, dynamic>> exportDatabaseToJson() async {
    final db = await database;
    final dailyLogs = await db.query('daily_logs');
    final srmActivities = await db.query('srm_activities');
    final medicationConfig = await db.query('medication_config');
    final medicationSchedule = await db.query('medication_schedule');
    final medicationIntake = await db.query('medication_intake');
    final settings = await db.query('settings');
    
    return {
      'daily_logs': dailyLogs,
      'srm_activities': srmActivities,
      'medication_config': medicationConfig,
      'medication_schedule': medicationSchedule,
      'medication_intake': medicationIntake,
      'settings': settings,
    };
  }

  @override
  Future<void> importDatabaseFromJson(String jsonString) async {
    final db = await database;
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    
    await clearAllData();
    
    for (final log in (data['daily_logs'] as List? ?? [])) {
      await db.insert('daily_logs', log as Map<String, dynamic>);
    }
    for (final activity in (data['srm_activities'] as List? ?? [])) {
      await db.insert('srm_activities', activity as Map<String, dynamic>);
    }
    for (final config in (data['medication_config'] as List? ?? [])) {
      await db.insert('medication_config', config as Map<String, dynamic>);
    }
    for (final schedule in (data['medication_schedule'] as List? ?? [])) {
      await db.insert('medication_schedule', schedule as Map<String, dynamic>);
    }
    for (final intake in (data['medication_intake'] as List? ?? [])) {
      await db.insert('medication_intake', intake as Map<String, dynamic>);
    }
    for (final setting in (data['settings'] as List? ?? [])) {
      await db.insert('settings', setting as Map<String, dynamic>);
    }
  }

  // Stub methods for compatibility
  @override Future<bool> hasPinSet() async => false;
  @override Future<bool> updatePin(String pin) async => true;
  @override Future<Map<String, dynamic>?> validateLoginPin(String pin) async => null;
  @override Future<List<Map<String, dynamic>>> getDailyLogsForWeek() async => getDailyLogs();
  @override Future<List<Map<String, dynamic>>> getScheduledMedicationsForToday() async => [];
  @override Future<List<Map<String, dynamic>>> getMedicalAppointments() async => [];
  @override Future<int> insertMedicalAppointment(Map<String, dynamic> data) async => 0;
  @override Future<List<Map<String, dynamic>>> getWeightLogs() async => [];
  @override Future<int> insertWeightLog(Map<String, dynamic> data) async => 0;
  @override Future<List<Map<String, dynamic>>> getLifeEvents() async => [];
  @override Future<int> insertLifeEvent(Map<String, dynamic> data) async => 0;
}
