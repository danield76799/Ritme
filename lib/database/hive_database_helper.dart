import 'package:hive/hive.dart';
import 'database_repository.dart';

class HiveDatabaseHelper implements DatabaseRepository {
  static final HiveDatabaseHelper instance = HiveDatabaseHelper._init();
  
  static const String _settingsBox = 'settings';
  static const String _dailyLogsBox = 'daily_logs';
  static const String _srmActivitiesBox = 'srm_activities';
  static const String _medicationConfigBox = 'medication_config';
  static const String _medicationIntakeBox = 'medication_intake';
  static const String _lifeEventsBox = 'life_events';

  HiveDatabaseHelper._init();

  static Future<void> init() async {
    await Hive.openBox(_settingsBox);
    await Hive.openBox(_dailyLogsBox);
    await Hive.openBox(_srmActivitiesBox);
    await Hive.openBox(_medicationConfigBox);
    await Hive.openBox(_medicationIntakeBox);
    await Hive.openBox(_lifeEventsBox);
  }

  Box get _settings => Hive.box(_settingsBox);
  Box get _dailyLogs => Hive.box(_dailyLogsBox);
  Box get _srmActivities => Hive.box(_srmActivitiesBox);
  Box get _medicationConfig => Hive.box(_medicationConfigBox);
  Box get _medicationIntake => Hive.box(_medicationIntakeBox);
  Box get _lifeEvents => Hive.box(_lifeEventsBox);

  // ===================
  // SETTINGS
  // ===================
  
  @override
  Future<Map<String, dynamic>?> getSettings() async {
    final data = _settings.get('user');
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<int> insertSettings(Map<String, dynamic> settings) async {
    await _settings.put('user', settings);
    return 1;
  }

  @override
  Future<int> updateSettings(String username, Map<String, dynamic> settings) async {
    await _settings.put(username, settings);
    return 1;
  }

  @override
  Future<int> updateSettingsMap(Map<String, dynamic> settings) async {
    await _settings.put('user', settings);
    return 1;
  }

  @override
  Future<bool> hasPinSet() async {
    final settings = await getSettings();
    return settings != null && settings['password_hash'] != null;
  }

  @override
  Future<bool> updatePin(String pin) async {
    final existing = await getSettings();
    if (existing != null) {
      existing['password_hash'] = pin;
      await _settings.put('user', existing);
    } else {
      await _settings.put('user', {'username': 'user', 'password_hash': pin});
    }
    return true;
  }

  @override
  Future<Map<String, dynamic>?> validateLoginPin(String pin) async {
    final settings = await getSettings();
    if (settings != null && settings['password_hash'] == pin) {
      return settings;
    }
    return null;
  }

  // ===================
  // DAILY LOGS
  // ===================
  
  @override
  Future<int> insertDailyLog(String date, Map<String, dynamic> data) async {
    await _dailyLogs.put(date, data);
    return 1;
  }

  @override
  Future<List<Map<String, dynamic>>> getDailyLogs() async {
    final logs = _dailyLogs.values.toList();
    logs.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return logs.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Future<Map<String, dynamic>?> getDailyLog(String date) async {
    final data = _dailyLogs.get(date);
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<int> upsertDailyLog(Map<String, dynamic> data) async {
    final date = data['date'] as String;
    await _dailyLogs.put(date, data);
    return 1;
  }

  // ===================
  // SRM ACTIVITIES
  // ===================
  
  @override
  Future<int> insertSrmActivity(String date, String activityType, String? actualTime, int? pScore, int? srtPoint) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    await _srmActivities.put(id, {
      'date': date,
      'activity_type': activityType,
      'actual_time': actualTime,
      'p_score': pScore,
      'srt_point': srtPoint,
    });
    return id;
  }

  @override
  Future<int> insertSrmActivityMap(Map<String, dynamic> data) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    await _srmActivities.put(id, data);
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getSrmActivities(String date) async {
    final activities = _srmActivities.values
        .where((e) => e['date'] == date)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return activities;
  }

  // ===================
  // MEDICATION CONFIG
  // ===================
  
  @override
  Future<int> insertMedicationConfig(String naam, String? dosering, String? eenheid) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    await _medicationConfig.put(id, {'naam': naam, 'dosering': dosering, 'eenheid': eenheid});
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationConfigs() async {
    return _medicationConfig.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ===================
  // MEDICATION INTAKE
  // ===================
  
  @override
  Future<int> insertMedicationIntake(String date, int medicationId, int aantal) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    await _medicationIntake.put(id, {
      'date': date,
      'medication_id': medicationId,
      'aantal_ingenomen': aantal,
    });
    return id;
  }

  @override
  Future<int> insertMedicationIntakeMap(Map<String, dynamic> data) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    await _medicationIntake.put(id, data);
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntake(String date) async {
    return _medicationIntake.values
        .where((e) => e['date'] == date)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ===================
  // LIFE EVENTS
  // ===================
  
  @override
  Future<int> insertLifeEvent(String date, String omschrijving, int invloed) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    await _lifeEvents.put(id, {
      'date': date,
      'omschrijving': omschrijving,
      'invloed': invloed,
    });
    return id;
  }

  @override
  Future<int> insertLifeEventMap(Map<String, dynamic> data) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    await _lifeEvents.put(id, data);
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getLifeEvents(String date) async {
    return _lifeEvents.values
        .where((e) => e['date'] == date)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
