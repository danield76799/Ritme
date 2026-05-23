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
    // Force new database by using a new name - old DB may have wrong schema
    final appDir = await getApplicationDocumentsDirectory();
    final dbDir = Directory(p.join(appDir.path, 'databases'));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    // Use new DB name to force fresh schema with correct columns
    final path = p.join(dbDir.path, 'ritme_app_v11.db');
    
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
      version: 11,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      readOnly: false,
      singleInstance: true,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 9) {
      // Migrate daily_logs to new schema with Life Chart fields
      await db.execute('ALTER TABLE daily_logs ADD COLUMN stemming_hoog REAL DEFAULT 50');
      await db.execute('ALTER TABLE daily_logs ADD COLUMN stemming_laag REAL DEFAULT 50');
      await db.execute('ALTER TABLE daily_logs ADD COLUMN gesplitste_stemming INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE daily_logs ADD COLUMN daglicht INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE daily_logs ADD COLUMN sociale_contacten INTEGER DEFAULT 0');
      // Migrate old data: stemming_ochtend -> stemming_hoog, stemming_avond -> stemming_laag
      await db.execute('UPDATE daily_logs SET stemming_hoog = stemming_ochtend WHERE stemming_ochtend IS NOT NULL');
      await db.execute('UPDATE daily_logs SET stemming_laag = stemming_avond WHERE stemming_avond IS NOT NULL');
    }
    if (oldVersion < 10) {
      // Fix daily_logs schema: add id column and ensure date is UNIQUE
      // First, create a backup of existing data
      await db.execute('''
        CREATE TABLE daily_logs_backup AS 
        SELECT * FROM daily_logs
      ''');
      
      // Drop old table
      await db.execute('DROP TABLE daily_logs');
      
      // Create new table with correct schema
      await db.execute('''
        CREATE TABLE daily_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL UNIQUE,
          uren_slaap REAL,
          bed_time TEXT,
          wake_time TEXT,
          awake_minutes INTEGER DEFAULT 0,
          sleep_hours REAL,
          stemming_hoog REAL DEFAULT 50,
          stemming_laag REAL DEFAULT 50,
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
      
      // Restore data, merging duplicates
      await db.execute('''
        INSERT INTO daily_logs (date, uren_slaap, bed_time, wake_time, awake_minutes, sleep_hours, 
          stemming_hoog, stemming_laag, gesplitste_stemming, ontstemde_manie, stemmingsomslagen, 
          daglicht, sociale_contacten, alcohol_middelen, menstruatie, gewicht, medication)
        SELECT 
          date,
          MAX(uren_slaap) as uren_slaap,
          MAX(bed_time) as bed_time,
          MAX(wake_time) as wake_time,
          MAX(awake_minutes) as awake_minutes,
          MAX(sleep_hours) as sleep_hours,
          MAX(stemming_hoog) as stemming_hoog,
          MAX(stemming_laag) as stemming_laag,
          MAX(gesplitste_stemming) as gesplitste_stemming,
          MAX(ontstemde_manie) as ontstemde_manie,
          MAX(stemmingsomslagen) as stemmingsomslagen,
          MAX(daglicht) as daglicht,
          MAX(sociale_contacten) as sociale_contacten,
          MAX(alcohol_middelen) as alcohol_middelen,
          MAX(menstruatie) as menstruatie,
          MAX(gewicht) as gewicht,
          MAX(medication) as medication
        FROM daily_logs_backup
        GROUP BY date
      ''');
      
      // Drop backup table
      await db.execute('DROP TABLE daily_logs_backup');
    }
    if (oldVersion < 11) {
      // Convert stemming scale from 0-100 to -5..+5
      // Formula: new_value = (old_value - 50) / 10
      // 0 -> -5, 50 -> 0, 100 -> +5
      await db.execute('''
        UPDATE daily_logs 
        SET stemming_hoog = CASE 
          WHEN stemming_hoog IS NOT NULL THEN ((stemming_hoog - 50) / 10.0)
          ELSE 0
        END,
        stemming_laag = CASE 
          WHEN stemming_laag IS NOT NULL THEN ((stemming_laag - 50) / 10.0)
          ELSE 0
        END
      ''');
    }
  }

  Future _createDB(Database db, int version) async {
    // Create daily_logs table with correct schema
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

    // Create index for faster queries
    await db.execute('CREATE INDEX idx_daily_logs_date ON daily_logs(date)');

    // Create settings table
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        password_hash TEXT,
        target_opstaan TEXT DEFAULT '08:00',
        target_slapen TEXT DEFAULT '23:00',
        target_contact TEXT,
        target_werk TEXT,
        target_eten TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create srm_activities table
    await db.execute('''
      CREATE TABLE srm_activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        activity_type TEXT NOT NULL,
        actual_time TEXT,
        target_time TEXT,
        p_score INTEGER DEFAULT 0,
        srt_point INTEGER DEFAULT 0
      )
    ''');

    // Create medication tables
    await db.execute('''
      CREATE TABLE medication_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        naam TEXT NOT NULL,
        dosering TEXT,
        eenheid TEXT,
        reminder_enabled INTEGER DEFAULT 1
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

    // Create weight_logs table
    await db.execute('''
      CREATE TABLE weight_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        weight REAL NOT NULL,
        notes TEXT
      )
    ''');

    // Create medical_appointments table
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

    // Create life_events table
    await db.execute('''
      CREATE TABLE life_events (
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
    
    // Try to get username - if empty, fall back to DB
    var username = prefs.getString('username') ?? '';
    var targetOpstaan = prefs.getString('target_opstaan') ?? '';
    var targetSlapen = prefs.getString('target_slapen') ?? '';
    var targetContact = prefs.getString('target_contact') ?? '';
    var targetWerk = prefs.getString('target_werk') ?? '';
    var targetEten = prefs.getString('target_eten') ?? '';
    
    // If any critical field is empty, try to get from DB and sync
    if (username.isEmpty || targetOpstaan.isEmpty || targetSlapen.isEmpty) {
      final dbSettings = await _getSettingsFromDb();
      if (dbSettings != null) {
        // Sync to SharedPreferences
        await _syncSettingsToPrefs(dbSettings);
        
        // Use DB values (they may be more up-to-date)
        username = dbSettings['username']?.toString() ?? username;
        targetOpstaan = dbSettings['target_opstaan']?.toString() ?? targetOpstaan;
        targetSlapen = dbSettings['target_slapen']?.toString() ?? targetSlapen;
        targetContact = dbSettings['target_contact']?.toString() ?? targetContact;
        targetWerk = dbSettings['target_werk']?.toString() ?? targetWerk;
        targetEten = dbSettings['target_eten']?.toString() ?? targetEten;
      }
    }
    
    if (username.isEmpty) {
      return null;
    }
    
    return {
      'username': username,
      'target_opstaan': targetOpstaan,
      'target_slapen': targetSlapen,
      'target_contact': targetContact,
      'target_werk': targetWerk,
      'target_eten': targetEten,
    };
  }
  
  Future<Map<String, dynamic>?> _getSettingsFromDb() async {
    final db = await database;
    final result = await db.query('settings', limit: 1);
    if (result.isEmpty) return null;
    return {
      'username': result.first['username']?.toString() ?? '',
      'target_opstaan': result.first['target_opstaan']?.toString() ?? '',
      'target_slapen': result.first['target_slapen']?.toString() ?? '',
      'target_contact': result.first['target_contact']?.toString() ?? '',
      'target_werk': result.first['target_werk']?.toString() ?? '',
      'target_eten': result.first['target_eten']?.toString() ?? '',
    };
  }
  
  Future<void> _syncSettingsToPrefs(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    if (settings['username'] != null) {
      await prefs.setString('username', settings['username'].toString());
    }
    if (settings['target_opstaan'] != null) {
      await prefs.setString('target_opstaan', settings['target_opstaan'].toString());
    }
    if (settings['target_slapen'] != null) {
      await prefs.setString('target_slapen', settings['target_slapen'].toString());
    }
    if (settings['target_contact'] != null) {
      await prefs.setString('target_contact', settings['target_contact'].toString());
    }
    if (settings['target_werk'] != null) {
      await prefs.setString('target_werk', settings['target_werk'].toString());
    }
    if (settings['target_eten'] != null) {
      await prefs.setString('target_eten', settings['target_eten'].toString());
    }
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
    int result;
    if (existing.isNotEmpty) {
      // Preserve the password_hash from the database
      final merged = Map<String, dynamic>.from(existing.first);
      // Remove password_hash from settings to preserve database value
      settings.remove('password_hash');
      merged.addAll(settings);
      // Update by id to ensure we update the correct row
      final id = existing.first['id'] as int;
      result = await db.update('settings', merged, where: 'id = ?', whereArgs: [id]);
    } else {
      // Insert new row - provide required fields with defaults
      final newRow = Map<String, dynamic>.from(settings);
      newRow['username'] = newRow['username'] ?? 'user';
      newRow['password_hash'] = newRow['password_hash'] ?? '';
      result = await db.insert('settings', newRow);
    }
    // Also sync to SharedPreferences so getSettings() can find it
    // Re-fetch from DB to ensure we sync the correct merged data
    final updatedSettings = await _getSettingsFromDb();
    if (updatedSettings != null) {
      await _syncSettingsToPrefs(updatedSettings);
    }
    
    // Also save individual fields directly to ensure they're persisted
    final prefs = await SharedPreferences.getInstance();
    if (settings['username'] != null) {
      await prefs.setString('username', settings['username'].toString());
    }
    if (settings['target_opstaan'] != null) {
      await prefs.setString('target_opstaan', settings['target_opstaan'].toString());
    }
    if (settings['target_slapen'] != null) {
      await prefs.setString('target_slapen', settings['target_slapen'].toString());
    }
    
    return result;
  }

  @override
  Future<bool> hasPinSet() async {
    final settings = await getSettings();
    return settings != null && settings['password_hash'] != null;
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
  Future<bool> updatePin(String pin) async {
    const username = 'user';
    // Hash de PIN voor veilige opslag
    final hashedPin = SecurityHelper.hashPin(pin);
    return await setPin(username, hashedPin);
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
    final db = await database;
    
    // Check if a log already exists for this date
    final existing = await db.query('daily_logs', where: 'date = ?', whereArgs: [date]);
    
    if (existing.isNotEmpty) {
      // Update existing row, preserving fields not in the new data
      final existingData = Map<String, dynamic>.from(existing.first);
      final updateData = Map<String, dynamic>.from(data);
      
      // Remove fields that are null in the new data to preserve existing values
      updateData.removeWhere((key, value) => value == null);
      
      // Merge new data with existing data
      existingData.addAll(updateData);
      existingData.remove('id'); // Don't update the ID
      
      return await db.update(
        'daily_logs',
        existingData,
        where: 'date = ?',
        whereArgs: [date],
      );
    } else {
      // Insert new row
      return await db.insert('daily_logs', data);
    }
  }

  // ===================
  // SRM ACTIVITIES
  // ===================
  
  @override
  Future<int> insertSrmActivity(String date, String activityType, String? actualTime, int? pScore, int? srtPoint, {String? targetTime}) async {
    final db = await database;
    return await db.insert('srm_activities', {
      'date': date,
      'activity_type': activityType,
      'actual_time': actualTime,
      'target_time': targetTime,
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
  Future<int> deleteMedicationSchedule(int id) async {
    final db = await database;
    return await db.delete('medication_schedule', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> insertMedicationIntake(String date, int medicationId, int aantal) async {
    final db = await database;
    return await db.insert('medication_intake', {
      'date': date,
      'medication_id': medicationId,
      'aantal_ingenomen': aantal,
      'confirmed': 0,
    });
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

  // ===================
  // SLEEP TRACKING
  // ===================
  
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
  Future<int> deleteMedicalAppointment(int id) async {
    final db = await database;
    return await db.delete('medical_appointments', where: 'id = ?', whereArgs: [id]);
  }

  // ===================
  // LIFE EVENTS
  // ===================
  
  @override
  Future<int> insertLifeEvent(String date, String omschrijving, int invloed) async {
    final db = await database;
    return await db.insert('life_events', {
      'date': date,
      'omschrijving': omschrijving,
      'invloed': invloed,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getLifeEvents(String date) async {
    final db = await database;
    return await db.query('life_events', where: 'date = ?', whereArgs: [date], orderBy: 'date DESC');
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
  Future<int> deleteLifeEvent(int id) async {
    final db = await database;
    return await db.delete('life_events', where: 'id = ?', whereArgs: [id]);
  }

  // ===================
  // WEIGHT LOGS
  // ===================
  
  @override
  Future<int> insertWeightLog(String date, double weight, String? notes) async {
    final db = await database;
    return await db.insert('weight_logs', {
      'date': date,
      'weight': weight,
      'notes': notes,
    });
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
}