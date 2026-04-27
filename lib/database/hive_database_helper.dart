import 'dart:convert';
import 'package:hive/hive.dart';
import 'database_repository.dart';

class HiveDatabaseHelper implements DatabaseRepository {
  static final HiveDatabaseHelper instance = HiveDatabaseHelper._init();
  
  static const String _settingsBox = 'settings';
  static const String _dailyLogsBox = 'daily_logs';
  static const String _srmActivitiesBox = 'srm_activities';
  static const String _medicationConfigBox = 'medication_config';
  static const String _medicationIntakeBox = 'medication_intake';
  static const String _medicationScheduleBox = 'medication_schedule';
  static const String _lifeEventsBox = 'life_events';
  static const String _weightLogsBox = 'weight_logs';
  static const String _medicalAppointmentsBox = 'medical_appointments';

  HiveDatabaseHelper._init();

  static Future<void> init() async {
    await Hive.openBox(_settingsBox);
    await Hive.openBox(_dailyLogsBox);
    await Hive.openBox(_srmActivitiesBox);
    await Hive.openBox(_medicationConfigBox);
    await Hive.openBox(_medicationIntakeBox);
    await Hive.openBox(_medicationScheduleBox);
    await Hive.openBox(_lifeEventsBox);
    await Hive.openBox(_weightLogsBox);
    await Hive.openBox(_medicalAppointmentsBox);
  }

  Box get _settings => Hive.box(_settingsBox);
  Box get _dailyLogs => Hive.box(_dailyLogsBox);
  Box get _srmActivities => Hive.box(_srmActivitiesBox);
  Box get _medicationConfig => Hive.box(_medicationConfigBox);
  Box get _medicationIntake => Hive.box(_medicationIntakeBox);
  Box get _medicationSchedule => Hive.box(_medicationScheduleBox);
  Box get _lifeEvents => Hive.box(_lifeEventsBox);
  Box get _weightLogs => Hive.box(_weightLogsBox);
  Box get _medicalAppointments => Hive.box(_medicalAppointmentsBox);

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
  Future<String> exportDatabaseToJson() async {
    final Map<String, dynamic> result = {
      'export_date': DateTime.now().toIso8601String(),
      'app_version': '1.2.0',
      'tables': <String, dynamic>{},
    };
    
    (result['tables'] as Map<String, dynamic>)['settings'] = _settings.values.toList();
    (result['tables'] as Map<String, dynamic>)['daily_logs'] = _dailyLogs.values.toList();
    (result['tables'] as Map<String, dynamic>)['srm_activities'] = _srmActivities.values.toList();
    (result['tables'] as Map<String, dynamic>)['medication_config'] = _medicationConfig.values.toList();
    (result['tables'] as Map<String, dynamic>)['medication_intake'] = _medicationIntake.values.toList();
    (result['tables'] as Map<String, dynamic>)['life_events'] = _lifeEvents.values.toList();
    
    return jsonEncode(result);
  }

  @override
  Future<void> importDatabaseFromJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final tables = data['tables'] as Map<String, dynamic>;
    
    await clearAllData();
    
