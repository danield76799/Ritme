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
    final map = Map<String, dynamic>.from(data);
    if (!map.containsKey('id')) {
      map['id'] = 'user';
    }
    return map;
  }

  @override
  Future<int> insertSettings(Map<String, dynamic> settings) async {
    settings['id'] = 'user';
    await _settings.put('user', settings);
    return 1;
  }

  @override
  Future<int> updateSettings(String username, Map<String, dynamic> settings) async {
    settings['id'] = username;
    await _settings.put(username, settings);
    return 1;
  }

  @override
  Future<int> updateSettingsMap(Map<String, dynamic> settings) async {
    settings['id'] = 'user';
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
    data['id'] = date;
    await _dailyLogs.put(date, data);
    return 1;
  }

  @override
  Future<List<Map<String, dynamic>>> getDailyLogs() async {
    final logs = _dailyLogs.toMap().entries.map((entry) {
      final map = Map<String, dynamic>.from(entry.value);
      if (!map.containsKey('id')) {
        map['id'] = entry.key;
      }
      return map;
    }).toList();
    logs.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return logs;
  }

  @override
  Future<List<Map<String, dynamic>>> getDailyLogsForWeek() async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final logs = await getDailyLogs();
    return logs.where((log) {
      if (log['date'] == null) return false;
      try {
        final logDate = DateTime.parse(log['date']);
        return logDate.isAfter(weekAgo) || logDate.isAtSameMomentAs(weekAgo);
      } catch (e) {
        return false;
      }
    }).toList();
  }

  @override
  Future<Map<String, dynamic>?> getDailyLog(String date) async {
    final data = _dailyLogs.get(date);
    if (data == null) return null;
    final map = Map<String, dynamic>.from(data);
    if (!map.containsKey('id')) {
      map['id'] = date;
    }
    return map;
  }

  @override
  Future<int> upsertDailyLog(Map<String, dynamic> data) async {
    final date = data['date'] as String;
    data['id'] = date;
    await _dailyLogs.put(date, data);
    return 1;
  }

  // ===================
  // SRM ACTIVITIES
  // ===================
  
  @override
  Future<int> insertSrmActivity(String date, String activityType, String? actualTime, int? pScore, int? srtPoint) async {
    // Find existing record for this date + activity
    final existing = _srmActivities.values.where((e) =>
      e['date'] == date && e['activity_type'] == activityType
    ).toList();

    if (existing.isNotEmpty) {
      // Update existing record - use first found record's key
      final key = _srmActivities.keyAt(
        _srmActivities.values.toList().indexOf(existing.first)
      );
      await _srmActivities.put(key, {
        'id': key,
        'date': date,
        'activity_type': activityType,
        'actual_time': actualTime,
        'p_score': pScore,
        'srt_point': srtPoint,
      });
      return key;
    } else {
      // Insert new record
      final id = DateTime.now().millisecondsSinceEpoch;
      await _srmActivities.put(id, {
        'id': id,
        'date': date,
        'activity_type': activityType,
        'actual_time': actualTime,
        'p_score': pScore,
        'srt_point': srtPoint,
      });
      return id;
    }
  }

  @override
  Future<int> insertSrmActivityMap(Map<String, dynamic> data) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    data['id'] = id;
    await _srmActivities.put(id, data);
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getSrmActivities(String date) async {
    return _srmActivities.toMap().entries.where((entry) {
      return entry.value['date'] == date;
    }).map((entry) {
      final map = Map<String, dynamic>.from(entry.value);
      if (!map.containsKey('id')) {
        map['id'] = entry.key;
      }
      return map;
    }).toList();
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
    
    (result['tables'] as Map<String, dynamic>)['settings'] = _settings.toMap().values.toList();
    (result['tables'] as Map<String, dynamic>)['daily_logs'] = _dailyLogs.toMap().values.toList();
    (result['tables'] as Map<String, dynamic>)['srm_activities'] = _srmActivities.toMap().values.toList();
    (result['tables'] as Map<String, dynamic>)['medication_config'] = _medicationConfig.toMap().values.toList();
    (result['tables'] as Map<String, dynamic>)['medication_intake'] = _medicationIntake.toMap().values.toList();
    (result['tables'] as Map<String, dynamic>)['life_events'] = _lifeEvents.toMap().values.toList();
    
    return jsonEncode(result);
  }

  @override
  Future<void> importDatabaseFromJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final tables = data['tables'] as Map<String, dynamic>;
    
    await clearAllData();
    
    if (tables['settings'] != null) {
      for (var row in tables['settings'] as List) {
        final map = Map<String, dynamic>.from(row);
        if (!map.containsKey('id')) {
          map['id'] = 'user';
        }
        await _settings.put(map['id'], map);
      }
    }
    if (tables['daily_logs'] != null) {
      for (var row in tables['daily_logs'] as List) {
        final map = Map<String, dynamic>.from(row);
        if (!map.containsKey('id')) {
          map['id'] = map['date'] ?? DateTime.now().millisecondsSinceEpoch;
        }
        await _dailyLogs.put(map['id'], map);
      }
    }
    if (tables['srm_activities'] != null) {
      for (var row in tables['srm_activities'] as List) {
        final map = Map<String, dynamic>.from(row);
        if (!map.containsKey('id')) {
          map['id'] = DateTime.now().millisecondsSinceEpoch;
        }
        await _srmActivities.put(map['id'], map);
      }
    }
    if (tables['medication_config'] != null) {
      for (var row in tables['medication_config'] as List) {
        final map = Map<String, dynamic>.from(row);
        if (!map.containsKey('id')) {
          map['id'] = DateTime.now().millisecondsSinceEpoch;
        }
        await _medicationConfig.put(map['id'], map);
      }
    }
    if (tables['medication_intake'] != null) {
      for (var row in tables['medication_intake'] as List) {
        final map = Map<String, dynamic>.from(row);
        if (!map.containsKey('id')) {
          map['id'] = DateTime.now().millisecondsSinceEpoch;
        }
        await _medicationIntake.put(map['id'], map);
      }
    }
    if (tables['life_events'] != null) {
      for (var row in tables['life_events'] as List) {
        final map = Map<String, dynamic>.from(row);
        if (!map.containsKey('id')) {
          map['id'] = DateTime.now().millisecondsSinceEpoch;
        }
        await _lifeEvents.put(map['id'], map);
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
    await _medicationConfig.put(id, {'id': id, 'naam': naam, 'dosering': dosering, 'eenheid': eenheid});
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationConfigs() async {
    return _medicationConfig.toMap().entries.map((entry) {
      final map = Map<String, dynamic>.from(entry.value);
      // Ensure id is present (for backwards compatibility with old data)
      if (!map.containsKey('id')) {
        map['id'] = entry.key;
      }
      return map;
    }).toList();
  }

  // ===================
  // MEDICATION SCHEDULE
  // ===================
  
  @override
  Future<List<Map<String, dynamic>>> getMedicationSchedules() async {
    return _medicationSchedule.toMap().entries.map((entry) {
      final map = Map<String, dynamic>.from(entry.value);
      if (!map.containsKey('id')) {
        map['id'] = entry.key;
      }
      return map;
    }).toList();
  }

  @override
  Future<int> insertMedicationSchedule(int medicationId, String reminderTime, String daysOfWeek) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    await _medicationSchedule.put(id, {
      'id': id,
      'medication_id': medicationId,
      'reminder_time': reminderTime,
      'days_of_week': daysOfWeek,
      'enabled': 1,
    });
    return id;
  }

  @override
  Future<int> updateMedicationSchedule(int id, Map<String, dynamic> data) async {
    data['id'] = id;
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
    final allSchedules = _medicationSchedule.toMap().entries.map((entry) {
      final map = Map<String, dynamic>.from(entry.value);
      if (!map.containsKey('id')) {
        map['id'] = entry.key;
      }
      return map;
    }).toList();
    
    return allSchedules.where((schedule) {
      final days = (schedule['days_of_week'] as String).split(',');
      return days.contains(today.toString());
    }).toList();
  }

  @override
  Future<int> confirmMedicationIntake(String date, int medicationId, int confirmed) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    await _medicationIntake.put(id, {
      'id': id,
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
    // Find existing record for this date + medication
    final existing = _medicationIntake.values.where((e) =>
      e['date'] == date && e['medication_id'] == medicationId
    ).toList();

    if (existing.isNotEmpty) {
      // Update existing record - use first found record's key
      final key = _medicationIntake.keyAt(
        _medicationIntake.values.toList().indexOf(existing.first)
      );
      await _medicationIntake.put(key, {
        'id': key,
        'date': date,
        'medication_id': medicationId,
        'aantal_ingenomen': aantal,
      });
      return key;
    } else {
      // Insert new record
      final id = DateTime.now().millisecondsSinceEpoch;
      await _medicationIntake.put(id, {
        'id': id,
        'date': date,
        'medication_id': medicationId,
        'aantal_ingenomen': aantal,
      });
      return id;
    }
  }

  @override
  Future<int> insertMedicationIntakeMap(Map<String, dynamic> data) async {
    final date = data['date'] as String;
    final medicationId = data['medication_id'] as int;

    // Find existing record for this date + medication
    final existing = _medicationIntake.values.where((e) =>
      e['date'] == date && e['medication_id'] == medicationId
    ).toList();

    if (existing.isNotEmpty) {
      // Update existing record - use first found record's key
      final key = _medicationIntake.keyAt(
        _medicationIntake.values.toList().indexOf(existing.first)
      );
      await _medicationIntake.put(key, data..['id'] = key);
      return key;
    } else {
      // Insert new record
      final id = DateTime.now().millisecondsSinceEpoch;
      await _medicationIntake.put(id, data..['id'] = id);
      return id;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntake(String date) async {
    return _medicationIntake.toMap().entries.where((entry) {
      return entry.value['date'] == date;
    }).map((entry) {
      final map = Map<String, dynamic>.from(entry.value);
      // Ensure id is present
      if (!map.containsKey('id')) {
        map['id'] = entry.key;
      }
      return map;
    }).toList();
  }

  // ===================
  // LIFE EVENTS
  // ===================
  
  @override
  Future<int> insertLifeEvent(String date, String omschrijving, int invloed) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    await _lifeEvents.put(id, {
      'id': id,
      'date': date,
      'omschrijving': omschrijving,
      'invloed': invloed,
    });
    return id;
  }

  @override
  Future<int> insertLifeEventMap(Map<String, dynamic> data) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    data['id'] = id;
    await _lifeEvents.put(id, data);
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getLifeEvents(String date) async {
    return _lifeEvents.toMap().entries.where((entry) {
      return entry.value['date'] == date;
    }).map((entry) {
      final map = Map<String, dynamic>.from(entry.value);
      if (!map.containsKey('id')) {
        map['id'] = entry.key;
      }
      return map;
    }).toList();
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
    return _weightLogs.toMap().entries.map((entry) {
      final map = Map<String, dynamic>.from(entry.value);
      if (!map.containsKey('id')) {
        map['id'] = entry.key;
      }
      return map;
    }).toList()
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
    try {
      final id = DateTime.now().millisecondsSinceEpoch;
      data['id'] = id;
      print('Hive: Inserting medical appointment with id: $id, data: $data');
      await _medicalAppointments.put(id, data);
      print('Hive: Successfully inserted medical appointment');
      return id;
    } catch (e, stackTrace) {
      print('Hive: Error inserting medical appointment: $e');
      print('Hive: Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMedicalAppointments() async {
    return _medicalAppointments.toMap().entries.map((entry) {
      final map = Map<String, dynamic>.from(entry.value);
      if (!map.containsKey('id')) {
        map['id'] = entry.key;
      }
      return map;
    }).toList()
      ..sort((a, b) => (a['appointment_date'] as String).compareTo(b['appointment_date'] as String));
  }

  Future<List<Map<String, dynamic>>> getUpcomingAppointments() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return _medicalAppointments.toMap().entries.where((entry) {
      return (entry.value['appointment_date'] as String).compareTo(today) >= 0;
    }).map((entry) {
      final map = Map<String, dynamic>.from(entry.value);
      if (!map.containsKey('id')) {
        map['id'] = entry.key;
      }
      return map;
    }).toList()
      ..sort((a, b) => (a['appointment_date'] as String).compareTo(b['appointment_date'] as String));
  }

  Future<int> updateMedicalAppointment(int id, Map<String, dynamic> data) async {
    data['id'] = id;
    await _medicalAppointments.put(id, data);
    return 1;
  }

  Future<int> deleteMedicalAppointment(int id) async {
    await _medicalAppointments.delete(id);
    return 1;
  }
}