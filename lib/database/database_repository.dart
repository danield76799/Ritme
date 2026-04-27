/// Abstract database repository interface
/// Implements platform-specific database helpers (Hive for web, SQLite for mobile)
abstract class DatabaseRepository {
  // Settings
  Future<Map<String, dynamic>?> getSettings();
  Future<int> insertSettings(Map<String, dynamic> settings);
  Future<int> updateSettings(String username, Map<String, dynamic> settings);
  Future<int> updateSettingsMap(Map<String, dynamic> settings);
  Future<bool> hasPinSet();
  Future<bool> updatePin(String pin);
  Future<Map<String, dynamic>?> validateLoginPin(String pin);

  // Daily Logs
  Future<int> insertDailyLog(String date, Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> getDailyLogs();
  Future<Map<String, dynamic>?> getDailyLog(String date);
  Future<int> upsertDailyLog(Map<String, dynamic> data);

  // SRM Activities
  Future<int> insertSrmActivity(String date, String activityType, String? actualTime, int? pScore, int? srtPoint);
  Future<int> insertSrmActivityMap(Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> getSrmActivities(String date);

  // Medication Config
  Future<String> exportDatabaseToJson();
  Future<void> importDatabaseFromJson(String jsonString);
  Future<void> clearAllData();
  Future<int> insertMedicationConfig(String naam, String? dosering, String? eenheid);
  Future<List<Map<String, dynamic>>> getMedicationConfigs();

  // Medication Schedule
  Future<List<Map<String, dynamic>>> getMedicationSchedules();
  Future<int> insertMedicationSchedule(int medicationId, String reminderTime, String daysOfWeek);
  Future<int> updateMedicationSchedule(int id, Map<String, dynamic> data);
  Future<int> deleteMedicationSchedule(int id);
  Future<List<Map<String, dynamic>>> getScheduledMedicationsForToday();
  Future<int> confirmMedicationIntake(String date, int medicationId, int confirmed);

  // Medication Intake
  Future<int> insertMedicationIntake(String date, int medicationId, int aantal);
  Future<int> insertMedicationIntakeMap(Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> getMedicationIntake(String date);

  // Life Events
  Future<int> insertLifeEvent(String date, String omschrijving, int invloed);
  Future<int> insertLifeEventMap(Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> getLifeEvents(String date);

  // Weight Logs
  Future<int> insertWeightLog(String date, double weight, String? notes);
  Future<List<Map<String, dynamic>>> getWeightLogs();
  Future<Map<String, dynamic>?> getLatestWeightLog();
  Future<int> deleteWeightLog(int id);

  // Medical Appointments
  Future<int> insertMedicalAppointment(Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> getMedicalAppointments();
  Future<List<Map<String, dynamic>>> getUpcomingAppointments();
  Future<int> updateMedicalAppointment(int id, Map<String, dynamic> data);
  Future<int> deleteMedicalAppointment(int id);
}
