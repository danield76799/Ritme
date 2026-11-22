import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Grootte van `<dir>/<name>.hive`, of null als die niet bestaat/te lezen is.
Future<int?> boxFileSize(String name, String? dirOverride) async {
  try {
    final dir = dirOverride ?? (await getApplicationDocumentsDirectory()).path;
    final f = File('$dir${Platform.pathSeparator}$name.hive');
    if (!await f.exists()) return null;
    return await f.length();
  } catch (_) {
    return null;
  }
}
