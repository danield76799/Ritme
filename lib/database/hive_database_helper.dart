import 'dart:convert';
import 'package:hive/hive.dart';
import '../utils/logger.dart';
import 'database_repository.dart';

class HiveDatabaseHelper implements DatabaseRepository {
  static int _nextId = 1;
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
  static const String _crisisPlanBox = 'crisis_plan';
  static const String _prodromalChecklistBox = 'prodromal_checklist';
  static const String _prodromalLogsBox = 'prodromal_logs';
  static const String _moodAssessmentBox = 'mood_assessment';

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
    await Hive.openBox(_crisisPlanBox);
    await Hive.openBox(_prodromalChecklistBox);
    await Hive.openBox(_prodromalLogsBox);
    await Hive.openBox(_moodAssessmentBox);
    // Seed default prodromal checklist if empty
    await instance._seedProdromalChecklistIfEmpty();
    // Migreer oude p_scores (eenmalig)
    await instance.migrateOldPScores();
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
  Box get _crisisPlan => Hive.box(_crisisPlanBox);
  Box get _prodromalChecklist => Hive.box(_prodromalChecklistBox);
  Box get _prodromalLogs => Hive.box(_prodromalLogsBox);
  Box get _moodAssessment => Hive.box(_moodAssessmentBox);

