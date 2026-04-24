import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ritme.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. settings - gebruiker + target tijden
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        pin_hash TEXT,
        target_wake_time TEXT,
        target_sleep_time TEXT,
        target_morning_routine INTEGER,
        target_evening_routine INTEGER,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 2. daily_logs - dagelijkse stemming/slaap
    await db.execute('''
      CREATE TABLE daily_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        mood_score INTEGER,
        sleep_quality INTEGER,
        sleep_hours REAL,
        wake_time TEXT,
        sleep_time TEXT,
        energy_level INTEGER,
        irritability INTEGER,
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 3. srm_activities - activiteiten metingen
    await db.execute('''
      CREATE TABLE srm_activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        activity_type TEXT NOT NULL,
        start_time TEXT,
        end_time TEXT,
        duration_minutes INTEGER,
        intensity INTEGER,
        social_contact INTEGER,
        satisfaction INTEGER,
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 4. medication_config - medicatie setup
    await db.execute('''
      CREATE TABLE medication_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        dosage TEXT,
        frequency TEXT,
        morning_time TEXT,
        afternoon_time TEXT,
        evening_time TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 5. medication_intake - inname tracking
    await db.execute('''
      CREATE TABLE medication_intake (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medication_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        time_slot TEXT NOT NULL,
        taken INTEGER NOT NULL DEFAULT 0,
        taken_at TEXT,
        skipped INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (medication_id) REFERENCES medication_config(id)
      )
    ''');

    // 6. life_events - life chart gebeurtenissen
    await db.execute('''
      CREATE TABLE life_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        event_type TEXT NOT NULL,
        impact_level INTEGER,
        description TEXT,
        category TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Insert default user voor eerste gebruik
    await db.insert('settings', {
      'username': 'gebruiker',
      'pin_hash': null,
      'target_wake_time': '07:00',
      'target_sleep_time': '23:00',
      'target_morning_routine': 30,
      'target_evening_routine': 30,
    });
  }

  // Settings queries
  Future<Map<String, dynamic>?> getSettings() async {
    final db = await database;
    final results = await db.query('settings', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<bool> validateLogin(String username, String pin) async {
    final db = await database;
    final results = await db.query(
      'settings',
      where: 'username = ? AND pin_hash = ?',
      whereArgs: [username, pin],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  Future<bool> hasPinSet() async {
    final db = await database;
    final results = await db.query(
      'settings',
      where: 'pin_hash IS NOT NULL',
      limit: 1,
    );
    return results.isNotEmpty;
  }

  Future<int> updatePin(String pin) async {
    final db = await database;
    return await db.update(
      'settings',
      {'pin_hash': pin, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = 1',
    );
  }

  Future<int> updateSettings(Map<String, dynamic> values) async {
    final db = await database;
    values['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'settings',
      values,
      where: 'id = 1',
    );
  }

  // Daily logs queries
  Future<int> insertDailyLog(Map<String, dynamic> log) async {
    final db = await database;
    return await db.insert('daily_logs', log);
  }

  Future<int> updateDailyLog(String date, Map<String, dynamic> log) async {
    final db = await database;
    log['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'daily_logs',
      log,
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  Future<int> upsertDailyLog(Map<String, dynamic> log) async {
    final existing = await getDailyLog(log['date'] as String);
    if (existing != null) {
      return await updateDailyLog(log['date'] as String, log);
    } else {
      return await insertDailyLog(log);
    }
  }

  Future<List<Map<String, dynamic>>> getDailyLogs({int limit = 30}) async {
    final db = await database;
    return await db.query(
      'daily_logs',
      orderBy: 'date DESC',
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> getDailyLog(String date) async {
    final db = await database;
    final results = await db.query(
      'daily_logs',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // SRM Activities queries
  Future<int> insertActivity(Map<String, dynamic> activity) async {
    final db = await database;
    return await db.insert('srm_activities', activity);
  }

  Future<int> updateActivity(int id, Map<String, dynamic> activity) async {
    final db = await database;
    return await db.update(
      'srm_activities',
      activity,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteActivity(int id) async {
    final db = await database;
    return await db.delete(
      'srm_activities',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getActivities(String date) async {
    final db = await database;
    return await db.query(
      'srm_activities',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'start_time ASC',
    );
  }

  // Medication queries
  Future<int> insertMedication(Map<String, dynamic> med) async {
    final db = await database;
    return await db.insert('medication_config', med);
  }

  Future<List<Map<String, dynamic>>> getMedications() async {
    final db = await database;
    return await db.query(
      'medication_config',
      where: 'active = 1',
      orderBy: 'name ASC',
    );
  }

  Future<int> updateMedication(int id, Map<String, dynamic> med) async {
    final db = await database;
    med['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'medication_config',
      med,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deactivateMedication(int id) async {
    final db = await database;
    return await db.update(
      'medication_config',
      {
        'active': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getMedicationById(int id) async {
    final db = await database;
    final results = await db.query(
      'medication_config',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> insertMedicationIntake(Map<String, dynamic> intake) async {
    final db = await database;
    return await db.insert('medication_intake', intake);
  }

  Future<Map<String, dynamic>?> getMedicationIntake(int medicationId, String date, String timeSlot) async {
    final db = await database;
    final results = await db.query(
      'medication_intake',
      where: 'medication_id = ? AND date = ? AND time_slot = ?',
      whereArgs: [medicationId, date, timeSlot],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> upsertMedicationIntake(Map<String, dynamic> intake) async {
    final existing = await getMedicationIntake(
      intake['medication_id'] as int,
      intake['date'] as String,
      intake['time_slot'] as String,
    );
    if (existing != null) {
      final db = await database;
      return await db.update(
        'medication_intake',
        {
          'taken': intake['taken'],
          'taken_at': intake['taken_at'],
          'skipped': intake['skipped'] ?? 0,
          'notes': intake['notes'],
        },
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
    } else {
      return await insertMedicationIntake(intake);
    }
  }

  Future<List<Map<String, dynamic>>> getMedicationIntakesForDate(String date) async {
    final db = await database;
    return await db.query(
      'medication_intake',
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  // Life events queries
  Future<int> insertLifeEvent(Map<String, dynamic> event) async {
    final db = await database;
    return await db.insert('life_events', event);
  }

  Future<int> updateLifeEvent(int id, Map<String, dynamic> event) async {
    final db = await database;
    return await db.update(
      'life_events',
      event,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteLifeEvent(int id) async {
    final db = await database;
    return await db.delete(
      'life_events',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getLifeEvents({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'life_events',
      orderBy: 'date DESC',
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> getLifeEventById(int id) async {
    final db = await database;
    final results = await db.query(
      'life_events',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
