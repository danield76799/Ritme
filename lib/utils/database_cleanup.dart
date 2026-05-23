import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Database cleanup utility to fix duplicate daily_logs entries
class DatabaseCleanup {
  static Future<void> cleanupDuplicateLogs() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dbDir = Directory(p.join(appDir.path, 'databases'));
    final dbPath = p.join(dbDir.path, 'ritme_app_v9.db');
    
    if (!await File(dbPath).exists()) {
      print('Database not found at $dbPath');
      return;
    }
    
    final db = await openDatabase(dbPath);
    
    try {
      // Start transaction
      await db.transaction((txn) async {
        // Find all dates with multiple entries
        final duplicateDates = await txn.rawQuery('''
          SELECT date, COUNT(*) as count 
          FROM daily_logs 
          GROUP BY date 
          HAVING count > 1
        ''');
        
        print('Found ${duplicateDates.length} dates with duplicate entries');
        
        for (var dup in duplicateDates) {
          final date = dup['date'] as String;
          final count = dup['count'] as int;
          
          print('Processing date $date with $count entries');
          
          // Get all entries for this date
          final entries = await txn.query(
            'daily_logs',
            where: 'date = ?',
            whereArgs: [date],
            orderBy: 'id DESC',
          );
          
          if (entries.isEmpty) continue;
          
          // Merge data: take the latest non-null values from all entries
          final merged = Map<String, dynamic>.from(entries.first);
          
          for (var i = 1; i < entries.length; i++) {
            final entry = entries[i];
            entry.forEach((key, value) {
              if (value != null && merged[key] == null) {
                merged[key] = value;
              }
            });
          }
          
          // Keep only the first (latest) entry, update it with merged data
          final keepId = entries.first['id'];
          
          // Delete all other entries
          await txn.delete(
            'daily_logs',
            where: 'date = ? AND id != ?',
            whereArgs: [date, keepId],
          );
          
          // Update the kept entry with merged data
          final updateData = Map<String, dynamic>.from(merged);
          updateData.remove('id');
          updateData.remove('date');
          
          if (updateData.isNotEmpty) {
            await txn.update(
              'daily_logs',
              updateData,
              where: 'id = ?',
              whereArgs: [keepId],
            );
          }
          
          print('Merged $count entries into one for date $date');
        }
        
        // Also fix entries where id is a date string instead of integer
        final dateStringIds = await txn.rawQuery('''
          SELECT * FROM daily_logs 
          WHERE id LIKE '2026-%' OR id LIKE '2025-%'
        ''');
        
        print('Found ${dateStringIds.length} entries with date string IDs');
        
        for (var entry in dateStringIds) {
          final date = entry['date'] as String;
          
          // Check if there's already an entry with proper integer ID
          final existing = await txn.query(
            'daily_logs',
            where: 'date = ? AND id NOT LIKE ?',
            whereArgs: [date, '2026-%'],
          );
          
          if (existing.isNotEmpty) {
            // Merge data into existing entry
            final merged = Map<String, dynamic>.from(existing.first);
            entry.forEach((key, value) {
              if (value != null && merged[key] == null) {
                merged[key] = value;
              }
            });
            
            // Update existing entry
            final updateData = Map<String, dynamic>.from(merged);
            updateData.remove('id');
            updateData.remove('date');
            
            if (updateData.isNotEmpty) {
              await txn.update(
                'daily_logs',
                updateData,
                where: 'id = ?',
                whereArgs: [existing.first['id']],
              );
            }
            
            // Delete the date-string ID entry
            await txn.delete(
              'daily_logs',
              where: 'id = ?',
              whereArgs: [entry['id']],
            );
            
            print('Merged date-string ID entry for $date into existing entry');
          } else {
            // No existing entry, just update the ID to be an integer
            // We need to delete and re-insert
            final data = Map<String, dynamic>.from(entry);
            data.remove('id');
            
            await txn.delete(
              'daily_logs',
              where: 'id = ?',
              whereArgs: [entry['id']],
            );
            
            await txn.insert('daily_logs', data);
            
            print('Re-inserted entry for $date with auto-increment ID');
          }
        }
      });
      
      print('Database cleanup completed successfully!');
    } catch (e) {
      print('Error during cleanup: $e');
      rethrow;
    } finally {
      await db.close();
    }
  }
  
  static double _calculateSleepHours(String bedTime, String wakeTime, int awakeMinutes) {
    final bed = _parseTime(bedTime);
    final wake = _parseTime(wakeTime);
    
    if (bed == null || wake == null) return 0.0;
    
    var duration = wake.difference(bed);
    if (duration.isNegative) {
      duration = duration + const Duration(days: 1);
    }
    
    final totalMinutes = duration.inMinutes - awakeMinutes;
    return totalMinutes / 60.0;
  }
  
  static DateTime? _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return null;
    
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    
    if (hour == null || minute == null) return null;
    
    return DateTime(2000, 1, 1, hour, minute);
  }
}