    if (tables['settings'] != null) {
      for (var row in tables['settings'] as List) {
        await _settings.put(row['id'] ?? DateTime.now().millisecondsSinceEpoch, row);
      }
    }
    if (tables['daily_logs'] != null) {
      for (var row in tables['daily_logs'] as List) {
        await _dailyLogs.put(row['date'], row);
      }
    }
    if (tables['srm_activities'] != null) {
      for (var row in tables['srm_activities'] as List) {
        await _srmActivities.put(DateTime.now().millisecondsSinceEpoch, row);
      }
    }
    if (tables['medication_config'] != null) {
      for (var row in tables['medication_config'] as List) {
        await _medicationConfig.put(DateTime.now().millisecondsSinceEpoch, row);
      }
    }
    if (tables['medication_intake'] != null) {
      for (var row in tables['medication_intake'] as List) {
        await _medicationIntake.put(DateTime.now().millisecondsSinceEpoch, row);
      }
    }
    if (tables['life_events'] != null) {
      for (var row in tables['life_events'] as List) {
        await _lifeEvents.put(DateTime.now().millisecondsSinceEpoch, row);
      }
    }
  }

  @override
  Future<void> clearAllData() async {
    await _dailyLogs.clear();
    await _srmActivities.clear();
    await _medicationIntake.clear();
    await _medicationConfig.clear();
    await _lifeEvents.clear();
    await _settings.clear();
  }

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
  // MEDICATION SCHEDULE
  // ===================
  
  @override
  Future<List<Map<String, dynamic>>> getMedicationSchedules() async {
    return _medicationSchedule.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<int> insertMedicationSchedule(int medicationId, String reminderTime, String daysOfWeek) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    await _medicationSchedule.put(id, {
      'medication_id': medicationId,
      'reminder_time': reminderTime,
      'days_of_week': daysOfWeek,
      'enabled': 1,
    });
    return id;
  }

  @override
  Future<int> updateMedicationSchedule(int id, Map<String, dynamic> data) async {
    await _medicationSchedule.put(id, data);
    return 1;
  }

  @override
  Future<int> deleteMedicationSchedule(int id) async {
    await _medicationSchedule.delete(id);
    return 1;
  }

  @override
  Future<List<Map<String, dynamic>>> getScheduledMedicationsForToday() async {
    final today = DateTime.now().weekday;
    final allSchedules = _medicationSchedule.values
        .where((e) => e['enabled'] == 1)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    
    return allSchedules.where((schedule) {
      final days = (schedule['days_of_week'] as String).split(',');
      return days.contains(today.toString());
    }).toList();
  }

  @override
  Future<int> confirmMedicationIntake(String date, int medicationId, int confirmed) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    await _medicationIntake.put(id, {
      'date': date,
      'medication_id': medicationId,
      'aantal_ingenomen': 1,
      'confirmed': confirmed,
      'confirmed_at': confirmed == 1 ? DateTime.now().toIso8601String() : null,
    });
    return id;
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

  // ===================
  // WEIGHT LOGS
  // ===================
  
  @override
  Future<int> insertWeightLog(String date, double weight, String? notes) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    await _weightLogs.put(id, {
      'id': id,
      'date': date,
      'weight': weight,
      'notes': notes,
    });
    return id;
  }

  Future<List<Map<String, dynamic>>> getWeightLogs() async {
    return _weightLogs.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
        ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
  }

  Future<Map<String, dynamic>?> getLatestWeightLog() async {
    final logs = await getWeightLogs();
    return logs.isNotEmpty ? logs.first : null;
  }

  Future<int> deleteWeightLog(int id) async {
    await _weightLogs.delete(id);
    return 1;
  }

  // ===================
  // MEDICAL APPOINTMENTS
  // ===================
  
  @override
  Future<int> insertMedicalAppointment(Map<String, dynamic> data) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    data['id'] = id;
    await _medicalAppointments.put(id, data);
    return id;
  }

  Future<List<Map<String, dynamic>>> getMedicalAppointments() async {
    return _medicalAppointments.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
        ..sort((a, b) => (a['appointment_date'] as String).compareTo(b['appointment_date'] as String));
  }

  Future<List<Map<String, dynamic>>> getUpcomingAppointments() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return _medicalAppointments.values
        .where((e) => (e['appointment_date'] as String).compareTo(today) >= 0)
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
        ..sort((a, b) => (a['appointment_date'] as String).compareTo(b['appointment_date'] as String));
  }

  Future<int> updateMedicalAppointment(int id, Map<String, dynamic> data) async {
    await _medicalAppointments.put(id, data);
    return 1;
  }

  Future<int> deleteMedicalAppointment(int id) async {
    await _medicalAppointments.delete(id);
    return 1;
  }
}
