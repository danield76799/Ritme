import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Utility class for consistent logging across the app.
///
/// Logt naar de console ÉN naar een bestand (ritme_log.txt in de app-map,
/// max ~256 KB, daarna wordt het in één keer ingekrompen). Zo bevat het
/// logboek ook de crashes en meldingen van eerdere sessies en kan het via
/// "Logboek delen" in Instellingen als bijlage worden meegestuurd.
class AppLogger {
  static const String _name = 'Ritme';
  static const int _maxBytes = 256 * 1024;
  static const int _keepBytes = 128 * 1024;

  static File? _logFile;
  static bool _initDone = false;

  /// Zet het bestands-logboek op. Idempotent; falen is niet fataal.
  static Future<void> init() async {
    if (_initDone || kIsWeb) return;
    _initDone = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/ritme_log.txt');
      if (await file.exists()) {
        final len = await file.length();
        if (len > _maxBytes) {
          final contents = await file.readAsString();
          final start = contents.length - _keepBytes;
          await file.writeAsString(contents.substring(start), flush: true);
        }
      }
      _logFile = file;
    } catch (e) {
      // Bestandslog niet beschikbaar (bijv. tests): console-log blijft werken.
      _logFile = null;
    }
  }

  /// De laatste [maxBytes] bytes van het logboek, voor delen/diagnose.
  static Future<String> leesLog({int maxBytes = 64 * 1024}) async {
    try {
      await init();
      final file = _logFile;
      if (file == null || !await file.exists()) return '(geen logboek beschikbaar)';
      final contents = await file.readAsString();
      if (contents.length <= maxBytes) return contents;
      return contents.substring(contents.length - maxBytes);
    } catch (e) {
      return '(logboek niet leesbaar: $e)';
    }
  }

  static void _writeLine(String level, String message, {Object? error, StackTrace? stackTrace}) {
    final buf = StringBuffer()
      ..write(DateTime.now().toIso8601String())
      ..write(' [$level] ')
      ..write(message);
    if (error != null) buf.write(' | $error');
    if (stackTrace != null) buf.write('\n$stackTrace');
    final line = buf.toString();
    try {
      final file = _logFile;
      if (file != null) {
        file.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
      }
    } catch (_) {
      // Nooit loggen over het loggen; console heeft het al.
    }
  }

  static void debug(String message, {String? tag}) {
    developer.log(message, name: tag ?? _name, level: 500);
  }

  static void info(String message, {String? tag}) {
    developer.log(message, name: tag ?? _name, level: 800);
    _writeLine('INFO', message);
  }

  static void warning(String message, {String? tag, Object? error}) {
    developer.log(message, name: tag ?? _name, level: 900, error: error);
    _writeLine('WARN', message, error: error);
  }

  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    developer.log(message, name: tag ?? _name, level: 1000, error: error, stackTrace: stackTrace);
    _writeLine('ERROR', message, error: error, stackTrace: stackTrace);
  }
}
