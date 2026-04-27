import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'database/database_repository.dart';
import 'database/database_helper.dart';
import 'database/hive_database_helper.dart';

// Service locator - selects the right database based on platform
late DatabaseRepository db;

Future<void> initDatabase() async {
  if (kIsWeb) {
    // Use Hive for web
    await Hive.initFlutter();
    await HiveDatabaseHelper.init();
    db = HiveDatabaseHelper.instance;
  } else {
    // Use SQLite for mobile
    db = DatabaseHelper.instance;
  }
}
