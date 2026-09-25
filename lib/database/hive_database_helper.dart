import 'dart:convert';
import 'package:hive/hive.dart';
import '../utils/logger.dart';
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
  static const String _crisisPlanBox = 'crisis_plan';
  static const String _prodromalChecklistBox = 'prodromal_checklist';
  static const String _prodromalLogsBox = 'prodromal_logs';
  static const String _episodeLogsBox = 'episode_logs';
  static const String _moodAssessmentBox = 'mood_assessment';
  static const String _dagboekBoxName = 'daily_dagboek';
  HiveDatabaseHelper._init();

  static Future<void> init() async {
    if (Hive.isBoxOpen(_settingsBox)) return; // Already initialized
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
    await Hive.openBox(_episodeLogsBox);
    if (!Hive.isBoxOpen(_dagboekBoxName)) await Hive.openBox(_dagboekBoxName);
    if (!Hive.isBoxOpen(_moodAssessmentBox)) await Hive.openBox(_moodAssessmentBox);
    // Seed default prodromal checklist if empty
    final h = HiveDatabaseHelper.instance;
    await h._seedProdromalChecklistIfEmpty();
    // Migreer oude p_scores (eenmalig)
    final h2 = HiveDatabaseHelper.instance;
    await h2.migrateOldPScores();
    // Ruim de dubbele slaaprijen op die de oude insertSleepLog opstapelde
    // (eenmalig; laat per datum één rij staan).
    final h3 = HiveDatabaseHelper.instance;
    await h3.migrateDubbeleSlaaprijen();
  }

  Box get _settings => Hive.box(_settingsBox);
  Box get _dailyLogs => Hive.box(_dailyLogsBox);
  Box get _srmActivities => Hive.box(_srmActivitiesBox);
  Box get _medicationConfig => Hive.box(_medicationConfigBox);

  /// Unieke sleutel voor een nieuwe Hive-rij.
  ///
  /// Eerder gebruikten meerdere writers `DateTime.now().millisecondsSinceEpoch
  /// % 1000000`. Die modulo-bezetting herhaalt zich elke 1.000.000 ms (16 min
  /// 40 s), dus twee rijen die binnen dat venster werden geschreven kregen
  /// DEZELFDE sleutel en de tweede overschreef de eerste — stil dataverlies.
  /// Gemeten: 30 dagen innames wegschrijven liet 15 rijen over.
  ///
  /// Het bereik MOET klein blijven: de config-id wordt doorgegeven aan
  /// `notification_helper` als `(id % 90000) + 10000` voor de Android-melding,
  /// en het oude commentaar waarschuwde al voor 32-bit overflow. Daarom geen
  /// tijdstempel in milliseconden (13 cijfers) maar een teller die aansluit op
  /// het hoogste id dat al in de box staat: monotoon, dus nooit een botsing,
  /// en niet groter dan nodig.
  int _nieuweSleutel(Box box, {String? seed}) {
    int hoogste = 0;
    for (final k in box.keys) {
      final n = k is int ? k : int.tryParse(k.toString()) ?? 0;
      if (n > hoogste) hoogste = n;
    }
    if (hoogste > 0) return hoogste + 1;
    // Lege box: zaai met een tijdstempel binnen het oude bereik.
    if (seed != null) {
      final n = int.tryParse(seed) ?? 0;
      if (n > 0) return n;
    }
    return DateTime.now().millisecondsSinceEpoch % 1000000;
  }
  Box get _medicationIntake => Hive.box(_medicationIntakeBox);
  Box get _medicationSchedule => Hive.box(_medicationScheduleBox);
  Box get _lifeEvents => Hive.box(_lifeEventsBox);
  Box get _weightLogs => Hive.box(_weightLogsBox);
  Box get _medicalAppointments => Hive.box(_medicalAppointmentsBox);
  Box get _crisisPlan => Hive.box(_crisisPlanBox);
  Box get _prodromalChecklist => Hive.box(_prodromalChecklistBox);
  Box get _prodromalLogs => Hive.box(_prodromalLogsBox);
  Box get _episodeLogs => Hive.box(_episodeLogsBox);
  Box get _moodAssessment => Hive.box(_moodAssessmentBox);
  Box get _dagboekBox => Hive.box(_dagboekBoxName);

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
      final id = _nieuweSleutel(_prodromalChecklist) + sortOrder;
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
    
    // Group by date and MERGE all entries per date (vragenlijst schrijft
    // onder date-key, slaap-log onder int-key — samennemen i.p.v. winner
    // kiezen, anders verdwijnt stemming_hoog uit de dagrij).
    //
    // TWEE DINGEN DIE HIER MISGINGEN:
    //
    // 1. `insertSleepLog` zette elke ochtend-check-in als NIEUWE rij neer. Wie
    //    de bedtijd corrigeerde kreeg dus een tweede slaaprij ernaast, en deze
    //    merge laat de EERST geziene waarde winnen — de oude. De gecorrigeerde
    //    slaapduur stond wél in de opslag maar kwam nooit op het scherm. De
    //    slaapvelden komen daarom nu uit de rij met het HOOGSTE numerieke id
    //    (de laatst geschreven slaaprij).
    //
    // 2. `bed_time` betekent per rij iets ANDERS: de avond-check-in schrijft de
    //    bedtijd van DIE avond (onder de datum-sleutel), de ochtend-check-in de
    //    bedtijd van de avond ERVOOR (onder een numerieke sleutel). De
    //    datum-rij moet daarom voorrang houden — anders overschrijft de
    //    ochtendrij de avond en klopt de "je ging gisteren om X naar bed"-regel
    //    niet meer.
    Map<String, Map<String, dynamic>> mergedLogsByDate = {};
    final nieuwsteSlaaprij = <String, Map<String, dynamic>>{};
    final avondBedTijd = <String, String>{};
    int latestNumericId = 0;

    int numeriekId(Map<String, dynamic> rij) {
      final raw = rij['id'];
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    for (var log in logs) {
      final date = log['date']?.toString();
      if (date == null) continue;

      final existing = mergedLogsByDate[date];
      if (existing == null) {
        mergedLogsByDate[date] = log;
      } else {
        // Merge: vul ontbrekende velden aan (bestaande niet-null waarden winnen)
        existing.forEach((k, v) {
          if (v != null && log[k] == null) log[k] = v;
        });
        log.forEach((k, v) {
          if (v != null && (existing[k] == null)) existing[k] = v;
        });
        mergedLogsByDate[date] = existing;
      }

      // Nieuwste slaaprij per datum onthouden.
      if (log['sleep_hours'] != null) {
        final vorige = nieuwsteSlaaprij[date];
        if (vorige == null || numeriekId(log) >= numeriekId(vorige)) {
          nieuwsteSlaaprij[date] = log;
        }
      }

      // Bedtijd van de avond-check-in (datum-sleutel) apart houden.
      if (log['id']?.toString() == date &&
          (log['bed_time']?.toString().isNotEmpty ?? false)) {
        avondBedTijd[date] = log['bed_time'].toString();
      }

      // Hoogste numerieke id bijhouden (voor 'meest recent'-volgorde)
      final idNum = numeriekId(log);
      if (idNum > latestNumericId) latestNumericId = idNum;
    }

    // Slaapvelden uit de NIEUWSTE slaaprij; de avond-bedtijd houdt voorrang.
    mergedLogsByDate.forEach((date, rij) {
      final slaap = nieuwsteSlaaprij[date];
      if (slaap != null) {
        if (slaap['sleep_hours'] != null) rij['sleep_hours'] = slaap['sleep_hours'];
        if (slaap['wake_time'] != null) rij['wake_time'] = slaap['wake_time'];
      }
      final bed = avondBedTijd[date];
      if (bed != null) rij['bed_time'] = bed;
    });

    // Zorg dat elke dagrij het hoogste id draagt (consistentie met oud gedrag)
    for (var log in mergedLogsByDate.values) {
      final idNum = log['id'] is num
          ? (log['id'] as num).toInt()
          : int.tryParse(log['id'].toString()) ?? 0;
      if (idNum < latestNumericId) log['id'] = latestNumericId;
    }

    final groupedLogs = mergedLogsByDate.values.toList();
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
    // Deze rij hoort bij de OCHTEND-check-in: bed_time is de bedtijd van de
    // avond ERVÓÓR. De avond-check-in schrijft dezelfde datum onder de
    // datum-sleutel met bed_time van DIE avond — dat zijn twee verschillende
    // betekenissen, dus deze rij mag die nooit overschrijven.
    //
    // Maar hij mag zichzelf ook niet blijven stapelen: eerder deed elke
    // ochtend-check-in `_nextId++` en zette er een NIEUWE rij naast. Wie zijn
    // bedtijd corrigeerde kreeg zo een tweede slaaprij, en de lezer pakte de
    // oudste — de correctie kwam nooit op het scherm. Daarom: bestaat er al een
    // ochtendrij voor deze datum, werk die dan bij.
    dynamic bestaandeSleutel;
    for (final entry in _dailyLogs.toMap().entries) {
      final sleutelIsDatum = entry.key.toString() == date;
      final isSlaaprij = entry.value['date']?.toString() == date &&
          entry.value['sleep_hours'] != null;
      if (!sleutelIsDatum && isSlaaprij) {
        bestaandeSleutel = entry.key;
        break;
      }
    }

    final id = bestaandeSleutel ?? _nieuweSleutel(_dailyLogs);
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
    
    // Twee soorten rows voor dezelfde datum:
    //  - date-string row (avond-checkin): bed_time = de bedtijd van DIE avond ✓
    //  - int-key row (ochtend-checkin insertSleepLog): bed_time = bedtijd van de
    //    avond ERVÓÓR ✗ — die mag de avond-bedtijd nooit overschrijven.
    // Kies daarom de date-string row als die bed_time heeft; anders de laatste row.
    Map<String, dynamic>? best;
    for (final entry in logs) {
      final keyIsDate = entry.key is String;
      final hasBed = entry.value['bed_time'] != null &&
          entry.value['bed_time'].toString().isNotEmpty;
      if (keyIsDate && hasBed) {
        best = Map<String, dynamic>.from(entry.value);
        if (!best.containsKey('id')) best['id'] = entry.key;
        return best;
      }
    }
    best = Map<String, dynamic>.from(logs.last.value);
    if (!best.containsKey('id')) {
      best['id'] = logs.last.key;
    }
    return best;
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
      final id = _nieuweSleutel(_srmActivities);
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
    // Wordt gebruikt door backup-restore. `_nextId++` begon bij elke start op 1,
    // dus een restore overschreef de eerste rijen van de box (id 1, 2, 3 …).
    // Dezelfde veilige teller als de rest van dit bestand.
    final id = _nieuweSleutel(_srmActivities);
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

  /// Eenmalige opruiming van de dubbele dag-/slaaprijen die door de oude
  /// writers zijn ontstaan.
  ///
  /// `insertSleepLog` zette elke ochtend-check-in als nieuwe rij neer, dus een
  /// gecorrigeerde dag had meerdere slaaprijen. De lezer pakt nu de nieuwste
  /// (zie getDailyLogs), maar de oude rijen blijven anders voor altijd staan.
  /// Deze migratie laat per datum één slaaprij over — de laatst geschreven —
  /// en ruimt de rest op. De dagrij onder de datum-sleutel blijft ongemoeid,
  /// want die draagt de avond-bedtijd en de vragenlijstvelden.
  Future<void> migrateDubbeleSlaaprijen() async {
    const marker = 'migratie_dubbele_slaaprijen_v1';
    if (_settings.get(marker) == true) return;

    // Groepeer slaaprijen (niet-datum-sleutel) per datum.
    final perDatum = <String, List<dynamic>>{};
    for (final k in _dailyLogs.keys) {
      if (k.toString() == '') continue;
      final v = _dailyLogs.get(k);
      if (v == null) continue;
      final datum = v['date']?.toString();
      if (datum == null) continue;
      final isDatumSleutel = k.toString() == datum;
      if (isDatumSleutel) continue;              // dagrij: nooit aanraken
      if (v['sleep_hours'] == null) continue;    // geen slaaprij
      perDatum.putIfAbsent(datum, () => []).add(k);
    }

    int opgeruimd = 0;
    for (final entry in perDatum.entries) {
      final sleutels = entry.value;
      if (sleutels.length < 2) continue;
      // Bewaar de sleutel met het hoogste nummer = laatst geschreven.
      sleutels.sort((a, b) {
        final na = a is int ? a : int.tryParse(a.toString()) ?? 0;
        final nb = b is int ? b : int.tryParse(b.toString()) ?? 0;
        return na.compareTo(nb);
      });
      final bewaren = sleutels.last;
      for (final k in sleutels) {
        if (k == bewaren) continue;
        await _dailyLogs.delete(k);
        opgeruimd++;
      }
    }

    await _settings.put(marker, true);
    if (opgeruimd > 0) {
      AppLogger.debug('Slaapmigratie: $opgeruimd dubbele slaaprijen opgeruimd');
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
    (result['tables'] as Map<String, dynamic>)['episode_logs'] = _episodeLogs.toMap().values.map((e) {
      final map = Map<String, dynamic>.from(e);
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        cleanMap[key] = value?.toString() ?? value;
      });
      return cleanMap;
    }).toList();
    (result['tables'] as Map<String, dynamic>)['mood_assessment'] = _moodAssessment.toMap().values.map((e) {
      final map = Map<String, dynamic>.from(e);
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        cleanMap[key] = value?.toString() ?? value;
      });
      return cleanMap;
    }).toList();
    (result['tables'] as Map<String, dynamic>)['dagboek'] = _dagboekBox.toMap().values.map((e) {
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
          map['id'] = _nieuweSleutel(_crisisPlan);
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
          map['id'] = _nieuweSleutel(_prodromalChecklist);
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
          map['id'] = _nieuweSleutel(_prodromalLogs);
        }
        // Ensure all values are strings for Hive compatibility
        final cleanMap = <String, dynamic>{};
        map.forEach((key, value) {
          cleanMap[key] = value?.toString() ?? value;
        });
        await _prodromalLogs.put(map['id'], cleanMap);
      }
    }
    if (tables['episode_logs'] != null) {
      for (var row in tables['episode_logs'] as List) {
        final map = Map<String, dynamic>.from(row);
        if (!map.containsKey('id')) {
          map['id'] = _nieuweSleutel(_episodeLogs);
        }
        final cleanMap = <String, dynamic>{};
        map.forEach((key, value) {
          cleanMap[key] = value?.toString() ?? value;
        });
        await _episodeLogs.put(map['id'], cleanMap);
      }
    }
    if (tables['mood_assessment'] != null) {
      for (var row in tables['mood_assessment'] as List) {
        final map = Map<String, dynamic>.from(row);
        if (!map.containsKey('id')) {
          map['id'] = map['date'] ?? _nieuweSleutel(_moodAssessment);
        }
        final cleanMap = <String, dynamic>{};
        map.forEach((key, value) {
          cleanMap[key] = value?.toString() ?? value;
        });
        await _moodAssessment.put(map['id'], cleanMap);
      }
    }
    if (tables['dagboek'] != null) {
      for (var row in tables['dagboek'] as List) {
        final map = Map<String, dynamic>.from(row);
        if (!map.containsKey('id')) {
          map['id'] = map['date'] ?? _nieuweSleutel(_dagboekBox);
        }
        final cleanMap = <String, dynamic>{};
        map.forEach((key, value) {
          cleanMap[key] = value?.toString() ?? value;
        });
        await _dagboekBox.put(map['id'], cleanMap);
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
    await _episodeLogs.clear();
    await _moodAssessment.clear();
    await _dagboekBox.clear();
  }

  @override
  @override
  Future<int> insertMedicationConfig(String naam, String? dosering, String? eenheid, {bool reminderEnabled = true}) async {
    try {
      // Use a smaller ID to avoid 32-bit integer overflow
      final id = _nieuweSleutel(_medicationConfig); // Max 999,999
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
    // Soft-delete, zelfde als de SQLite-kant (database_helper.dart): het
    // medicijn verdwijnt uit de lijst maar de INNAME-HISTORIE BLIJFT. Eerder
    // wiste deze methode alle intakes van dat medicijn mee (cascade), waardoor
    // het verwijderen van één dag met terugwerkende kracht je hele historie
    // leegmaakte — je zag daarna nergens meer dat je het ooit genomen had.
    //
    // Schedules mogen wél weg: er hoeft geen herinnering meer af te gaan.
    final schedules = _medicationSchedule.toMap().entries.where((e) {
      final medId = e.value['medication_id'];
      return medId == id || medId == id.toString();
    });
    for (final s in schedules) {
      await _medicationSchedule.delete(s.key);
    }
    // Innames blijven staan; alleen de config krijgt de markering.
    final bestaand = _medicationConfig.get(id) ??
        _medicationConfig.get(id.toString());
    final gemarkeerd = <String, dynamic>{
      ...?bestaand?.cast<String, dynamic>(),
      'id': id,
      'deleted': '1',
    };
    await _medicationConfig.put(id, gemarkeerd);
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
      }).where((m) {
        final del = m['deleted'];
        return del == null || del == 0 || del == '0' || del == false;
      }).toList();
    } catch (e) {
      AppLogger.error('Error loading medication configs', error: e);
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationConfigsAll() async {
    // Hive backend: geen soft-delete filter, retourneer alles
    return getMedicationConfigs();
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
    final id = _nieuweSleutel(_medicationSchedule);
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
    final id = _nieuweSleutel(_medicationIntake);
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
    // Find existing record for this date + medication.
    //
    // De vergelijking moet TYPE-TOLERANT zijn: de SQLite->Hive migratie zet
    // elke waarde om naar een string (zie de migratie verderop), dus
    // `medication_id` is daar '555' terwijl de UI met int 555 schrijft. Een
    // strikte `==` vond de bestaande rij dan nooit en zette er elke keer een
    // NIEUWE naast — dat is de "tweede inname" die op het scherm verscheen
    // zodra je de dosering van een medicijn aanpaste.
    bool zelfdeMedicijn(dynamic raw) {
      final id = raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
      return id == medicationId;
    }

    dynamic bestaandeSleutel;
    for (final e in _medicationIntake.toMap().entries) {
      if (e.value['date'] == date && zelfdeMedicijn(e.value['medication_id'])) {
        bestaandeSleutel = e.key;
        break;
      }
    }

    if (bestaandeSleutel != null) {
      await _medicationIntake.put(bestaandeSleutel, {
        'id': bestaandeSleutel,
        'date': date.toString(),
        'medication_id': medicationId,
        'aantal_ingenomen': aantal,
      });
      return 1;
    }
    // Nog geen rij voor deze dag: nieuwe aanmaken.
    final id = DateTime.now().millisecondsSinceEpoch;
    await _medicationIntake.put(id, {
      'id': id,
      'date': date.toString(),
      'medication_id': medicationId,
      'aantal_ingenomen': aantal,
    });
    return id;
  }

  @override
  Future<int> insertMedicationIntakeMap(Map<String, dynamic> data) async {
    final date = data['date'] as String;
    final medicationId = data['medication_id'] as int;

    // Zelfde type-tolerantie als insertMedicationIntake: na de migratie staat
    // medication_id als string in de box. Een strikte `==` ziet de bestaande
    // rij niet en maakt een tweede aan — precies de dubbele inname.
    final existing = _medicationIntake.toMap().entries.where((e) {
      final raw = e.value['medication_id'];
      final id = raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
      return e.value['date'] == date && id == medicationId;
    }).toList();

    if (existing.isNotEmpty) {
      // Werk de gevonden rij bij — de entries dragen hun sleutel al.
      final key = existing.first.key;
      await _medicationIntake.put(key, {
        ...data,
        'id': key,
        'date': (data['date'] as String?)?.toString() ?? date,
        'medication_id': data['medication_id'] ?? medicationId,
        'aantal_ingenomen': data['aantal_ingenomen'] ?? 0,
      });
      return key;
    }
    // Nog geen rij: nieuwe aanmaken met kleinere ID tegen 32-bit overflow.
    final id = _nieuweSleutel(_medicationIntake);
    await _medicationIntake.put(id, {
      ...data,
      'id': id,
      'date': (data['date'] as String?)?.toString() ?? date,
      'medication_id': data['medication_id'] ?? medicationId,
      'aantal_ingenomen': data['aantal_ingenomen'] ?? 0,
    });
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntake(String date) async {
    try {
      return _medicationIntake.toMap().entries.where((entry) {
        return entry.value['date'] == date;
      }).map((entry) {
        final map = Map<String, dynamic>.from(entry.value);
        if (!map.containsKey('id')) map['id'] = entry.key;
        if (map['medication_id'] is String) {
          map['medication_id'] = int.tryParse(map['medication_id']) ?? 0;
        }
        final raw = map['aantal_ingenomen'];
        if (raw is String) {
          map['aantal_ingenomen'] = int.tryParse(raw) ?? 0;
        } else if (raw == null) {
          map['aantal_ingenomen'] = 0;
        }
        return map;
      }).toList();
    } catch (e) {
      AppLogger.error('Error loading medication intake', error: e);
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakeForMedication(int medicationId) async {
    try {
      return _medicationIntake.toMap().entries.where((entry) {
        final v = entry.value['medication_id'];
        final id = v is int ? v : int.tryParse(v?.toString() ?? '0') ?? 0;
        return id == medicationId;
      }).map((entry) {
        final map = Map<String, dynamic>.from(entry.value);
        if (!map.containsKey('id')) map['id'] = entry.key;
        final raw = map['aantal_ingenomen'];
        if (raw is String) {
          map['aantal_ingenomen'] = int.tryParse(raw) ?? 0;
        } else if (raw == null) {
          map['aantal_ingenomen'] = 0;
        }
        return map;
      }).toList();
    } catch (e) {
      AppLogger.error('Error loading medication intake by med', error: e);
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicationIntakeRange(String startDate, String endDate) async {
    try {
      return _medicationIntake.toMap().entries.where((entry) {
        final d = entry.value['date']?.toString() ?? '';
        return d.compareTo(startDate) >= 0 && d.compareTo(endDate) <= 0;
      }).map((entry) {
        final map = Map<String, dynamic>.from(entry.value);
        if (!map.containsKey('id')) map['id'] = entry.key;
        if (map['medication_id'] is String) {
          map['medication_id'] = int.tryParse(map['medication_id']) ?? 0;
        }
        final raw = map['aantal_ingenomen'];
        if (raw is String) {
          map['aantal_ingenomen'] = int.tryParse(raw) ?? 0;
        } else if (raw == null) {
          map['aantal_ingenomen'] = 0;
        }
        return map;
      }).toList();
    } catch (e) {
      AppLogger.error('Error loading medication intake range', error: e);
      return [];
    }
  }

  // ===================
  // LIFE EVENTS
  // ===================
  
  @override
  Future<int> insertLifeEvent(String date, String omschrijving, int invloed) async {
    // Use smaller ID to avoid 32-bit integer overflow in Hive
    final id = _nieuweSleutel(_lifeEvents);
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
    final id = _nieuweSleutel(_lifeEvents);
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

  /// Leest een DB-waarde als int (Hive bewaart soms String door de
  /// stringify in de getters; formulieren leveren int of String).
  static int _leesInt(dynamic v, int fallback) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  @override
  Future<int> insertMedicalAppointment(Map<String, dynamic> data) async {
    try {
      // Use a smaller ID to avoid 32-bit integer overflow in Hive (max 0xFFFFFFFF)
      final id = _nieuweSleutel(_medicalAppointments);
      
      // Ensure all values are properly typed for Hive.
      // reminder_days MOET als int bewaard blijven: het scherm vergelijkt
      // ermee (dropdown-waardes 0/1/3/7) en plant ermee. Viel eerder weg,
      // waardoor een opgeslagen herinnering als "geen" terugkwam.
      final cleanData = <String, dynamic>{
        'id': id,
        'title': data['title']?.toString() ?? '',
        'doctor_name': data['doctor_name']?.toString() ?? '',
        'location': data['location']?.toString() ?? '',
        'appointment_date': data['appointment_date']?.toString() ?? '',
        'appointment_time': data['appointment_time']?.toString() ?? '',
        'notes': data['notes']?.toString() ?? '',
        'reminder_days': _leesInt(data['reminder_days'], 0),
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
      // Ensure all values are properly typed. id en reminder_days blijven
      // int: het scherm vergelijkt reminder_days met 0/1/3/7 en geeft id als
      // int door aan cancelAppointmentReminder. Alles stringifyen brak beide.
      final cleanMap = <String, dynamic>{};
      map.forEach((key, value) {
        if (key == 'id' || key == 'reminder_days') {
          cleanMap[key] = _leesInt(value, 0);
        } else {
          cleanMap[key] = value?.toString() ?? value;
        }
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
    // Ensure all values are properly typed for Hive (zie insert: reminder_days als int).
    final cleanData = <String, dynamic>{
      'id': id,
      'title': data['title']?.toString() ?? '',
      'doctor_name': data['doctor_name']?.toString() ?? '',
      'location': data['location']?.toString() ?? '',
      'appointment_date': data['appointment_date']?.toString() ?? '',
      'appointment_time': data['appointment_time']?.toString() ?? '',
      'notes': data['notes']?.toString() ?? '',
      'reminder_days': _leesInt(data['reminder_days'], 0),
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
    final id = _nieuweSleutel(_prodromalChecklist);
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
    final id = _nieuweSleutel(_prodromalLogs);
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
    final id = _nieuweSleutel(_crisisPlan);
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
  Future<int> insertEpisode(Map<String, dynamic> data) async {
    final id = _nieuweSleutel(_episodeLogs);
    final clean = Map<String, dynamic>.from(data);
    clean['id'] = id;
    clean.forEach((key, value) {
      clean[key] = value?.toString() ?? value;
    });
    await _episodeLogs.put(id, clean);
    return id;
  }

  @override
  Future<int> updateEpisode(int id, Map<String, dynamic> data) async {
    final existing = _episodeLogs.get(id);
    if (existing == null) return 0;
    final merged = Map<String, dynamic>.from(existing);
    merged.addAll(data);
    merged['id'] = id;
    await _episodeLogs.put(id, merged);
    return 1;
  }

  @override
  Future<List<Map<String, dynamic>>> getEpisodes({String? type, int limit = 50}) async {
    var values = _episodeLogs.toMap().values.map((e) => Map<String, dynamic>.from(e)).toList();
    if (type != null) {
      values = values.where((e) => e['episode_type'] == type).toList();
    }
    values.sort((a, b) {
      final da = a['start_date']?.toString() ?? '';
      final db = b['start_date']?.toString() ?? '';
      return db.compareTo(da);
    });
    return values.take(limit).toList();
  }

  @override
  Future<Map<String, dynamic>?> getActiveEpisode() async {
    final values = _episodeLogs.toMap().values.map((e) => Map<String, dynamic>.from(e));
    final active = values.where((e) => e['end_date'] == null).toList();
    active.sort((a, b) {
      final da = a['start_date']?.toString() ?? '';
      final db = b['start_date']?.toString() ?? '';
      return db.compareTo(da);
    });
    return active.isNotEmpty ? active.first : null;
  }

  @override
  Future<int> endEpisode(int id, String endDate) async {
    final existing = _episodeLogs.get(id);
    if (existing == null) return 0;
    final merged = Map<String, dynamic>.from(existing);
    merged['end_date'] = endDate;
    merged['id'] = id;
    await _episodeLogs.put(id, merged);
    return 1;
  }

  @override
  Future<int> deleteEpisode(int id) async {
    await _episodeLogs.delete(id);
    return 1;
  }

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

  // ---- DAGBOEK (daily journal) ----

  @override
  Future<int> upsertDagboek(Map<String, dynamic> data) async {
    final date = data['date'] as String;
    data['id'] = date;
    await _dagboekBox.put(date, data);
    return 1;
  }

  @override
  Future<Map<String, dynamic>?> getDagboek(String date) async {
    final value = _dagboekBox.get(date);
    if (value == null) return null;
    return Map<String, dynamic>.from(value as Map);
  }

  @override
  Future<List<Map<String, dynamic>>> getDagboekRange(
    String startDate,
    String endDate,
  ) async {
    final results = <Map<String, dynamic>>[];
    for (final key in _dagboekBox.keys) {
      final date = key.toString();
      if (date.compareTo(startDate) >= 0 && date.compareTo(endDate) <= 0) {
        results.add(Map<String, dynamic>.from(_dagboekBox.get(key) as Map));
      }
    }
    results.sort(
      (a, b) => (a['date'] as String).compareTo(b['date'] as String),
    );
    return results;
  }
}