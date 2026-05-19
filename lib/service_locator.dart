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
  
  print('initDatabase: starting...');
  print('initDatabase: kIsWeb=$kIsWeb, Platform.isAndroid=${Platform.isAndroid}, Platform.isIOS=${Platform.isIOS}');
  
  try {
    if (kIsWeb) {
      print('initDatabase: using Hive for web');
      await Hive.initFlutter();
      await HiveDatabaseHelper.init();
      _db = HiveDatabaseHelper.instance;
    } else if (Platform.isAndroid) {
      print('initDatabase: using Hive for Android');
      await Hive.initFlutter();
      await HiveDatabaseHelper.init();
      _db = HiveDatabaseHelper.instance;
    } else {
      print('initDatabase: using SQLite for iOS');
      _db = DatabaseHelper.instance;
      await _db!.getSettings();
    }
    print('initDatabase: completed successfully');
  } catch (e, stack) {
    print('Database initialization failed: $e');
    print('Stack: $stack');
    rethrow;
  }
}
