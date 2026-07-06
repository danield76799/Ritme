import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'database/database_repository.dart';
import 'database/database_helper.dart';
import 'database/hive_database_helper.dart';
import 'utils/database_cleanup.dart';
import 'utils/logger.dart';

// Service locator - exports the db instance for use across the app
export 'database/database_repository.dart';

DatabaseRepository? _db;

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
  AppLogger.debug('initDatabase: kIsWeb=$kIsWeb, Platform.isAndroid=${Platform.isAndroid}, Platform.isIOS=${Platform.isIOS}');
  
  try {
    if (kIsWeb) {
      AppLogger.debug('initDatabase: using Hive for web');
      await Hive.initFlutter();
      await HiveDatabaseHelper.init();
      _db = HiveDatabaseHelper.instance;
    } else if (Platform.isAndroid) {
      AppLogger.debug('initDatabase: using Hive for Android');
      await Hive.initFlutter();
      await HiveDatabaseHelper.init();
      _db = HiveDatabaseHelper.instance;
    } else {
      AppLogger.debug('initDatabase: using SQLite for iOS');
      _db = DatabaseHelper.instance;
      await _db!.getSettings();
    }
    AppLogger.debug('initDatabase: completed successfully');
    
    // Run one-time database cleanup for duplicate logs (v9 -> v10 migration)
    await _runDatabaseCleanupIfNeeded();
  } catch (e, stack) {
    AppLogger.error('Database initialization failed', error: e, stackTrace: stack);
    rethrow;
  }
}

/// Run database cleanup once after v10 migration
Future<void> _runDatabaseCleanupIfNeeded() async {
  try {
    // Only run for SQLite (Android uses Hive which doesn't have this issue)
    if (!kIsWeb && !Platform.isAndroid && Platform.isIOS) {
      await DatabaseCleanup.cleanupDuplicateLogs();
    }
  } catch (e) {
    AppLogger.warning('Database cleanup failed', error: e);
    // Don't rethrow - app should still work even if cleanup fails
  }
}
