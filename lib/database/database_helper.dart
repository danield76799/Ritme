import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'database_repository.dart';

class DatabaseHelper implements DatabaseRepository {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ritme_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);
    return await openDatabase(path, version: 2, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE weight_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          weight REAL NOT NULL,
          notes TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE medical_appointments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          doctor_name TEXT,
          location TEXT,
          appointment_date TEXT NOT NULL,
          appointment_time TEXT,
          notes TEXT,
          reminder_enabled INTEGER DEFAULT 1,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        target_opstaan TEXT,
        target_contact TEXT,
        target_werk TEXT,
        target_eten TEXT,
        target_slapen TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_logs (
        date TEXT PRIMARY KEY,
        uren_slaap REAL,
        stemming_ochtend INTEGER,
        stemming_avond INTEGER,
        ontstemde_manie INTEGER DEFAULT 0,
        stemmingsomslagen INTEGER DEFAULT 0,
        alcohol_middelen INTEGER DEFAULT 0,
        menstruatie INTEGER DEFAULT 0,
        andere_klachten TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE srm_activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        activity_type TEXT NOT NULL,
        actual_time TEXT,
        p_score INTEGER,
        srt_point INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE medication_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        naam TEXT NOT NULL,
        dosering TEXT,
        eenheid TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE medication_schedule (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medication_id INTEGER,
        reminder_time TEXT NOT NULL,
        days_of_week TEXT DEFAULT '1,2,3,4,5,6,7',
        enabled INTEGER DEFAULT 1,
        FOREIGN KEY (medication_id) REFERENCES medication_config(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE medication_intake (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        medication_id INTEGER,
        aantal_ingenomen INTEGER,
        confirmed INTEGER DEFAULT 0,
        confirmed_at TEXT,
        FOREIGN KEY (medication_id) REFERENCES medication_config(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE weight_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        weight REAL NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE medical_appointments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        doctor_name TEXT,
        location TEXT,
        appointment_date TEXT NOT NULL,
        appointment_time TEXT,
        notes TEXT,
        reminder_enabled INTEGER DEFAULT 1,
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
  Future<int> insertSettings(Map<String, dynamic> settings) async {
    final db = await database;
    return await db.insert('settings', settings);
  }

  @override
  Future<int> updateSettings(String username, Map<String, dynamic> settings) async {
    final db = await database;
    return await db.update('settings', settings, where: 'username = ?', whereArgs: [username]);
  }

  @override
  Future<int> updateSettingsMap(Map<String, dynamic> settings) async {
    final db = await database;
    return await db.update('settings', settings, where: 'username = ?', whereArgs: ['user']);
  }

  @override
  Future<bool> hasPinSet() async {
    final settings = await getSettings();
    return settings != null && settings['password_hash'] != null;
  }

  @override
  Future<bool> updatePin(String pin) async {
    const username = 'user';
    return await setPin(username, pin);
  }

  Future<bool> setPin(String username, String passwordHash) async {
    final db = await database;
    final existing = await getSettings();
    if (existing != null) {
      await db.update('settings', {'password_hash': passwordHash}, where: 'username = ?', whereArgs: [username]);
    } else {
      await db.insert('settings', {'username': username, 'password_hash': passwordHash});
    }
    return true;
  }

  @override
  Future<Map<String, dynamic>?> validateLoginPin(String pin) async {
    final db = await database;
    final results = await db.query(
      'settings',
      where: 'username = ? AND password_hash = ?',
      whereArgs: ['user', pin],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // ===================
  // DAILY LOGS
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
    return await db.query('daily_logs', orderBy: 'date ASC');
  }

  @override
  Future<Map<String, dynamic>?> getDailyLog(String date) async {
    final db = await database;
    final results = await db.query('daily_logs', where: 'date = ?', whereArgs: [date], limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  @override
  Future<int> upsertDailyLog(Map<String, dynamic> data) async {
    final date = data['date'] as String;
    return await insertDailyLog(date, data);
  }

  // ===================
  // SRM ACTIVITIES
  // ===================
  
  @override
  Future<int> insertSrmActivity(String date, String activityType, String? actualTime, int? pScore, int? srtPoint) async {
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
  Future<int> insertSrmActivityMap(Map<String, dynamic> data) async {
    return await insertSrmActivity(
      data['date'] as String,
      data['activity_type'] as String,
      data['actual_time'] as String?,
      data['p_score'] as int?,
      data['srt_point'] as int?,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getSrmActivities(String date) async {
    final db = await database;
    return await db.query('srm_activities', where: 'date = ?', whereArgs: [date]);
  }

  // ===================
  // MEDICATION CONFIG
  // ===================
  
  @override
  Future<String> exportDatabaseToJson() async {
    final db = await database;
    
    final Map<String, dynamic> result = {
      'export_date': DateTime.now().toIso8601String(),
      'app_version': '1.2.0',
      'tables': <String, dynamic>{},
    };
    
    // Export all tables
    (result['tables'] as Map<String, dynamic>)['settings'] = await db.query('settings');
    (result['tables'] as Map<String, dynamic>)['daily_logs'] = await db.query('daily_logs');
    (result['tables'] as Map<String, dynamic>)['srm_activities'] = await db.query('srm_activities');
    (result['tables'] as Map<String, dynamic>)['medication_config'] = await db.query('medication_config');
    (result['tables'] as Map<String, dynamic>)['medication_intake'] = await db.query('medication_intake');
    (result['tables'] as Map<String, dynamic>)['life_events'] = await db.query('life_events');
    (result['tables'] as Map<String, dynamic>)['weight_logs'] = await db.query('weight_logs');
    (result['tables'] as Map<String, dynamic>)['medical_appointments'] = await db.query('medical_appointments');
    
    return jsonEncode(result);
  }

  @override
  Future<void> importDatabaseFromJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final tables = data['tables'] as Map<String, dynamic>;
    
    final db = await database;
    
    // Clear all data first
    await clearAllData();
    
    // Import each table
    if (tables['settings'] != null) {
      for (var row in tables['settings'] as List) {
        await db.insert('settings', row as Map<String, dynamic>);
      }
    }
    if (tables['daily_logs'] != null) {
      for (var row in tables['daily_logs'] as List) {
        await db.insert('daily_logs', row as Map<String, dynamic>);
      }
    }
    if (tables['srm_activities'] != null) {
      for (var row in tables['srm_activities'] as List) {
        await db.insert('srm_activities', row as Map<String, dynamic>);
      }
    }
    if (tables['medication_config'] != null) {
      for (var row in tables['medication_config'] as List) {
        await db.insert('medication_config', row as Map<String, dynamic>);
      }
    }
    if (tables['medication_intake'] != null) {
      for (var row in tables['medication_intake'] as List) {
        await db.insert('medication_intake', row as Map<String, dynamic>);
      }
    }
    if (tables['life_events'] != null) {
      for (var row in tables['life_events'] as List) {
        await db.insert('life_events', row as Map<String, dynamic>);
      }
    }
    if (tables['weight_logs'] != null) {
      for (var row in tables['weight_logs'] as List) {
        await db.insert('weight_logs', row as Map<String, dynamic>);
      }
    }
    if (tables['medical_appointments'] != null) {
      for (var row in tables['medical_appointments'] as List) {
        await db.insert('medical_appointments', row as Map<String, dynamic>);
      }
    }
  }

  @override
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('daily_logs');
    await db.delete('srm_activities');
    await db.delete('medication_intake');
    await db.delete('medication_config');
    await db.delete('life_events');
    await db.delete('weight_logs');
    await db.delete('medical_appointments');
    await db.delete('settings');
  }

  @override
  Future<int> insertMedicationConfig(String naam, String? dosering, String? eenheid) async {
    final db = await database;
    return await db.insert('medication_config', {'naam': naam, 'dosering': dosering, 'eenheid': eenheid});
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationConfigs() async {
    final db = await database;
    return await db.query('medication_config');
  }

  // ===================
  // MEDICATION SCHEDULE
  // ===================
  
  @override
  Future<List<Map<String, dynamic>>> getMedicationSchedules() async {
    final db = await database;
    return await db.query('medication_schedule');
  }

  @override
  Future<int> insertMedicationSchedule(int medicationId, String reminderTime, String daysOfWeek) async {
    final db = await database;
    return await db.insert('medication_schedule', {
      'medication_id': medicationId,
      'reminder_time': reminderTime,
      'days_of_week': daysOfWeek,
      'enabled': 1,
    });
  }

  @override
  Future<int> updateMedicationSchedule(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('medication_schedule', data, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> deleteMedicationSchedule(int id) async {
    final db = await database;
    return await db.delete('medication_schedule', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Map<String, dynamic>>> getScheduledMedicationsForToday() async {
    final db = await database;
    final today = DateTime.now().weekday; // 1= Monday, 7=Sunday
    final allSchedules = await db.query('medication_schedule', where: 'enabled = ?', whereArgs: [1]);
    
    return allSchedules.where((schedule) {
      final days = (schedule['days_of_week'] as String).split(',');
      return days.contains(today.toString());
    }).toList();
  }

  @override
  Future<int> confirmMedicationIntake(String date, int medicationId, int confirmed) async {
    final db = await database;
    final existing = await db.query(
      'medication_intake',
      where: 'date = ? AND medication_id = ?',
      whereArgs: [date, medicationId],
      limit: 1,
    );
    
    if (existing.isNotEmpty) {
      return await db.update(
        'medication_intake',
        {'confirmed': confirmed, 'confirmed_at': DateTime.now().toIso8601String()},
        where: 'date = ? AND medication_id = ?',
        whereArgs: [date, medicationId],
      );
    } else {
      return await db.insert('medication_intake', {
        'date': date,
        'medication_id': medicationId,
        'aantal_ingenomen': 1,
        'confirmed': confirmed,
        'confirmed_at': confirmed == 1 ? DateTime.now().toIso8601String() : null,
      });
    }
  }

  // ===================
  // MEDICATION INTAKE
  // ===================
  
  @override
  Future<int> insertMedicationIntake(String date, int medicationId, int aantal) async {
    final db = await database;
    return await db.insert('medication_intake', {'date': date, 'medication_id': medicationId, 'aantal_ingenomen': aantal});
  }

  @override
  Future<int> insertMedicationIntakeMap(Map<String, dynamic> data) async {
    return await insertMedicationIntake(
      data['date'] as String,
      data['medication_id'] as int,
      data['aantal_ingenomen'] as int,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntake(String date) async {
    final db = await database;
    return await db.query('medication_intake', where: 'date = ?', whereArgs: [date]);
  }

  // ===================
  // LIFE EVENTS
  // ===================
  
  @override
  Future<int> insertLifeEvent(String date, String omschrijving, int invloed) async {
    final db = await database;
    return await db.insert('life_events', {'date': date, 'omschrijving': omschrijving, 'invloed': invloed});
  }

  @override
  Future<int> insertLifeEventMap(Map<String, dynamic> data) async {
    return await insertLifeEvent(
      data['date'] as String,
      data['omschrijving'] as String,
      data['invloed'] as int,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getLifeEvents(String date) async {
    final db = await database;
    return await db.query('life_events', where: 'date = ?', whereArgs: [date]);
  }

  // ===================
  // WEIGHT LOGS
  // ===================
  
  Future<int> insertWeightLog(String date, double weight, String? notes) async {
    final db = await database;
    return await db.insert('weight_logs', {'date': date, 'weight': weight, 'notes': notes});
  }

  Future<List<Map<String, dynamic>>> getWeightLogs() async {
    final db = await database;
    return await db.query('weight_logs', orderBy: 'date DESC');
  }

  Future<Map<String, dynamic>?> getLatestWeightLog() async {
    final db = await database;
    final results = await db.query('weight_logs', orderBy: 'date DESC', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> deleteWeightLog(int id) async {
    final db = await database;
    return await db.delete('weight_logs', where: 'id = ?', whereArgs: [id]);
  }

  // ===================
  // MEDICAL APPOINTMENTS
  // ===================
  
  Future<int> insertMedicalAppointment(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('medical_appointments', data);
  }

  Future<List<Map<String, dynamic>>> getMedicalAppointments() async {
    final db = await database;
    return await db.query('medical_appointments', orderBy: 'appointment_date ASC');
  }

  Future<List<Map<String, dynamic>>> getUpcomingAppointments() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    return await db.query(
      'medical_appointments',
      where: 'appointment_date >= ?',
      whereArgs: [today],
      orderBy: 'appointment_date ASC',
    );
  }

  Future<int> updateMedicalAppointment(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('medical_appointments', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteMedicalAppointment(int id) async {
    final db = await database;
    return await db.delete('medical_appointments', where: 'id = ?', whereArgs: [id]);
  }
}
