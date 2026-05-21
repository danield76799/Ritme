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
    try {
      _database = await _initDB('ritme_app.db');
      // Test if database is writable
      await _database!.execute('CREATE TABLE IF NOT EXISTS _test_write (id INTEGER PRIMARY KEY)');
      await _database!.execute('DROP TABLE IF EXISTS _test_write');
      return _database!;
    } catch (e) {
      print('CRITICAL: Database is read-only or corrupted: $e');
      // Return null to indicate database failure
      throw Exception('Database not writable: $e');
    }
  }

  Future<Database> _initDB(String filePath) async {
    // Use app documents directory for write access on all platforms
    final appDir = await getApplicationDocumentsDirectory();
    final dbDir = Directory(p.join(appDir.path, 'databases'));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    final path = p.join(dbDir.path, filePath);
    
    // Check if we need to migrate from old location
    final oldDbPath = p.join(await getDatabasesPath(), filePath);
    final oldDbFile = File(oldDbPath);
    if (await oldDbFile.exists()) {
      // Try to copy old database to new location
      try {
        await oldDbFile.copy(path);
        print('Migrated database from $oldDbPath to $path');
      } catch (e) {
        print('Failed to migrate database: $e');
      }
    }
    
    return await openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      readOnly: false,
      singleInstance: true,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS weight_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          weight REAL NOT NULL,
          notes TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS medical_appointments (
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
    
    // Add life_events table for version 3
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS life_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          omschrijving TEXT NOT NULL,
          invloed INTEGER NOT NULL
        )
      ''');
    }
    
    // Add sleep tracking columns for version 6
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE daily_logs ADD COLUMN bed_time TEXT');
      } catch (e) {
        print('bed_time column might already exist: $e');
      }
      try {
        await db.execute('ALTER TABLE daily_logs ADD COLUMN wake_time TEXT');
      } catch (e) {
        print('wake_time column might already exist: $e');
      }
      try {
        await db.execute('ALTER TABLE daily_logs ADD COLUMN awake_minutes INTEGER DEFAULT 0');
      } catch (e) {
        print('awake_minutes column might already exist: $e');
      }
      try {
        await db.execute('ALTER TABLE daily_logs ADD COLUMN sleep_hours REAL');
      } catch (e) {
        print('sleep_hours column might already exist: $e');
      }
    }
    
    // Add reminder_days column for medical_appointments (version 7)
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE medical_appointments ADD COLUMN reminder_days INTEGER DEFAULT 1');
      } catch (e) {
        print('reminder_days column might already exist: $e');
      }
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
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
      CREATE TABLE IF NOT EXISTS daily_logs (
        date TEXT PRIMARY KEY,
        uren_slaap REAL,
        bed_time TEXT,
        wake_time TEXT,
        awake_minutes INTEGER DEFAULT 0,
        sleep_hours REAL,
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
      CREATE TABLE IF NOT EXISTS srm_activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        activity_type TEXT NOT NULL,
        actual_time TEXT,
        p_score INTEGER,
        srt_point INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS medication_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        naam TEXT NOT NULL,
        dosering TEXT,
        eenheid TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS medication_schedule (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medication_id INTEGER,
        reminder_time TEXT NOT NULL,
        days_of_week TEXT DEFAULT '1,2,3,4,5,6,7',
        enabled INTEGER DEFAULT 1,
        FOREIGN KEY (medication_id) REFERENCES medication_config(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS medication_intake (
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
      CREATE TABLE IF NOT EXISTS weight_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        weight REAL NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS medical_appointments (
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

    // FIX: Added missing life_events table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS life_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        omschrijving TEXT NOT NULL,
        invloed INTEGER NOT NULL
      )
    ''');
  }

  // ===================
  // SETTINGS
  // ===================
  
  @override
  Future<Map<String, dynamic>?> getSettings() async {
    // Use SharedPreferences for settings (reliable on Android)
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    if (username == null || username.isEmpty) {
      return null;
    }
    return {
      'username': username,
      'target_opstaan': prefs.getString('target_opstaan') ?? '',
      'target_slapen': prefs.getString('target_slapen') ?? '',
      'target_contact': prefs.getString('target_contact') ?? '',
      'target_werk': prefs.getString('target_werk') ?? '',
      'target_eten': prefs.getString('target_eten') ?? '',
    };
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
    // Get the first settings row (there should only be one)
    final existing = await db.query('settings', limit: 1);
    if (existing.isNotEmpty) {
      // Preserve the username and password_hash from the database
      final merged = Map<String, dynamic>.from(existing.first);
      // Remove protected fields from settings to preserve database values
      settings.remove('username');
      settings.remove('password_hash');
      merged.addAll(settings);
      // Update by id to ensure we update the correct row
      final id = existing.first['id'] as int;
      return await db.update('settings', merged, where: 'id = ?', whereArgs: [id]);
    } else {
      // Insert new row - provide required fields with defaults
      final newRow = Map<String, dynamic>.from(settings);
      newRow['username'] = newRow['username'] ?? 'user';
      newRow['password_hash'] = newRow['password_hash'] ?? '';
      return await db.insert('settings', newRow);
    }
  }

  @override
  Future<bool> hasPinSet() async {
    final settings = await getSettings();
    return settings != null && settings['password_hash'] != null;
  }

  @override
  Future<bool> updatePin(String pin) async {
    const username = 'user';
    // Hash de PIN voor veilige opslag
    final hashedPin = SecurityHelper.hashPin(pin);
    return await setPin(username, hashedPin);
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
    // Haal de opgeslagen hash op
    final results = await db.query(
      'settings',
      where: 'username = ?',
      whereArgs: ['user'],
      limit: 1,
    );
    
    if (results.isEmpty) return null;
    
    final storedHash = results.first['password_hash'] as String?;
    if (storedHash == null) return null;
    
    // Verifieer de PIN tegen de hash
    final isValid = SecurityHelper.verifyPin(pin, storedHash);
    return isValid ? results.first : null;
  }

  // ===================
  // DAILY LOGS
  // ===================
  
  @override
  Future<int> insertDailyLog(String date, Map<String, dynamic> data) async {
    try {
      final db = await database;
      data['date'] = date;
      return await db.insert('daily_logs', data, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('ERROR inserting daily_log: $e');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getDailyLogs() async {
    final db = await database;
    return await db.query('daily_logs', orderBy: 'date DESC');
  }

  @override
  Future<List<Map<String, dynamic>>> getDailyLogsForWeek() async {
    final db = await database;
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekAgoStr = '${weekAgo.year}-${weekAgo.month.toString().padLeft(2, '0')}-${weekAgo.day.toString().padLeft(2, '0')}';
    return await db.query(
      'daily_logs',
      where: 'date >= ?',
      whereArgs: [weekAgoStr],
      orderBy: 'date DESC',
    );
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

    final dailyLogs = await db.query('daily_logs', orderBy: 'date DESC');
    final srmActivities = await db.query('srm_activities', orderBy: 'date DESC');
    final medicationConfig = await db.query('medication_config');
    final medicationSchedule = await db.query('medication_schedule');
    final medicationIntake = await db.query('medication_intake', orderBy: 'date DESC');
    final weightLogs = await db.query('weight_logs', orderBy: 'date DESC');
    final appointments = await db.query('medical_appointments', orderBy: 'appointment_date DESC');
    final lifeEvents = await db.query('life_events', orderBy: 'date DESC');

    final exportData = {
      'daily_logs': dailyLogs,
      'srm_activities': srmActivities,
      'medication_config': medicationConfig,
      'medication_schedule': medicationSchedule,
      'medication_intake': medicationIntake,
      'weight_logs': weightLogs,
      'medical_appointments': appointments,
      'life_events': lifeEvents,
    };

    return jsonEncode(exportData);
  }

  @override
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('daily_logs');
    await db.delete('srm_activities');
    await db.delete('medication_intake');
    await db.delete('medication_schedule');
    await db.delete('medication_config');
    await db.delete('weight_logs');
    await db.delete('medical_appointments');
    await db.delete('life_events');
    await db.delete('settings');
  }

  // ===================
  // MEDICATION CONFIG
  // ===================
  
  @override
  Future<int> insertMedicationConfig(String naam, String? dosering, String? eenheid, {bool reminderEnabled = true}) async {
    final db = await database;
    return await db.insert('medication_config', {
      'naam': naam,
      'dosering': dosering,
      'eenheid': eenheid,
      'reminder_enabled': reminderEnabled ? 1 : 0,
    });
  }

  @override
  Future<int> insertMedicationConfigMap(Map<String, dynamic> data) async {
    return await insertMedicationConfig(
      data['naam'] as String,
      data['dosering'] as String,
      data['eenheid'] as String,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationConfig() async {
    final db = await database;
    return await db.query('medication_config');
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationConfigs() async {
    final db = await database;
    return await db.query('medication_config');
  }

  @override
  Future<int> deleteMedicationConfig(int id) async {
    final db = await database;
    return await db.delete('medication_config', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> updateMedicationConfig(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('medication_config', data, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationSchedules() async {
    final db = await database;
    return await db.query('medication_schedule');
  }

  @override
  Future<int> updateMedicationSchedule(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('medication_schedule', data, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Map<String, dynamic>>> getScheduledMedicationsForToday() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    final weekday = DateTime.now().weekday.toString();
    return await db.query(
      'medication_schedule',
      where: 'days_of_week LIKE ? AND enabled = 1',
      whereArgs: ['%$weekday%'],
    );
  }

  @override
  Future<int> confirmMedicationIntake(String date, int medicationId, int confirmed) async {
    final db = await database;
    return await db.update(
      'medication_intake',
      {'confirmed': confirmed},
      where: 'date = ? AND medication_id = ?',
      whereArgs: [date, medicationId],
    );
  }

  @override
  Future<void> importDatabaseFromJson(String jsonString) async {
    final db = await database;
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    
    // Clear existing data
    await clearAllData();
    
    // Import daily logs
    final dailyLogs = data['daily_logs'] as List<dynamic>? ?? [];
    for (final log in dailyLogs) {
      await db.insert('daily_logs', log as Map<String, dynamic>);
    }
    
    // Import SRM activities
    final srmActivities = data['srm_activities'] as List<dynamic>? ?? [];
    for (final activity in srmActivities) {
      await db.insert('srm_activities', activity as Map<String, dynamic>);
    }
    
    // Import medication config
    final medicationConfig = data['medication_config'] as List<dynamic>? ?? [];
    for (final config in medicationConfig) {
      await db.insert('medication_config', config as Map<String, dynamic>);
    }
    
    // Import medication schedule
    final medicationSchedule = data['medication_schedule'] as List<dynamic>? ?? [];
    for (final schedule in medicationSchedule) {
      await db.insert('medication_schedule', schedule as Map<String, dynamic>);
    }
    
    // Import medication intake
    final medicationIntake = data['medication_intake'] as List<dynamic>? ?? [];
    for (final intake in medicationIntake) {
      await db.insert('medication_intake', intake as Map<String, dynamic>);
    }
    
    // Import weight logs
    final weightLogs = data['weight_logs'] as List<dynamic>? ?? [];
    for (final log in weightLogs) {
      await db.insert('weight_logs', log as Map<String, dynamic>);
    }
    
    // Import medical appointments
    final appointments = data['medical_appointments'] as List<dynamic>? ?? [];
    for (final appointment in appointments) {
      await db.insert('medical_appointments', appointment as Map<String, dynamic>);
    }
    
    // Import life events
    final lifeEvents = data['life_events'] as List<dynamic>? ?? [];
    for (final event in lifeEvents) {
      await db.insert('life_events', event as Map<String, dynamic>);
    }
  }

  // ===================
  // MEDICATION SCHEDULE
  // ===================
  
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
  Future<int> insertMedicationScheduleMap(Map<String, dynamic> data) async {
    return await insertMedicationSchedule(
      data['medication_id'] as int,
      data['reminder_time'] as String,
      data['days_of_week'] as String,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationSchedule(int medicationId) async {
    final db = await database;
    return await db.query('medication_schedule', where: 'medication_id = ?', whereArgs: [medicationId]);
  }

  @override
  Future<int> deleteMedicationSchedule(int id) async {
    final db = await database;
    return await db.delete('medication_schedule', where: 'id = ?', whereArgs: [id]);
  }

  // ===================
  // MEDICATION INTAKE
  // ===================
  
  @override
  Future<int> insertMedicationIntake(String date, int medicationId, int aantal) async {
    final db = await database;
    
    // Check of er al een entry is voor deze datum/medicatie
    final existing = await db.query(
      'medication_intake',
      where: 'date = ? AND medication_id = ?',
      whereArgs: [date, medicationId],
      limit: 1,
    );
    
    if (existing.isNotEmpty) {
      // Update bestaande entry in plaats van nieuwe toe te voegen
      return await db.update(
        'medication_intake',
        {'aantal_ingenomen': aantal},
        where: 'date = ? AND medication_id = ?',
        whereArgs: [date, medicationId],
      );
    }
    
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
  
  @override
  Future<int> insertWeightLog(String date, double weight, String? notes) async {
    final db = await database;
    return await db.insert('weight_logs', {'date': date, 'weight': weight, 'notes': notes});
  }

  @override
  Future<List<Map<String, dynamic>>> getWeightLogs() async {
    final db = await database;
    return await db.query('weight_logs', orderBy: 'date DESC');
  }

  @override
  Future<Map<String, dynamic>?> getLatestWeightLog() async {
    final db = await database;
    final results = await db.query('weight_logs', orderBy: 'date DESC', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  @override
  Future<int> deleteWeightLog(int id) async {
    final db = await database;
    return await db.delete('weight_logs', where: 'id = ?', whereArgs: [id]);
  }

  // ===================
  // SLEEP TRACKING
  // ===================
  
  @override
  Future<int> insertSleepLog(String date, String bedTime, String wakeTime, int awakeMinutes) async {
    final db = await database;
    
    // Check if sleep log exists for this date
    final existing = await db.query(
      'daily_logs',
      where: 'date = ?',
      whereArgs: [date],
    );
    
    final sleepHours = _calculateSleepHours(bedTime, wakeTime, awakeMinutes);
    
    if (existing.isNotEmpty) {
      // Update existing
      return await db.update(
        'daily_logs',
        {
          'bed_time': bedTime,
          'wake_time': wakeTime,
          'awake_minutes': awakeMinutes,
          'sleep_hours': sleepHours,
        },
        where: 'date = ?',
        whereArgs: [date],
      );
    } else {
      // Insert new
      return await db.insert('daily_logs', {
        'date': date,
        'bed_time': bedTime,
        'wake_time': wakeTime,
        'awake_minutes': awakeMinutes,
        'sleep_hours': sleepHours,
      });
    }
  }

  @override
  Future<Map<String, dynamic>?> getSleepLog(String date) async {
    final db = await database;
    final results = await db.query(
      'daily_logs',
      where: 'date = ? AND bed_time IS NOT NULL',
      whereArgs: [date],
    );
    
    if (results.isEmpty) return null;
    return results.first;
  }

  double _calculateSleepHours(String bedTime, String wakeTime, int awakeMinutes) {
    try {
      final bedParts = bedTime.split(':');
      final wakeParts = wakeTime.split(':');
      
      int bedHour = int.parse(bedParts[0]);
      int bedMinute = int.parse(bedParts[1]);
      int wakeHour = int.parse(wakeParts[0]);
      int wakeMinute = int.parse(wakeParts[1]);
      
      int bedMinutes = bedHour * 60 + bedMinute;
      int wakeMinutes = wakeHour * 60 + wakeMinute;
      
      if (wakeMinutes < bedMinutes) {
        wakeMinutes += 24 * 60;
      }
      
      int totalMinutes = wakeMinutes - bedMinutes - awakeMinutes;
      return totalMinutes / 60.0;
    } catch (e) {
      return 0.0;
    }
  }

  // ===================
  // MEDICAL APPOINTMENTS
  // ===================
  
  @override
  Future<int> insertMedicalAppointment(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('medical_appointments', data);
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicalAppointments() async {
    final db = await database;
    return await db.query('medical_appointments', orderBy: 'appointment_date ASC');
  }

  @override
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

  @override
  Future<int> updateMedicalAppointment(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('medical_appointments', data, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> deleteMedicalAppointment(int id) async {
    final db = await database;
    return await db.delete('medical_appointments', where: 'id = ?', whereArgs: [id]);
  }
}