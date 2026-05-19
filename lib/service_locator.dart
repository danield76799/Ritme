import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  
  try {
    if (kIsWeb) {
      // Use Hive for web
      await Hive.initFlutter();
      await HiveDatabaseHelper.init();
      _db = HiveDatabaseHelper.instance;
    } else if (Platform.isAndroid) {
      // Use Hive for Android (reliable, no read-only issues)
      await Hive.initFlutter();
      await HiveDatabaseHelper.init();
      _db = HiveDatabaseHelper.instance;
    } else {
      // Use SQLite for iOS
      _db = DatabaseHelper.instance;
      // Test database connectivity
      await _db!.getSettings();
    }
  } catch (e) {
    print('Database initialization failed: $e');
    // Fallback: use in-memory database or show error
    throw Exception('Database initialization failed: $e');
  }
}
