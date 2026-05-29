/// Helper voor consistente boolean conversie uit database waarden
/// Ondersteunt: bool, int (0/1), String ('true'/'false', '0'/'1')
class BoolHelper {
  /// Converteer een dynamische waarde naar boolean
  /// Standaard waarde is false als input null is
  static bool parse(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase().trim();
      return lower == 'true' || lower == '1' || lower == 'yes' || lower == 'ja';
    }
    return defaultValue;
  }

  /// Converteer boolean naar int (0/1) voor database opslag
  static int toInt(bool value) => value ? 1 : 0;

  /// Converteer boolean naar String ('true'/'false') voor database opslag
  static String toStringValue(bool value) => value ? 'true' : 'false';
}