  Future<void> _seedProdromalChecklistIfEmpty() async {
    if (_prodromalChecklist.isNotEmpty) return;

    final defaults = [
      // Manie/hypomanie voortekenen
      {'category': 'manie', 'sign': 'Minder slaap nodig dan normaal', 'sort_order': 1, 'enabled': 1},
      {'category': 'manie', 'sign': 'Racing thoughts / gedachten die racen', 'sort_order': 2, 'enabled': 1},
      {'category': 'manie', 'sign': 'Meer energie dan normaal', 'sort_order': 3, 'enabled': 1},
      {'category': 'manie', 'sign': 'Sneller praten dan normaal', 'sort_order': 4, 'enabled': 1},
      {'category': 'manie', 'sign': 'Verhoogde prikkelbaarheid', 'sort_order': 5, 'enabled': 1},
      {'category': 'manie', 'sign': 'Meer uitgeven / risicogedrag', 'sort_order': 6, 'enabled': 1},
      {'category': 'manie', 'sign': 'Grotere plannen / grandioos denken', 'sort_order': 7, 'enabled': 1},
      {'category': 'manie', 'sign': 'Afleidbaar / slechte concentratie', 'sort_order': 8, 'enabled': 1},
      // Depressie voortekenen
      {'category': 'depressie', 'sign': 'Minder interesse in activiteiten', 'sort_order': 9, 'enabled': 1},
      {'category': 'depressie', 'sign': 'Vermoeidheid / weinig energie', 'sort_order': 10, 'enabled': 1},
      {'category': 'depressie', 'sign': 'Somberheid / verdriet', 'sort_order': 11, 'enabled': 1},
      {'category': 'depressie', 'sign': 'Meer slapen dan normaal', 'sort_order': 12, 'enabled': 1},
      {'category': 'depressie', 'sign': 'Eetlust verandering', 'sort_order': 13, 'enabled': 1},
      {'category': 'depressie', 'sign': 'Concentratieproblemen', 'sort_order': 14, 'enabled': 1},
      {'category': 'depressie', 'sign': 'Terugtrekken uit sociale contacten', 'sort_order': 15, 'enabled': 1},
      {'category': 'depressie', 'sign': 'Gevoelens van waardeloosheid', 'sort_order': 16, 'enabled': 1},
      // Gemengd/stress voortekenen
      {'category': 'gemengd', 'sign': 'Verhoogde stress / spanning', 'sort_order': 17, 'enabled': 1},
      {'category': 'gemengd', 'sign': 'Piekeren / malen', 'sort_order': 18, 'enabled': 1},
      {'category': 'gemengd', 'sign': 'Lichamelijke onrust', 'sort_order': 19, 'enabled': 1},
      {'category': 'gemengd', 'sign': 'Conflicten met anderen', 'sort_order': 20, 'enabled': 1},
    ];

    for (final item in defaults) {
      final sortOrder = item['sort_order'] is int ? item['sort_order'] as int : int.tryParse(item['sort_order'].toString()) ?? 0;
      final id = DateTime.now().millisecondsSinceEpoch % 1000000 + sortOrder;
      final data = Map<String, dynamic>.from(item);
      data['id'] = id;
      await _prodromalChecklist.put(id, data);
    }
  }

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
    // Ensure all values are properly typed
    final cleanMap = <String, dynamic>{};
    map.forEach((key, value) {
      cleanMap[key] = value?.toString() ?? value;
    });
    return cleanMap;
  }

  @override
  Future<int> insertSettings(Map<String, dynamic> settings) async {
    final cleanData = <String, dynamic>{};
    settings.forEach((key, value) {
      cleanData[key] = value?.toString() ?? value;
    });
    cleanData['id'] = 'user';
    await _settings.put('user', cleanData);
    return 1;
  }

  @override
  Future<int> updateSettings(String username, Map<String, dynamic> settings) async {
    final cleanData = <String, dynamic>{};
    settings.forEach((key, value) {
      cleanData[key] = value?.toString() ?? value;
    });
    cleanData['id'] = username;
    await _settings.put(username, cleanData);
    return 1;
  }

  @override
  Future<int> updateSettingsMap(Map<String, dynamic> settings) async {
    final cleanData = <String, dynamic>{};
    settings.forEach((key, value) {
      cleanData[key] = value?.toString() ?? value;
    });
    cleanData['id'] = 'user';
    await _settings.put('user', cleanData);
    return 1;
  }

  @override
  Future<int> updateBiometricEnabled(bool enabled) async {
    final existing = await getSettings() ?? <String, dynamic>{'id': 'user'};
    existing['biometric_enabled'] = enabled ? '1' : '0';
    await _settings.put('user', existing);
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
      existing['password_hash'] = pin.toString();
      await _settings.put('user', existing);
    } else {
      await _settings.put('user', {'id': 'user', 'username': 'user', 'password_hash': pin.toString()});
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
      return Map<String, dynamic>.from(map);
    }).toList();
    
    // Group by date and keep only the latest entry per date (by id/timestamp)
    Map<String, Map<String, dynamic>> latestLogsByDate = {};
    for (var log in logs) {
      final date = log['date']?.toString();
      if (date != null) {
        // Keep the entry with the highest id (most recent)
        // Parse ids as numbers for comparison
        final currentId = latestLogsByDate[date]?['id'];
        final newId = log['id'];
        
        bool shouldReplace = !latestLogsByDate.containsKey(date);
        if (!shouldReplace && currentId != null && newId != null) {
          // Parse as numbers if possible, otherwise compare as strings
          final currentNum = currentId is num ? currentId.toInt() : int.tryParse(currentId.toString()) ?? 0;
          final newNum = newId is num ? newId.toInt() : int.tryParse(newId.toString()) ?? 0;
          shouldReplace = newNum > currentNum;
        }
        
        if (shouldReplace) {
          latestLogsByDate[date] = log;
        }
      }
    }
    
    final groupedLogs = latestLogsByDate.values.toList();
    groupedLogs.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return groupedLogs;
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

  /// Batch query voor Hive: filter op datumrange
  @override
  Future<List<Map<String, dynamic>>> getDailyLogsRange(String startDate, String endDate) async {
    final logs = await getDailyLogs();
    return logs.where((log) {
      final date = log['date']?.toString() ?? '';
      return date.compareTo(startDate) >= 0 && date.compareTo(endDate) <= 0;
    }).toList();
  }

  /// Batch query voor Hive: filter op datumrange
  @override
  Future<List<Map<String, dynamic>>> getSrmActivitiesRange(String startDate, String endDate) async {
    final allActivities = _srmActivities.toMap().entries.map((entry) {
      final map = Map<String, dynamic>.from(entry.value);
      if (!map.containsKey('id')) map['id'] = entry.key;
      return map;
    }).toList();
    return allActivities.where((activity) {
      final date = activity['date']?.toString() ?? '';
      return date.compareTo(startDate) >= 0 && date.compareTo(endDate) <= 0;
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
    // Ensure all values are properly typed
    final cleanMap = <String, dynamic>{};
    map.forEach((key, value) {
      cleanMap[key] = value?.toString() ?? value;
    });
    return cleanMap;
  }

  @override
  Future<int> upsertDailyLog(Map<String, dynamic> data) async {
    final date = data['date'] as String;
    final cleanData = <String, dynamic>{};
    data.forEach((key, value) {
      cleanData[key] = value?.toString() ?? value;
    });
    cleanData['id'] = date;
    cleanData['date'] = date.toString();
    await _dailyLogs.put(date, cleanData);
    return 1;
  }

  // ===================
  // SLEEP TRACKING
  // ===================
  
  Future<int> insertSleepLog(String date, String bedTime, String wakeTime, int awakeMinutes) async {
    // Use incremental counter for unique IDs
    final id = _nextId++;
    await _dailyLogs.put(id, {
      'id': id,
      'date': date.toString(),
      'bed_time': bedTime.toString(),
      'wake_time': wakeTime.toString(),
      'awake_minutes': awakeMinutes,
      'sleep_hours': _calculateSleepHours(bedTime, wakeTime, awakeMinutes),
    });
    return id;
  }

  Future<Map<String, dynamic>?> getSleepLog(String date) async {
    final logs = _dailyLogs.toMap().entries.where((entry) {
      return entry.value['date'] == date && entry.value['bed_time'] != null;
    }).toList();
    
    if (logs.isEmpty) return null;
    
    final map = Map<String, dynamic>.from(logs.last.value);
    if (!map.containsKey('id')) {
      map['id'] = logs.last.key;
    }
    return map;
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
  // SRM ACTIVITIES
  // ===================
  
  @override
  Future<int> insertSrmActivity(String date, String activityType, String? actualTime, int? pScore, int? srtPoint, {String? targetTime}) async {
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
        'date': date.toString(),
        'activity_type': activityType.toString(),
        'actual_time': actualTime?.toString(),
        'p_score': pScore,
        'srt_point': srtPoint,
        'target_time': targetTime?.toString(),
      });
      return key;
    } else {
      // Insert new record with smaller ID
      final id = DateTime.now().millisecondsSinceEpoch % 1000000;
      await _srmActivities.put(id, {
        'id': id,
        'date': date.toString(),
        'activity_type': activityType.toString(),
        'actual_time': actualTime?.toString(),
        'p_score': pScore,
        'srt_point': srtPoint,
        'target_time': targetTime?.toString(),
      });
      return id;
    }
  }

  @override
  Future<int> insertSrmActivityMap(Map<String, dynamic> data) async {
    // Use incremental counter for unique IDs
    final id = _nextId++;
    final cleanData = <String, dynamic>{};
    data.forEach((key, value) {
      cleanData[key] = value?.toString() ?? value;
    });
    cleanData['id'] = id;
    await _srmActivities.put(id, cleanData);
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
      // Ensure all values are properly typed
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        if (key == 'p_score' || key == 'srt_point') {
          // Keep numeric fields as int
          if (value is int) {
            cleanMap[key] = value;
          } else if (value is String) {
            cleanMap[key] = int.tryParse(value) ?? 0;
          } else {
            cleanMap[key] = 0;
          }
        } else {
          cleanMap[key] = value?.toString() ?? value;
        }
      });
      return cleanMap;
    }).toList();
  }

  /// Migreer bestaande activiteiten: p_score=1 zonder target_time -> p_score=3
  Future<void> migrateOldPScores() async {
    int migrated = 0;
    for (var entry in _srmActivities.toMap().entries) {
      final data = entry.value;
      final pScore = data['p_score'];
      final targetTime = data['target_time'];
      
      // Als p_score=1 en er is geen target_time, upgrade naar 3
      if (pScore == 1 && (targetTime == null || targetTime.toString().isEmpty || targetTime == '--:--')) {
        final updated = Map<String, dynamic>.from(data);
        updated['p_score'] = 3;
        await _srmActivities.put(entry.key, updated);
        migrated++;
      }
    }
    if (migrated > 0) {
      AppLogger.debug('SRT migratie: $migrated activiteiten opgewaardeerd van p_score 1 naar 3');
    }
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
    
    (result['tables'] as Map<String, dynamic>)['settings'] = _settings.toMap().values.map((e) {
      final map = Map<String, dynamic>.from(e);
      // Convert all values to strings for consistent export
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        cleanMap[key] = value?.toString() ?? value;
      });
      return cleanMap;
    }).toList();
    (result['tables'] as Map<String, dynamic>)['daily_logs'] = _dailyLogs.toMap().values.map((e) {
      final map = Map<String, dynamic>.from(e);
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        cleanMap[key] = value?.toString() ?? value;
      });
      return cleanMap;
    }).toList();
    (result['tables'] as Map<String, dynamic>)['srm_activities'] = _srmActivities.toMap().values.map((e) {
      final map = Map<String, dynamic>.from(e);
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        cleanMap[key] = value?.toString() ?? value;
      });
      return cleanMap;
    }).toList();
    (result['tables'] as Map<String, dynamic>)['medication_config'] = _medicationConfig.toMap().values.map((e) {
      final map = Map<String, dynamic>.from(e);
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        cleanMap[key] = value?.toString() ?? value;
      });
      return cleanMap;
    }).toList();
    (result['tables'] as Map<String, dynamic>)['medication_intake'] = _medicationIntake.toMap().values.map((e) {
      final map = Map<String, dynamic>.from(e);
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        cleanMap[key] = value?.toString() ?? value;
      });
      return cleanMap;
    }).toList();
    (result['tables'] as Map<String, dynamic>)['life_events'] = _lifeEvents.toMap().values.map((e) {
      final map = Map<String, dynamic>.from(e);
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        cleanMap[key] = value?.toString() ?? value;
      });
      return cleanMap;
    }).toList();
    (result['tables'] as Map<String, dynamic>)['crisis_plan'] = _crisisPlan.toMap().values.map((e) {
      final map = Map<String, dynamic>.from(e);
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        cleanMap[key] = value?.toString() ?? value;
      });
      return cleanMap;
    }).toList();
    (result['tables'] as Map<String, dynamic>)['prodromal_checklist'] = _prodromalChecklist.toMap().values.map((e) {
      final map = Map<String, dynamic>.from(e);
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        cleanMap[key] = value?.toString() ?? value;
      });
      return cleanMap;
    }).toList();
    (result['tables'] as Map<String, dynamic>)['prodromal_logs'] = _prodromalLogs.toMap().values.map((e) {
      final map = Map<String, dynamic>.from(e);
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        cleanMap[key] = value?.toString() ?? value;
      });
      return cleanMap;
    }).toList();
    
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
        // Ensure all values are strings for Hive compatibility
        final cleanMap = <String, dynamic>{};
        map.forEach((key, value) {
          cleanMap[key] = value?.toString() ?? value;
        });
        await _settings.put(map['id'], cleanMap);
      }
    }
    if (tables['daily_logs'] != null) {
      for (var row in tables['daily_logs'] as List) {
        final map = Map<String, dynamic>.from(row);
        if (!map.containsKey('id')) {
          map['id'] = map['date'] ?? DateTime.now().millisecondsSinceEpoch;
        }
        // Ensure all values are strings for Hive compatibility
        final cleanMap = <String, dynamic>{};
        map.forEach((key, value) {
          cleanMap[key] = value?.toString() ?? value;
        });
        await _dailyLogs.put(map['id'], cleanMap);
      }
    }
    if (tables['srm_activities'] != null) {
      for (var row in tables['srm_activities'] as List) {
        final map = Map<String, dynamic>.from(row);
        if (!map.containsKey('id')) {
          map['id'] = DateTime.now().millisecondsSinceEpoch;
        }
        // Ensure all values are strings for Hive compatibility
        final cleanMap = <String, dynamic>{};
        map.forEach((key, value) {
          cleanMap[key] = value?.toString() ?? value;
        });
        await _srmActivities.put(map['id'], cleanMap);
      }
    }
    if (tables['medication_config'] != null) {
      for (var row in tables['medication_config'] as List) {
        final map = Map<String, dynamic>.from(row);
        if (!map.containsKey('id')) {
          map['id'] = DateTime.now().millisecondsSinceEpoch;
        }
        // Ensure all values are strings for Hive compatibility
        final cleanMap = <String, dynamic>{};
        map.forEach((key, value) {
          cleanMap[key] = value?.toString() ?? value;
        });
        await _medicationConfig.put(map['id'], cleanMap);
      }
    }
    if (tables['medication_intake'] != null) {
      for (var row in tables['medication_intake'] as List) {
        final map = Map<String, dynamic>.from(row);
        if (!map.containsKey('id')) {
          map['id'] = DateTime.now().millisecondsSinceEpoch;
        }
        // Ensure all values are strings for Hive compatibility
        final cleanMap = <String, dynamic>{};
        map.forEach((key, value) {
          cleanMap[key] = value?.toString() ?? value;
        });
        await _medicationIntake.put(map['id'], cleanMap);
      }
    }
    if (tables['life_events'] != null) {
      for (var row in tables['life_events'] as List) {
        final map = Map<String, dynamic>.from(row);
        if (!map.containsKey('id')) {
          map['id'] = DateTime.now().millisecondsSinceEpoch;
        }
        // Ensure all values are strings for Hive compatibility
        final cleanMap = <String, dynamic>{};
        map.forEach((key, value) {
          cleanMap[key] = value?.toString() ?? value;
        });
        await _lifeEvents.put(map['id'], cleanMap);
      }
    }
    if (tables['crisis_plan'] != null) {
      for (var row in tables['crisis_plan'] as List) {
        final map = Map<String, dynamic>.from(row);
        if (!map.containsKey('id')) {
          map['id'] = DateTime.now().millisecondsSinceEpoch % 1000000;
        }
        // Ensure all values are strings for Hive compatibility
        final cleanMap = <String, dynamic>{};
        map.forEach((key, value) {
          cleanMap[key] = value?.toString() ?? value;
        });
        await _crisisPlan.put(map['id'], cleanMap);
      }
    }
    if (tables['prodromal_checklist'] != null) {
      for (var row in tables['prodromal_checklist'] as List) {
        final map = Map<String, dynamic>.from(row);
        if (!map.containsKey('id')) {
          map['id'] = DateTime.now().millisecondsSinceEpoch % 1000000;
        }
        // Ensure all values are strings for Hive compatibility
        final cleanMap = <String, dynamic>{};
        map.forEach((key, value) {
          cleanMap[key] = value?.toString() ?? value;
        });
        await _prodromalChecklist.put(map['id'], cleanMap);
      }
    }
    if (tables['prodromal_logs'] != null) {
      for (var row in tables['prodromal_logs'] as List) {
        final map = Map<String, dynamic>.from(row);
        if (!map.containsKey('id')) {
          map['id'] = DateTime.now().millisecondsSinceEpoch % 1000000;
        }
        // Ensure all values are strings for Hive compatibility
        final cleanMap = <String, dynamic>{};
        map.forEach((key, value) {
          cleanMap[key] = value?.toString() ?? value;
        });
        await _prodromalLogs.put(map['id'], cleanMap);
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
    await _crisisPlan.clear();
    await _prodromalChecklist.clear();
    await _prodromalLogs.clear();
  }

  @override
  @override
  Future<int> insertMedicationConfig(String naam, String? dosering, String? eenheid, {bool reminderEnabled = true}) async {
    try {
      // Use a smaller ID to avoid 32-bit integer overflow
      final id = DateTime.now().millisecondsSinceEpoch % 1000000; // Max 999,999
      final data = {
        'id': id,
        'naam': naam.toString(),
        'dosering': dosering?.toString() ?? '',
        'eenheid': eenheid?.toString() ?? '',
        'reminder_enabled': reminderEnabled ? '1' : '0', // Store as string for consistency
      };
      await _medicationConfig.put(id, data);
      return id;
    } catch (e) {
      AppLogger.error('ERROR in insertMedicationConfig', error: e);
      rethrow;
    }
  }

  @override
  Future<int> deleteMedicationConfig(int id) async {
    // Cascade delete: remove schedules and intakes first
    final schedules = _medicationSchedule.toMap().entries.where((e) {
      final medId = e.value['medication_id'];
      return medId == id || medId == id.toString();
    });
    for (final s in schedules) {
      await _medicationSchedule.delete(s.key);
    }
    final intakes = _medicationIntake.toMap().entries.where((e) {
      final medId = e.value['medication_id'];
      return medId == id || medId == id.toString();
    });
    for (final i in intakes) {
      await _medicationIntake.delete(i.key);
    }
    // Try deleting with both int and string key
    await _medicationConfig.delete(id);
    await _medicationConfig.delete(id.toString());
    return 1;
  }

  @override
  Future<int> updateMedicationConfig(int id, Map<String, dynamic> data) async {
    final cleanData = <String, dynamic>{};
    data.forEach((key, value) {
      cleanData[key] = value?.toString() ?? value;
    });
    cleanData['id'] = id;
    await _medicationConfig.put(id, cleanData);
    return 1;
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationConfigs() async {
    try {
      return _medicationConfig.toMap().entries.map((entry) {
        final map = Map<String, dynamic>.from(entry.value);
        // Ensure id is present (for backwards compatibility with old data)
        if (!map.containsKey('id')) {
          map['id'] = entry.key;
        }
        // Ensure reminder_enabled has a default value
        if (!map.containsKey('reminder_enabled')) {
          map['reminder_enabled'] = '1';
        }
        // Keep id as int, convert other values to strings
        final cleanMap = <String, dynamic>{};
        map.forEach((key, value) {
          if (key == 'id') {
            cleanMap[key] = value is int ? value : int.tryParse(value.toString()) ?? entry.key;
          } else {
            cleanMap[key] = value?.toString() ?? value;
          }
        });
        return cleanMap;
      }).toList();
    } catch (e) {
      AppLogger.error('Error loading medication configs', error: e);
      return [];
    }
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
      // Ensure all values are properly typed
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        cleanMap[key] = value?.toString() ?? value;
      });
      return cleanMap;
    }).toList();
  }

  @override
  Future<int> insertMedicationSchedule(int medicationId, String reminderTime, String daysOfWeek) async {
    // Use smaller ID to avoid 32-bit integer overflow in Hive
    final id = DateTime.now().millisecondsSinceEpoch % 1000000;
    await _medicationSchedule.put(id, {
      'id': id,
      'medication_id': medicationId,
      'reminder_time': reminderTime.toString(),
      'days_of_week': daysOfWeek.toString(),
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
  Future<void> cleanupMedicationSchedulesAndCancelNotifications() async {
    final configs = await getMedicationConfigs();
    final configIds = configs.map((c) => c['id']).toSet();

    final entries = _medicationSchedule.toMap().entries.toList();
    // Group schedules per medication_id and keep only the most recent
    final schedulesByMedId = <dynamic, List<MapEntry<dynamic, dynamic>>>{};
    for (final entry in entries) {
      final map = Map<String, dynamic>.from(entry.value);
      final medId = map['medication_id'];
      schedulesByMedId.putIfAbsent(medId, () => []).add(entry);
    }

    for (final medId in schedulesByMedId.keys.toList()) {
      final medSchedules = schedulesByMedId[medId]!;
      // Delete orphaned schedules (medication doesn't exist)
      final medicationExists = configIds.contains(medId) || configIds.contains(medId?.toString());
      if (!medicationExists) {
        for (final entry in medSchedules) {
          await _medicationSchedule.delete(entry.key);
        }
        continue;
      }

      // Keep only the most recent schedule per medication
      medSchedules.sort((a, b) {
        final idA = a.value['id'] ?? a.key;
        final idB = b.value['id'] ?? b.key;
        final numA = idA is num ? idA.toInt() : int.tryParse(idA.toString()) ?? 0;
        final numB = idB is num ? idB.toInt() : int.tryParse(idB.toString()) ?? 0;
        return numB.compareTo(numA); // descending
      });

      for (int i = 1; i < medSchedules.length; i++) {
        await _medicationSchedule.delete(medSchedules[i].key);
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getScheduledMedicationsForToday() async {
    final today = DateTime.now().weekday;
    final allSchedules = _medicationSchedule.toMap().entries.map((entry) {
      final map = Map<String, dynamic>.from(entry.value);
      if (!map.containsKey('id')) {
        map['id'] = entry.key;
      }
      // Ensure all values are properly typed
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        cleanMap[key] = value?.toString() ?? value;
      });
      return cleanMap;
    }).toList();
    
    return allSchedules.where((schedule) {
      final days = (schedule['days_of_week'] as String).split(',');
      return days.contains(today.toString());
    }).toList();
  }

  @override
  Future<int> confirmMedicationIntake(String date, int medicationId, int confirmed) async {
    // Use smaller ID to avoid 32-bit integer overflow in Hive
    final id = DateTime.now().millisecondsSinceEpoch % 1000000;
    await _medicationIntake.put(id, {
      'id': id,
      'date': date.toString(),
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
        'date': date.toString(),
        'medication_id': medicationId,
        'aantal_ingenomen': aantal,
      });
      return key;
    } else {
      // Insert new record
      final id = DateTime.now().millisecondsSinceEpoch;
      await _medicationIntake.put(id, {
        'id': id,
        'date': date.toString(),
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
      await _medicationIntake.put(key, {
        ...data,
        'id': key,
        'date': (data['date'] as String?)?.toString() ?? date,
        'medication_id': data['medication_id'] ?? medicationId,
        'aantal_ingenomen': data['aantal_ingenomen'] ?? 0,
      });
      return key;
    } else {
      // Insert new record with smaller ID to avoid 32-bit overflow
      final id = DateTime.now().millisecondsSinceEpoch % 1000000;
      await _medicationIntake.put(id, {
        ...data,
        'id': id,
        'date': (data['date'] as String?)?.toString() ?? date,
        'medication_id': data['medication_id'] ?? medicationId,
        'aantal_ingenomen': data['aantal_ingenomen'] ?? 0,
      });
      return id;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntake(String date) async {
    try {
      return _medicationIntake.toMap().entries.where((entry) {
        return entry.value['date'] == date;
      }).map((entry) {
        final map = Map<String, dynamic>.from(entry.value);
        // Ensure id is present
        if (!map.containsKey('id')) {
          map['id'] = entry.key;
        }
        // Convert medication_id to int if it's a string
        if (map['medication_id'] is String) {
          map['medication_id'] = int.tryParse(map['medication_id']) ?? 0;
        }
        // Ensure all values are properly typed
        final cleanMap = <String, dynamic>{};
        map.forEach((key, value) {
          cleanMap[key] = value?.toString() ?? value;
        });
        return cleanMap;
      }).toList();
    } catch (e) {
      AppLogger.error('Error loading medication intake', error: e);
      return [];
    }
  }

  // ===================
  // LIFE EVENTS
  // ===================
  
  @override
  Future<int> insertLifeEvent(String date, String omschrijving, int invloed) async {
    // Use smaller ID to avoid 32-bit integer overflow in Hive
    final id = DateTime.now().millisecondsSinceEpoch % 1000000;
    await _lifeEvents.put(id, {
      'id': id,
      'date': date.toString(),
      'omschrijving': omschrijving.toString(),
      'invloed': invloed,
    });
    return id;
  }

  @override
  Future<int> insertLifeEventMap(Map<String, dynamic> data) async {
    // Use smaller ID to avoid 32-bit integer overflow in Hive
    final id = DateTime.now().millisecondsSinceEpoch % 1000000;
    final cleanData = <String, dynamic>{
      'id': id,
      'date': (data['date'] as String?)?.toString() ?? '',
      'omschrijving': (data['omschrijving'] as String?)?.toString() ?? '',
      'invloed': data['invloed'] ?? 0,
    };
    await _lifeEvents.put(id, cleanData);
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
      // Ensure all values are properly typed
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        cleanMap[key] = value?.toString() ?? value;
      });
      return cleanMap;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getAllLifeEvents() async {
    return _lifeEvents.toMap().entries.map((entry) {
      final map = Map<String, dynamic>.from(entry.value);
      if (!map.containsKey('id')) {
        map['id'] = entry.key;
      }
      // Ensure all values are properly typed
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        cleanMap[key] = value?.toString() ?? value;
      });
      return cleanMap;
    }).toList()
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
  }

  // ===================
  // WEIGHT LOGS
  // ===================
  
  @override
  Future<int> insertWeightLog(String date, double weight, String? notes) async {
    // Use date as key — one entry per date, automatic upsert
    await _weightLogs.put(date, {
      'id': date.hashCode,
      'date': date,
      'weight': weight,
      'notes': notes?.toString(),
    });
    return date.hashCode;
  }

  Future<List<Map<String, dynamic>>> getWeightLogs() async {
    return _weightLogs.toMap().entries.map((entry) {
      final map = Map<String, dynamic>.from(entry.value);
      // Use date-based ID for consistency
      final dateStr = map['date']?.toString() ?? entry.key.toString();
      map['id'] = dateStr.hashCode;
      // Ensure weight is a number, not a string
      if (map['weight'] is String) {
        map['weight'] = double.tryParse(map['weight']) ?? 0.0;
      }
      // Ensure all values are properly typed
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        if (key == 'weight') {
          cleanMap[key] = (value is num) ? value.toDouble() : double.tryParse(value.toString()) ?? 0.0;
        } else {
          cleanMap[key] = value?.toString() ?? value;
        }
      });
      return cleanMap;
    }).toList()
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
  }

  Future<Map<String, dynamic>?> getLatestWeightLog() async {
    final logs = await getWeightLogs();
    return logs.isNotEmpty ? logs.first : null;
  }

  Future<int> deleteWeightLog(int id) async {
    // Find entry by hashCode-based id and delete by key
    final entry = _weightLogs.toMap().entries.firstWhere(
      (e) => (e.value['date']?.toString().hashCode ?? e.key.hashCode) == id,
      orElse: () => MapEntry(null, null),
    );
    if (entry.key != null) {
      await _weightLogs.delete(entry.key);
    }
    return 1;
  }

  // ===================
  // MEDICAL APPOINTMENTS
  // ===================
  
  @override
  Future<int> insertMedicalAppointment(Map<String, dynamic> data) async {
    try {
      // Use a smaller ID to avoid 32-bit integer overflow in Hive (max 0xFFFFFFFF)
      final id = DateTime.now().millisecondsSinceEpoch % 1000000;
      
      // Ensure all values are properly typed for Hive
      final cleanData = <String, dynamic>{
        'id': id,
        'title': data['title']?.toString() ?? '',
        'doctor_name': data['doctor_name']?.toString() ?? '',
        'location': data['location']?.toString() ?? '',
        'appointment_date': data['appointment_date']?.toString() ?? '',
        'appointment_time': data['appointment_time']?.toString() ?? '',
        'notes': data['notes']?.toString() ?? '',
        'reminder_enabled': data['reminder_enabled']?.toString() ?? '1',
        'created_at': data['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      };
      
      AppLogger.debug('Hive: Inserting medical appointment with id: $id');
      await _medicalAppointments.put(id, cleanData);
      AppLogger.debug('Hive: Successfully inserted medical appointment');
      return id;
    } catch (e, stackTrace) {
      AppLogger.error('Hive: Error inserting medical appointment', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMedicalAppointments() async {
    return _medicalAppointments.toMap().entries.map((entry) {
      final map = Map<String, dynamic>.from(entry.value);
      if (!map.containsKey('id')) {
        map['id'] = entry.key;
      }
      // Ensure all values are properly typed
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        cleanMap[key] = value?.toString() ?? value;
      });
      return cleanMap;
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
      // Ensure all values are properly typed
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        cleanMap[key] = value?.toString() ?? value;
      });
      return cleanMap;
    }).toList()
      ..sort((a, b) => (a['appointment_date'] as String).compareTo(b['appointment_date'] as String));
  }

  Future<int> updateMedicalAppointment(int id, Map<String, dynamic> data) async {
    // Ensure all values are properly typed for Hive
    final cleanData = <String, dynamic>{
      'id': id,
      'title': data['title']?.toString() ?? '',
      'doctor_name': data['doctor_name']?.toString() ?? '',
      'location': data['location']?.toString() ?? '',
      'appointment_date': data['appointment_date']?.toString() ?? '',
      'appointment_time': data['appointment_time']?.toString() ?? '',
      'notes': data['notes']?.toString() ?? '',
      'reminder_enabled': data['reminder_enabled']?.toString() ?? '1',
      'created_at': data['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    };
    await _medicalAppointments.put(id, cleanData);
    return 1;
  }

  Future<int> deleteMedicalAppointment(int id) async {
    await _medicalAppointments.delete(id);
    return 1;
  }

  // ===================
  // BIPOIRE STOORNIS v3 (Hive stubs — web fallback)
  // ===================

  @override
  Future<List<Map<String, dynamic>>> getProdromalChecklist() async {
    return _prodromalChecklist.toMap().entries.map((entry) {
      final map = Map<String, dynamic>.from(entry.value);
      if (!map.containsKey('id')) {
        map['id'] = entry.key;
      }
      // Preserve id and sort_order as int, keep others as-is
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        if (key == 'id' || key == 'sort_order') {
          cleanMap[key] = value is int ? value : int.tryParse(value.toString()) ?? 0;
        } else if (key == 'enabled') {
          cleanMap[key] = value == 1 || value == '1' || value == true;
        } else {
          cleanMap[key] = value?.toString() ?? value;
        }
      });
      return cleanMap;
    }).toList()
      ..sort((a, b) {
        final aOrder = a['sort_order'] is int ? a['sort_order'] : int.tryParse(a['sort_order']?.toString() ?? '0') ?? 0;
        final bOrder = b['sort_order'] is int ? b['sort_order'] : int.tryParse(b['sort_order']?.toString() ?? '0') ?? 0;
        return aOrder.compareTo(bOrder);
      });
  }

  @override
  Future<List<Map<String, dynamic>>> getEnabledProdromalChecklist() async {
    final all = await getProdromalChecklist();
    return all.where((item) {
      final enabled = item['enabled'];
      return enabled == true || enabled == 1 || enabled == '1';
    }).toList();
  }

  @override
  Future<int> insertProdromalSign(Map<String, dynamic> data) async {
    final id = DateTime.now().millisecondsSinceEpoch % 1000000;
    final cleanData = <String, dynamic>{};
    data.forEach((key, value) {
      if (key == 'id' || key == 'sort_order') {
        cleanData[key] = value is int ? value : int.tryParse(value.toString()) ?? 0;
      } else if (key == 'enabled') {
        cleanData[key] = value == true || value == 1 || value == '1' ? 1 : 0;
      } else {
        cleanData[key] = value?.toString() ?? value;
      }
    });
    cleanData['id'] = id;
    cleanData['enabled'] = cleanData['enabled'] ?? 1;
    await _prodromalChecklist.put(id, cleanData);
    return id;
  }

  @override
  Future<int> updateProdromalSign(int id, Map<String, dynamic> data) async {
    final cleanData = <String, dynamic>{};
    data.forEach((key, value) {
      if (key == 'id' || key == 'sort_order') {
        cleanData[key] = value is int ? value : int.tryParse(value.toString()) ?? 0;
      } else if (key == 'enabled') {
        cleanData[key] = value == true || value == 1 || value == '1' ? 1 : 0;
      } else {
        cleanData[key] = value?.toString() ?? value;
      }
    });
    cleanData['id'] = id;
    await _prodromalChecklist.put(id, cleanData);
    return 1;
  }

  @override
  Future<int> deleteProdromalSign(int id) async {
    await _prodromalChecklist.delete(id);
    return 1;
  }

  @override
  Future<int> insertProdromalLog(Map<String, dynamic> data) async {
    final id = DateTime.now().millisecondsSinceEpoch % 1000000;
    final cleanData = <String, dynamic>{};
    data.forEach((key, value) {
      cleanData[key] = value?.toString() ?? value;
    });
    cleanData['id'] = id;
    await _prodromalLogs.put(id, cleanData);
    return id;
  }

  @override
  Future<void> upsertProdromalLog(Map<String, dynamic> data) async {
    final date = data['date']?.toString();
    final checklistId = data['checklist_id'];
    if (date == null || checklistId == null) return;
    
    // Find existing log for this date + checklist_id
    final existing = _prodromalLogs.toMap().entries.where((entry) {
      return entry.value['date'] == date && entry.value['checklist_id'].toString() == checklistId.toString();
    }).toList();
    
    if (existing.isNotEmpty) {
      // Update existing
      final id = existing.first.key;
      final updated = Map<String, dynamic>.from(existing.first.value);
      data.forEach((key, value) {
        updated[key] = value?.toString() ?? value;
      });
      await _prodromalLogs.put(id, updated);
    } else {
      // Insert new
      await insertProdromalLog(data);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getProdromalLogs(String date) async {
    return _prodromalLogs.toMap().entries.where((entry) {
      return entry.value['date'] == date;
    }).map((entry) {
      final map = Map<String, dynamic>.from(entry.value);
      if (!map.containsKey('id')) {
        map['id'] = entry.key;
      }
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        if (key == 'present' || key == 'severity' || key == 'checklist_id') {
          if (value is int) {
            cleanMap[key] = value;
          } else if (value is String) {
            cleanMap[key] = int.tryParse(value) ?? 0;
          } else {
            cleanMap[key] = 0;
          }
        } else {
          cleanMap[key] = value?.toString() ?? value;
        }
      });
      return cleanMap;
    }).toList();
  }

  @override
  Future<Map<String, dynamic>?> getProdromalSummary(String date) async {
    final logs = await getProdromalLogs(date);
    final checklist = await getProdromalChecklist();
    
    int manieCount = 0;
    int depressieCount = 0;
    int gemengdCount = 0;
    
    for (var log in logs) {
      if ((log['present'] ?? 0) == 1) {
        final cid = log['checklist_id'];
        final item = checklist.firstWhere(
          (c) => c['id'].toString() == cid.toString(),
          orElse: () => <String, dynamic>{},
        );
        final category = item['category']?.toString() ?? '';
        if (category == 'manie') manieCount++;
        else if (category == 'depressie') depressieCount++;
        else if (category == 'gemengd') gemengdCount++;
      }
    }
    
    return {
      'date': date,
      'manie_count': manieCount,
      'depressie_count': depressieCount,
      'gemengd_count': gemengdCount,
      'total': manieCount + depressieCount + gemengdCount,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getRecentProdromalTrends(int days) async {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days));
    
    // Group logs by date and count warnings per day
    final Map<String, int> countsByDate = {};
    
    for (var entry in _prodromalLogs.toMap().entries) {
      final log = Map<String, dynamic>.from(entry.value);
      final dateStr = log['date']?.toString() ?? '';
      if (dateStr.isEmpty) continue;
      
      try {
        final logDate = DateTime.parse(dateStr);
        if (logDate.isBefore(cutoff)) continue;
        
        final present = log['present'] is int ? log['present'] : int.tryParse(log['present']?.toString() ?? '0') ?? 0;
        if (present == 1) {
          countsByDate[dateStr] = (countsByDate[dateStr] ?? 0) + 1;
        }
      } catch (_) {}
    }
    
    final result = countsByDate.entries.map((e) {
      return <String, dynamic>{
        'date': e.key,
        'warning_count': e.value,
      };
    }).toList();
    
    result.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return result;
  }

  @override
  Future<String?> getLastProdromalDate() async {
    String? lastDate;
    for (var entry in _prodromalLogs.toMap().entries) {
      final log = Map<String, dynamic>.from(entry.value);
      final dateStr = log['date']?.toString() ?? '';
      if (dateStr.isEmpty) continue;
      if (lastDate == null || dateStr.compareTo(lastDate) > 0) {
        lastDate = dateStr;
      }
    }
    return lastDate;
  }

  @override
  Future<void> copyProdromalLogs(String fromDate, String toDate) async {
    // Delete existing logs for target date first
    final existingKeys = _prodromalLogs.toMap().entries
        .where((e) => e.value['date'] == toDate)
        .map((e) => e.key)
        .toList();
    for (var key in existingKeys) {
      await _prodromalLogs.delete(key);
    }

    // Copy logs from source date
    final sourceLogs = await getProdromalLogs(fromDate);
    for (var log in sourceLogs) {
      final newLog = Map<String, dynamic>.from(log);
      newLog['date'] = toDate;
      newLog.remove('id');
      await insertProdromalLog(newLog);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCrisisPlan() async {
    return _crisisPlan.toMap().entries.map((entry) {
      final map = Map<String, dynamic>.from(entry.value);
      // Ensure id is always present and is an int
      map['id'] = entry.key;
      return map;
    }).toList()
      ..sort((a, b) {
        final aOrder = int.tryParse(a['sort_order']?.toString() ?? '0') ?? 0;
        final bOrder = int.tryParse(b['sort_order']?.toString() ?? '0') ?? 0;
        return aOrder.compareTo(bOrder);
      });
  }

  @override
  Future<int> insertCrisisPlanSection(Map<String, dynamic> data) async {
    final id = DateTime.now().millisecondsSinceEpoch % 1000000;
    final cleanData = <String, dynamic>{};
    data.forEach((key, value) {
      cleanData[key] = value?.toString() ?? value;
    });
    cleanData['id'] = id;
    await _crisisPlan.put(id, cleanData);
    return id;
  }

  @override
  Future<int> updateCrisisPlanSection(int id, Map<String, dynamic> data) async {
    final cleanData = <String, dynamic>{};
    data.forEach((key, value) {
      cleanData[key] = value?.toString() ?? value;
    });
    cleanData['id'] = id;
    await _crisisPlan.put(id, cleanData);
    return 1;
  }

  @override
  Future<int> updateCrisisPlanSectionBySection(String section, Map<String, dynamic> data) async {
    // Find the entry with matching section key
    final entries = _crisisPlan.toMap().entries.toList();
    for (final entry in entries) {
      final map = Map<String, dynamic>.from(entry.value);
      if (map['section'] == section) {
        final cleanData = <String, dynamic>{};
        data.forEach((key, value) {
          cleanData[key] = value?.toString() ?? value;
        });
        cleanData['id'] = entry.key;
        cleanData['section'] = section; // Keep the section key
        await _crisisPlan.put(entry.key, cleanData);
        return 1;
      }
    }
    return 0; // No matching section found
  }

  @override
  Future<int> deleteCrisisPlanSection(int id) async {
    await _crisisPlan.delete(id);
    return 1;
  }

  @override
  Future<int> insertEpisode(Map<String, dynamic> data) async => 0;

  @override
  Future<int> updateEpisode(int id, Map<String, dynamic> data) async => 0;

  @override
  Future<List<Map<String, dynamic>>> getEpisodes({String? type, int limit = 50}) async {
    return [];
  }

  @override
  Future<Map<String, dynamic>?> getActiveEpisode() async => null;

  @override
  Future<int> endEpisode(int id, String endDate) async => 0;

  @override
  Future<int> deleteEpisode(int id) async => 0;

  @override
  Future<int> insertMedicationLevel(Map<String, dynamic> data) async => 0;

  @override
  Future<List<Map<String, dynamic>>> getMedicationLevels(int medicationId) async {
    return [];
  }

  @override
  Future<Map<String, dynamic>?> getLatestMedicationLevel(int medicationId) async => null;

  // ---- MOOD ASSESSMENT ----

  @override
  Future<int> upsertMoodAssessment(Map<String, dynamic> data) async {
    final date = data['date'] as String;
    data['id'] = date;
    await _moodAssessment.put(date, data);
    return 1;
  }

  @override
  Future<Map<String, dynamic>?> getMoodAssessment(String date) async {
    final value = _moodAssessment.get(date);
    if (value == null) return null;
    return Map<String, dynamic>.from(value as Map);
  }

  @override
  Future<List<Map<String, dynamic>>> getMoodAssessmentRange(
    String startDate,
    String endDate,
  ) async {
    final results = <Map<String, dynamic>>[];
    for (final key in _moodAssessment.keys) {
      final date = key.toString();
      if (date.compareTo(startDate) >= 0 && date.compareTo(endDate) <= 0) {
        results.add(Map<String, dynamic>.from(_moodAssessment.get(key) as Map));
      }
    }
    results.sort(
      (a, b) => (a['date'] as String).compareTo(b['date'] as String),
    );
    return results;
  }
}