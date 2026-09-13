import '../service_locator.dart';

/// Bepaalt of de ochtend- en avond check-in van een dag zijn ingevuld.
///
/// Deze logica stond eerder alleen inline in het dashboard. De
/// notificatie-herinneringen moeten dezelfde vraag beantwoorden ("is gisteren
/// ingevuld?") vanuit een achtergrondtaak, dus hij staat nu hier — één
/// definitie, zodat een notificatie nooit iets anders beweert dan het
/// dashboard toont.
///
/// Bewust géén BuildContext: dit draait ook buiten de widget-tree.
class CheckinStatus {
  /// SRM-activiteitstypes die bij de avond check-in horen.
  ///
  /// Dit zijn de DB-waarden (Nederlands, ongeacht de taal van de app).
  static const Set<String> avondTypes = {
    'Eerste contact',
    'Werk / Hobby',
    'Avondeten',
    'Naar bed',
  };

  /// Datum als 'YYYY-MM-DD', de sleutel waaronder alles wordt opgeslagen.
  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static double? _asDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

  static int _asInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

  /// Is de ochtend check-in van [dateKey] ingevuld?
  ///
  /// De ochtend check-in schrijft slaapduur, wakkertijd en slaapbehoefte weg.
  /// Eén daarvan is genoeg: een gebruiker die alleen de wakkertijd invult hoort
  /// niet "nog niet ingevuld" te zien.
  static Future<bool> heeftOchtend(String dateKey) async {
    try {
      final logs = await db.getDailyLogsRange(dateKey, dateKey);
      for (final log in logs) {
        if (log['date']?.toString() != dateKey) continue;
        final slaap = _asDouble(log['uren_slaap']);
        final wakker = _asInt(log['awake_minutes']);
        final behoefte = log['q4_slaapbehoefte'];
        if ((slaap != null && slaap > 0) || wakker > 0 || behoefte != null) {
          return true;
        }
      }
    } catch (_) {
      // Bij een leesfout liever geen valse "niet ingevuld"-melding sturen.
      return true;
    }
    return false;
  }

  /// Is de avond check-in van [dateKey] ingevuld?
  ///
  /// De avond check-in bestaat uit de SRM-activiteiten (eerste contact, werk,
  /// avondeten, naar bed). Minstens één daarvan telt als ingevuld.
  static Future<bool> heeftAvond(String dateKey) async {
    try {
      final activities = await db.getSrmActivitiesRange(dateKey, dateKey);
      for (final a in activities) {
        if (a['date']?.toString() != dateKey) continue;
        if (avondTypes.contains(a['activity_type']?.toString() ?? '')) {
          return true;
        }
      }
    } catch (_) {
      return true;
    }
    return false;
  }

  /// Beide check-ins in één keer (twee DB-reads parallel).
  static Future<({bool ochtend, bool avond})> voor(String dateKey) async {
    final results = await Future.wait([
      heeftOchtend(dateKey),
      heeftAvond(dateKey),
    ]);
    return (ochtend: results[0], avond: results[1]);
  }
}
