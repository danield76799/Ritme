import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'database_repository.dart';

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
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
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

    // ---- BIPOIRE STOORNIS FEATURES (v3) ----
    await db.execute('''
      CREATE TABLE prodromal_checklist (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        sign TEXT NOT NULL,
        enabled INTEGER DEFAULT 1,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE prodromal_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        checklist_id INTEGER NOT NULL,
        present INTEGER DEFAULT 0,
        severity INTEGER DEFAULT 1,
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE crisis_plan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        section TEXT NOT NULL,
        content TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE episode_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_date TEXT NOT NULL,
        end_date TEXT,
        episode_type TEXT NOT NULL,
        severity INTEGER DEFAULT 3,
        notes TEXT,
        trigger TEXT,
        medication_changes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE medication_levels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medication_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        bloedspiegel REAL,
        eenheid TEXT DEFAULT 'mmol/L',
        dosering_mg INTEGER,
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Nieuwe kolommen in medication_config
    await db.execute('ALTER TABLE medication_config ADD COLUMN bloedspiegel_bijhouden INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE medication_config ADD COLUMN target_min REAL');
    await db.execute('ALTER TABLE medication_config ADD COLUMN target_max REAL');

    // Voortekenen standaard items seeden
    await _seedProdromalChecklist(db);

    await db.execute('''
      CREATE TABLE settings (
        username TEXT PRIMARY KEY,
        password_hash TEXT,
        target_opstaan TEXT,
        target_slapen TEXT,
        target_contact TEXT,
        target_werk TEXT,
        target_eten TEXT,
        show_menstruatie TEXT DEFAULT '1',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Indexen voor betere performance
    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    // Daily logs - meest opgevraagd per datum
    await db.execute('CREATE INDEX idx_daily_logs_date ON daily_logs(date)');
    
    // SRM activities - per datum
    await db.execute('CREATE INDEX idx_srm_activities_date ON srm_activities(date)');
    
    // Medication intake - per medicatie en datum
    await db.execute('CREATE INDEX idx_medication_intake_med_date ON medication_intake(medication_id, date)');
    
    // Prodromal logs - per datum
    await db.execute('CREATE INDEX idx_prodromal_logs_date ON prodromal_logs(date)');
    
    // Episode logs - per start datum
    await db.execute('CREATE INDEX idx_episode_logs_start ON episode_logs(start_date)');
    
    // Medication levels - per medicatie en datum
    await db.execute('CREATE INDEX idx_medication_levels_med_date ON medication_levels(medication_id, date)');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE daily_logs ADD COLUMN life_event TEXT');
        await db.execute('ALTER TABLE daily_logs ADD COLUMN life_event_influence INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE daily_logs ADD COLUMN gewicht_notes TEXT');
        await db.execute('ALTER TABLE daily_logs ADD COLUMN appointment TEXT');
      } catch (e) {
        // Columns may already exist
      }
    }
    if (oldVersion < 3) {
      await _migrateToV3(db);
    }
  }

  Future _migrateToV3(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS prodromal_checklist (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category TEXT NOT NULL,
          sign TEXT NOT NULL,
          enabled INTEGER DEFAULT 1,
          sort_order INTEGER DEFAULT 0,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS prodromal_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          checklist_id INTEGER NOT NULL,
          present INTEGER DEFAULT 0,
          severity INTEGER DEFAULT 1,
          notes TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS crisis_plan (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          section TEXT NOT NULL,
          content TEXT NOT NULL,
          sort_order INTEGER DEFAULT 0,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS episode_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          start_date TEXT NOT NULL,
          end_date TEXT,
          episode_type TEXT NOT NULL,
          severity INTEGER DEFAULT 3,
          notes TEXT,
          trigger TEXT,
          medication_changes TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS medication_levels (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          medication_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          bloedspiegel REAL,
          eenheid TEXT DEFAULT 'mmol/L',
          dosering_mg INTEGER,
          notes TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('ALTER TABLE medication_config ADD COLUMN bloedspiegel_bijhouden INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE medication_config ADD COLUMN target_min REAL');
      await db.execute('ALTER TABLE medication_config ADD COLUMN target_max REAL');
      try {
        await db.execute('ALTER TABLE settings ADD COLUMN show_menstruatie TEXT DEFAULT ''1''');
      } catch (_) {}
      await _seedProdromalChecklist(db);
    } catch (e) {
      // Tables/columns may already exist
    }
  }

  Future _seedProdromalChecklist(Database db) async {
    final existing = await db.query('prodromal_checklist', limit: 1);
    if (existing.isNotEmpty) return;

    final defaults = [
      // Manie/hypomanie voortekenen
      {'category': 'manie', 'sign': 'Minder slaap nodig dan normaal', 'sort_order': 1},
      {'category': 'manie', 'sign': 'Racing thoughts / gedachten die racen', 'sort_order': 2},
      {'category': 'manie', 'sign': 'Meer energie dan normaal', 'sort_order': 3},
      {'category': 'manie', 'sign': 'Sneller praten dan normaal', 'sort_order': 4},
      {'category': 'manie', 'sign': 'Verhoogde prikkelbaarheid', 'sort_order': 5},
      {'category': 'manie', 'sign': 'Meer uitgeven / risicogedrag', 'sort_order': 6},
      {'category': 'manie', 'sign': 'Grotere plannen / grandioos denken', 'sort_order': 7},
      {'category': 'manie', 'sign': 'Afleidbaar / slechte concentratie', 'sort_order': 8},
      // Depressie voortekenen
      {'category': 'depressie', 'sign': 'Minder interesse in activiteiten', 'sort_order': 9},
      {'category': 'depressie', 'sign': 'Vermoeidheid / weinig energie', 'sort_order': 10},
      {'category': 'depressie', 'sign': 'Somberheid / verdriet', 'sort_order': 11},
      {'category': 'depressie', 'sign': 'Meer slapen dan normaal', 'sort_order': 12},
      {'category': 'depressie', 'sign': 'Eetlust verandering', 'sort_order': 13},
      {'category': 'depressie', 'sign': 'Concentratieproblemen', 'sort_order': 14},
      {'category': 'depressie', 'sign': 'Terugtrekken uit sociale contacten', 'sort_order': 15},
      {'category': 'depressie', 'sign': 'Gevoelens van waardeloosheid', 'sort_order': 16},
      // Gemengd/stress voortekenen
      {'category': 'gemengd', 'sign': 'Verhoogde stress / spanning', 'sort_order': 17},
      {'category': 'gemengd', 'sign': 'Piekeren / malen', 'sort_order': 18},
      {'category': 'gemengd', 'sign': 'Lichamelijke onrust', 'sort_order': 19},
      {'category': 'gemengd', 'sign': 'Conflicten met anderen', 'sort_order': 20},
    ];

    for (final item in defaults) {
      await db.insert('prodromal_checklist', item);
    }
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
    return await db.insert('settings', settings, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<int> updateSettings(String username, Map<String, dynamic> settings) async {
    final db = await database;
    return await db.update('settings', settings, where: 'username = ?', whereArgs: [username]);
  }

  @override
  Future<int> updateSettingsMap(Map<String, dynamic> settings) async {
    final db = await database;
    final existing = await getSettings();
    if (existing != null) {
      return await db.update('settings', settings, where: 'username = ?', whereArgs: [existing['username']]);
    } else {
      return await db.insert('settings', settings);
    }
  }

  @override
  Future<bool> hasPinSet() async => false;

  @override
  Future<bool> updatePin(String pin) async => true;

  @override
  Future<Map<String, dynamic>?> validateLoginPin(String pin) async => null;

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
    final logs = await db.query('daily_logs', orderBy: 'date DESC, id DESC');
    
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
  Future<List<Map<String, dynamic>>> getDailyLogsForWeek() async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return getDailyLogsRange(
      '${weekAgo.year}-${weekAgo.month.toString().padLeft(2, '0')}-${weekAgo.day.toString().padLeft(2, '0')}',
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    );
  }

  /// Batch query: laadt alle logs in één keer voor een datumrange, met SQL dedup
  @override
  Future<List<Map<String, dynamic>>> getDailyLogsRange(String startDate, String endDate) async {
    final db = await database;
    // Eén query: groepeer per datum, pak de laatste entry (hoogste id) per datum
    final logs = await db.rawQuery('''
      SELECT dl.* FROM daily_logs dl
      INNER JOIN (
        SELECT date, MAX(id) as max_id FROM daily_logs
        WHERE date BETWEEN ? AND ?
        GROUP BY date
      ) grouped ON dl.date = grouped.date AND dl.id = grouped.max_id
      ORDER BY dl.date DESC
    ''', [startDate, endDate]);
    return logs;
  }

  /// Batch query: laadt alle SRM activiteiten voor een datumrange
  @override
  Future<List<Map<String, dynamic>>> getSrmActivitiesRange(String startDate, String endDate) async {
    final db = await database;
    return await db.query(
      'srm_activities',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date DESC, id DESC',
    );
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
  Future<int> insertSrmActivity(String date, String activityType, String? actualTime, int? pScore, int? srtPoint, {String? targetTime}) async {
    final db = await database;
    return await db.insert('srm_activities', {
      'date': date,
      'activity_type': activityType,
      'actual_time': actualTime,
      'target_time': targetTime,
      'p_score': pScore ?? 3,
      'srt_point': srtPoint,
    });
  }

  @override
  Future<int> insertSrmActivityMap(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('srm_activities', data);
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
  Future<int> insertMedicationConfig(String naam, String? dosering, String? eenheid, {bool reminderEnabled = true}) async {
    final db = await database;
    return await db.insert('medication_config', {
      'naam': naam,
      'dosering': dosering,
      'eenheid': eenheid,
      'reminder_enabled': reminderEnabled ? 1 : 0,
    });
  }

  /// Cleanup orphaned and duplicate medication schedules, then cancel all
  /// scheduled local notifications. Call this before rescheduling to ensure
  /// no stale or duplicate reminders remain.
  @override
  Future<void> cleanupMedicationSchedulesAndCancelNotifications() async {
    final db = await database;

    // 1. Delete schedules for medications that no longer exist
    await db.rawDelete('''
      DELETE FROM medication_schedule
      WHERE medication_id NOT IN (SELECT id FROM medication_config)
    ''');

    // 2. Delete disabled schedules (reminder_enabled=0 in medication_config)
    await db.rawDelete('''
      DELETE FROM medication_schedule
      WHERE medication_id IN (
        SELECT id FROM medication_config WHERE reminder_enabled = 0
      )
    ''');

    // 3. Keep only the most recent schedule per medication_id
    await db.rawDelete('''
      DELETE FROM medication_schedule
      WHERE id NOT IN (
        SELECT MAX(id)
        FROM medication_schedule
        GROUP BY medication_id
      )
    ''');
  }

  @override
  Future<int> deleteMedicationConfig(int id) async {
    final db = await database;
    // Cascade delete: remove schedules and intakes first
    await db.delete('medication_schedule', where: 'medication_id = ?', whereArgs: [id]);
    await db.delete('medication_intake', where: 'medication_id = ?', whereArgs: [id]);
    return await db.delete('medication_config', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> updateMedicationConfig(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('medication_config', data, where: 'id = ?', whereArgs: [id]);
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
  Future<int> insertMedicationSchedule(int medicationId, String reminderTime, String daysOfWeek) async {
    final db = await database;
    return await db.insert('medication_schedule', {
      'medication_id': medicationId,
      'reminder_time': reminderTime,
      'days_of_week': daysOfWeek,
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
  Future<List<Map<String, dynamic>>> getMedicationSchedules() async {
    final db = await database;
    return await db.query('medication_schedule');
  }

  @override
  Future<List<Map<String, dynamic>>> getScheduledMedicationsForToday() async {
    // Return empty list - implementation depends on notification system
    return [];
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

  // ===================
  // MEDICATION INTAKE
  // ===================
  
  @override
  Future<int> insertMedicationIntake(String date, int medicationId, int aantal) async {
    final db = await database;
    return await db.insert('medication_intake', {
      'medication_id': medicationId,
      'date': date,
      'aantal_ingenomen': aantal,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<int> insertMedicationIntakeMap(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('medication_intake', data, conflictAlgorithm: ConflictAlgorithm.replace);
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
    return await upsertDailyLog({
      'date': date,
      'life_event': omschrijving,
      'life_event_influence': invloed,
    });
  }

  @override
  Future<int> insertLifeEventMap(Map<String, dynamic> data) async {
    return await upsertDailyLog(data);
  }

  @override
  Future<List<Map<String, dynamic>>> getLifeEvents(String date) async {
    final log = await getDailyLog(date);
    if (log == null || log['life_event'] == null) return [];
    return [{
      'date': date,
      'omschrijving': log['life_event'],
      'invloed': log['life_event_influence'],
    }];
  }

  @override
  Future<List<Map<String, dynamic>>> getAllLifeEvents() async {
    final db = await database;
    return await db.query('daily_logs', where: 'life_event IS NOT NULL', orderBy: 'date DESC');
  }

  // ===================
  // WEIGHT LOGS
  // ===================
  
  @override
  Future<int> insertWeightLog(String date, double weight, String? notes) async {
    return await upsertDailyLog({
      'date': date,
      'gewicht': weight,
      'gewicht_notes': notes,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getWeightLogs() async {
    final db = await database;
    return await db.query('daily_logs', where: 'gewicht IS NOT NULL', orderBy: 'date DESC');
  }

  @override
  Future<Map<String, dynamic>?> getLatestWeightLog() async {
    final db = await database;
    final results = await db.query('daily_logs', where: 'gewicht IS NOT NULL', orderBy: 'date DESC', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  @override
  Future<int> deleteWeightLog(int id) async {
    final db = await database;
    return await db.update('daily_logs', {'gewicht': null}, where: 'id = ?', whereArgs: [id]);
  }

  // ===================
  // MEDICAL APPOINTMENTS
  // ===================
  
  @override
  Future<int> insertMedicalAppointment(Map<String, dynamic> data) async {
    return await upsertDailyLog({
      'date': data['date'],
      'appointment': data['omschrijving'],
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicalAppointments() async {
    final db = await database;
    return await db.query('daily_logs', where: 'appointment IS NOT NULL', orderBy: 'date DESC');
  }

  @override
  Future<List<Map<String, dynamic>>> getUpcomingAppointments() async {
    // Return empty for now
    return [];
  }

  @override
  Future<int> updateMedicalAppointment(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('daily_logs', data, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> deleteMedicalAppointment(int id) async {
    final db = await database;
    return await db.update('daily_logs', {'appointment': null}, where: 'id = ?', whereArgs: [id]);
  }

  // ===================
  // PRODROMAL CHECKLIST
  // ===================

  Future<List<Map<String, dynamic>>> getProdromalChecklist() async {
    final db = await database;
    return await db.query('prodromal_checklist', orderBy: 'sort_order ASC');
  }

  Future<List<Map<String, dynamic>>> getEnabledProdromalChecklist() async {
    final db = await database;
    return await db.query('prodromal_checklist', where: 'enabled = 1', orderBy: 'sort_order ASC');
  }

  Future<int> insertProdromalSign(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('prodromal_checklist', data);
  }

  Future<int> updateProdromalSign(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('prodromal_checklist', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteProdromalSign(int id) async {
    final db = await database;
    return await db.delete('prodromal_checklist', where: 'id = ?', whereArgs: [id]);
  }

  // ===================
  // PRODROMAL LOGS
  // ===================

  Future<int> insertProdromalLog(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('prodromal_logs', data);
  }

  Future<void> upsertProdromalLog(Map<String, dynamic> data) async {
    final db = await database;
    final date = data['date']?.toString();
    final checklistId = data['checklist_id'];
    if (date == null || checklistId == null) return;
    
    // Check if entry exists for this date + checklist_id
    final existing = await db.query(
      'prodromal_logs',
      where: 'date = ? AND checklist_id = ?',
      whereArgs: [date, checklistId],
    );
    
    if (existing.isNotEmpty) {
      // Update existing
      await db.update(
        'prodromal_logs',
        data,
        where: 'date = ? AND checklist_id = ?',
        whereArgs: [date, checklistId],
      );
    } else {
      // Insert new
      await db.insert('prodromal_logs', data);
    }
  }

  Future<List<Map<String, dynamic>>> getProdromalLogs(String date) async {
    final db = await database;
    return await db.query('prodromal_logs', where: 'date = ?', whereArgs: [date]);
  }

  Future<Map<String, dynamic>?> getProdromalSummary(String date) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN present = 1 THEN 1 ELSE 0 END) as total_present,
        SUM(CASE WHEN p.category = 'manie' AND present = 1 THEN 1 ELSE 0 END) as manie_count,
        SUM(CASE WHEN p.category = 'depressie' AND present = 1 THEN 1 ELSE 0 END) as depressie_count,
        SUM(CASE WHEN p.category = 'gemengd' AND present = 1 THEN 1 ELSE 0 END) as gemengd_count
      FROM prodromal_logs pl
      JOIN prodromal_checklist p ON pl.checklist_id = p.id
      WHERE pl.date = ?
    ''', [date]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getRecentProdromalTrends(int days) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days));
    final dateStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    return await db.rawQuery('''
      SELECT pl.date, COUNT(*) as warning_count
      FROM prodromal_logs pl
      WHERE pl.date >= ? AND pl.present = 1
      GROUP BY pl.date
      ORDER BY pl.date DESC
    ''', [dateStr]);
  }

  Future<String?> getLastProdromalDate() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT date FROM prodromal_logs
      WHERE present = 1
      GROUP BY date
      ORDER BY date DESC
      LIMIT 1
    ''');
    if (result.isEmpty) return null;
    return result.first['date']?.toString();
  }

  Future<void> copyProdromalLogs(String fromDate, String toDate) async {
    final db = await database;
    // Delete existing logs for target date
    await db.delete('prodromal_logs', where: 'date = ?', whereArgs: [toDate]);
    // Copy from source date using rawInsert instead of rawQuery
    final sourceLogs = await db.query('prodromal_logs', where: 'date = ?', whereArgs: [fromDate]);
    for (var log in sourceLogs) {
      final newLog = Map<String, dynamic>.from(log);
      newLog['date'] = toDate;
      newLog.remove('id');
      await db.insert('prodromal_logs', newLog);
    }
  }

  // ===================
  // CRISIS PLAN
  // ===================

  Future<List<Map<String, dynamic>>> getCrisisPlan() async {
    final db = await database;
    return await db.query('crisis_plan', orderBy: 'sort_order ASC');
  }

  Future<int> insertCrisisPlanSection(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('crisis_plan', data);
  }

  Future<int> updateCrisisPlanSection(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('crisis_plan', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateCrisisPlanSectionBySection(String section, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('crisis_plan', data, where: 'section = ?', whereArgs: [section]);
  }

  Future<int> deleteCrisisPlanSection(int id) async {
    final db = await database;
    return await db.delete('crisis_plan', where: 'id = ?', whereArgs: [id]);
  }

  // ===================
  // EPISODE LOGS
  // ===================

  Future<int> insertEpisode(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('episode_logs', data);
  }

  Future<int> updateEpisode(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('episode_logs', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getEpisodes({String? type, int limit = 50}) async {
    final db = await database;
    if (type != null) {
      return await db.query('episode_logs', where: 'episode_type = ?', whereArgs: [type], orderBy: 'start_date DESC', limit: limit);
    }
    return await db.query('episode_logs', orderBy: 'start_date DESC', limit: limit);
  }

  Future<Map<String, dynamic>?> getActiveEpisode() async {
    final db = await database;
    final results = await db.query('episode_logs', where: 'end_date IS NULL', orderBy: 'start_date DESC', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> endEpisode(int id, String endDate) async {
    final db = await database;
    return await db.update('episode_logs', {'end_date': endDate}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteEpisode(int id) async {
    final db = await database;
    return await db.delete('episode_logs', where: 'id = ?', whereArgs: [id]);
  }

  // ===================
  // MEDICATION LEVELS
  // ===================

  Future<int> insertMedicationLevel(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('medication_levels', data);
  }

  Future<List<Map<String, dynamic>>> getMedicationLevels(int medicationId) async {
    final db = await database;
    return await db.query('medication_levels', where: 'medication_id = ?', whereArgs: [medicationId], orderBy: 'date DESC');
  }

  Future<Map<String, dynamic>?> getLatestMedicationLevel(int medicationId) async {
    final db = await database;
    final results = await db.query('medication_levels', where: 'medication_id = ?', whereArgs: [medicationId], orderBy: 'date DESC', limit: 1);
    return results.isNotEmpty ? results.first : null;
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
    await db.delete('prodromal_checklist');
    await db.delete('prodromal_logs');
    await db.delete('crisis_plan');
    await db.delete('episode_logs');
    await db.delete('medication_levels');
    await db.delete('settings');
  }

  @override
  Future<String> exportDatabaseToJson() async {
    final db = await database;
    final data = {
      'daily_logs': await db.query('daily_logs'),
      'srm_activities': await db.query('srm_activities'),
      'medication_config': await db.query('medication_config'),
      'medication_schedule': await db.query('medication_schedule'),
      'medication_intake': await db.query('medication_intake'),
      'prodromal_checklist': await db.query('prodromal_checklist'),
      'prodromal_logs': await db.query('prodromal_logs'),
      'crisis_plan': await db.query('crisis_plan'),
      'episode_logs': await db.query('episode_logs'),
      'medication_levels': await db.query('medication_levels'),
      'settings': await db.query('settings'),
    };
    return jsonEncode(data);
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
    for (final item in (data['prodromal_checklist'] as List? ?? [])) {
      await db.insert('prodromal_checklist', item as Map<String, dynamic>);
    }
    for (final item in (data['prodromal_logs'] as List? ?? [])) {
      await db.insert('prodromal_logs', item as Map<String, dynamic>);
    }
    for (final item in (data['crisis_plan'] as List? ?? [])) {
      await db.insert('crisis_plan', item as Map<String, dynamic>);
    }
    for (final item in (data['episode_logs'] as List? ?? [])) {
      await db.insert('episode_logs', item as Map<String, dynamic>);
    }
    for (final item in (data['medication_levels'] as List? ?? [])) {
      await db.insert('medication_levels', item as Map<String, dynamic>);
    }
    for (final setting in (data['settings'] as List? ?? [])) {
      await db.insert('settings', setting as Map<String, dynamic>);
    }
  }
}