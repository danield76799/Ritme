import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'database/database_repository.dart';
import 'database/hive_database_helper.dart';
import 'utils/logger.dart';

// Service locator - exports the db instance for use across the app
export 'database/database_repository.dart';

DatabaseRepository? _db;

/// Set a custom database instance (used in tests and screenshots).
void setDbForTesting(DatabaseRepository database) {
  _db = database;
}

/// Get the database instance (lazy initialization)
DatabaseRepository get db {
  if (_db == null) {
    throw StateError('Database not initialized. Call initDatabase() first.');
  }
  return _db!; // Safe: checked above
}

/// Ensure database is initialized before use
/// Returns immediately if already initialized
Future<void> ensureInitialized() async {
  if (_db != null) return;
  await initDatabase();
}

/// Initialize the appropriate database based on platform
Future<void> initDatabase() async {
  if (_db != null) return; // Already initialized
  
  AppLogger.debug('initDatabase: starting...');
  try {
    // Er is één backend: Hive. (De oude SQLite-implementatie voor iOS is
    // verwijderd — er komt geen iOS-versie.)
    if (kIsWeb) {
      AppLogger.debug('initDatabase: Hive (web)');
    } else {
      AppLogger.debug('initDatabase: Hive');
    }
    await Hive.initFlutter();
    await HiveDatabaseHelper.init();
    _db = HiveDatabaseHelper.instance;
    AppLogger.debug('initDatabase: completed successfully');
  } catch (e, stack) {
    AppLogger.error('Database initialization failed', error: e, stackTrace: stack);
    rethrow;
  }
}
