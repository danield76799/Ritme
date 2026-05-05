import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'database/database_repository.dart';
import 'database/database_helper.dart';
import 'database/hive_database_helper.dart';

// Service locator - exports the db instance for use across the app
export 'database/database_repository.dart';

DatabaseRepository? _db;

/// Get the database instance (lazy initialization)
DatabaseRepository get db {
  if (_db == null) {
    throw StateError('Database not initialized. Call initDatabase() first.');
  }
  return _db!;
}

/// Initialize the appropriate database based on platform
Future<void> initDatabase() async {
  if (_db != null) return; // Already initialized
  
  if (kIsWeb) {
    // Use Hive for web
    await Hive.initFlutter();
    await HiveDatabaseHelper.init();
    _db = HiveDatabaseHelper.instance;
  } else {
    // Use SQLite for mobile
    _db = DatabaseHelper.instance;
  }
}
