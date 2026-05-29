import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ritme/database/database_helper.dart';

void main() {
  // Initialize sqflite_ffi for testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseHelper', () {
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper.instance;
      // Use in-memory database for testing
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 3,
        onCreate: (db, version) async {
          // Create minimal schema for testing
          await db.execute('''
            CREATE TABLE daily_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL UNIQUE,
              stemming_hoog REAL DEFAULT 0,
              stemming_laag REAL DEFAULT 0,
              created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
          ''');
        },
      );
    });

    tearDown(() async {
      await dbHelper.database.then((db) => db.close());
    });

    test('should insert and retrieve daily log', () async {
      final db = await dbHelper.database;
      
      // Insert test data
      await db.insert('daily_logs', {
        'date': '2024-01-15',
        'stemming_hoog': 3.0,
        'stemming_laag': -2.0,
      });

      // Retrieve
      final result = await db.query(
        'daily_logs',
        where: 'date = ?',
        whereArgs: ['2024-01-15'],
      );

      expect(result.length, equals(1));
      expect(result.first['stemming_hoog'], equals(3.0));
      expect(result.first['stemming_laag'], equals(-2.0));
    });

    test('should enforce unique date constraint', () async {
      final db = await dbHelper.database;
      
      await db.insert('daily_logs', {
        'date': '2024-01-15',
        'stemming_hoog': 3.0,
      });

      // Should throw exception for duplicate date
      expect(
        () async => await db.insert('daily_logs', {
          'date': '2024-01-15',
          'stemming_laag': -2.0,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
