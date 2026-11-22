// Samenvoegen van dubbele medicatie-registraties.
//
// De app kent gevallen waarin hetzelfde middel (zelfde naam, dosis en
// eenheid) meerdere keren als losse config is aangemaakt — bijvoorbeeld
// na stoppen + opnieuw toevoegen, of na een restore. Ze tonen allemaal
// als aparte kaarten. Dit bestand plant het samenvoegen (puur, testbaar)
// en voert het uit op de database.

import '../service_locator.dart';

/// Eén groep dubbele configs van hetzelfde middel.
class MedDuplicateGroup {
  final String naam;
  final String dosering;
  final String eenheid;

  /// De config die blijft staan (actieve config heeft voorrang, daarna de
  /// oudste: die draagt doorgaans de meeste inname-historie).
  final Map<String, dynamic> keeper;

  /// De overige (gelijknamige) configs die weg kunnen.
  final List<Map<String, dynamic>> verwijderen;

  const MedDuplicateGroup({
    required this.naam,
    required this.dosering,
    required this.eenheid,
    required this.keeper,
    required this.verwijderen,
  });

  int get anzahlDubbels => verwijderen.length;
}

String _norm(String? v) =>
    (v ?? '').trim().toLowerCase().replaceAll(',', '.').replaceAll(RegExp(r'\s+'), ' ');

int _idOf(Map<String, dynamic> c) {
  final v = c['id'];
  if (v is int) return v;
  return int.tryParse('$v') ?? 0;
}

bool _isActief(Map<String, dynamic> c) {
  final del = c['deleted'];
  if (del == 1 || del == '1' || del == true) return false;
  final stop = c['stopped_at']?.toString();
  if (stop != null && stop.isNotEmpty) {
    final d = DateTime.tryParse(stop);
    if (d != null && !d.isAfter(DateTime.now())) return false;
  }
  return true;
}

/// Groepeert configs met identieke (naam, dosis, eenheid). Groepen met één
/// lid worden genegeerd. Puur: geen database-toegang, dus direct testbaar.
List<MedDuplicateGroup> vindDubbeleMeds(List<Map<String, dynamic>> configs) {
  final groepen = <String, List<Map<String, dynamic>>>{};
  for (final c in configs) {
    final naam = _norm(c['naam']?.toString());
    if (naam.isEmpty) continue;
    final key = '$naam|${_norm(c['dosering']?.toString())}|${_norm(c['eenheid']?.toString())}';
    groepen.putIfAbsent(key, () => []).add(c);
  }

  final result = <MedDuplicateGroup>[];
  for (final entry in groepen.entries) {
    if (entry.value.length < 2) continue;
    final leden = [...entry.value];
    // Keeper: actieve configs eerst, dan de oudste (kleinste id).
    leden.sort((a, b) {
      final aa = _isActief(a) ? 0 : 1;
      final bb = _isActief(b) ? 0 : 1;
      if (aa != bb) return aa - bb;
      return _idOf(a).compareTo(_idOf(b));
    });
    final first = leden.first;
    result.add(MedDuplicateGroup(
      naam: (first['naam'] ?? '').toString().trim(),
      dosering: (first['dosering'] ?? '').toString().trim(),
      eenheid: (first['eenheid'] ?? '').toString().trim(),
      keeper: leden.first,
      verwijderen: leden.skip(1).toList(),
    ));
  }
  return result;
}

/// Voert het samenvoegen uit: alle innames van de te verwijderen configs
/// worden naar de keeper verplaatst; schema's van de verwijderde configs
/// worden opgeruimd; daarna worden de configs zelf hard verwijderd.
/// Geeft het aantal verwijderde configs terug.
Future<int> mergeDubbeleMeds(List<MedDuplicateGroup> groepen) async {
  var verwijderd = 0;
  for (final groep in groepen) {
    final keeperId = _idOf(groep.keeper);
    for (final dubbel in groep.verwijderen) {
      final dubbelId = _idOf(dubbel);
      if (dubbelId == keeperId) continue;
      await db.reassignMedicationIntakes(dubbelId, keeperId);
      await db.deleteMedicationSchedulesForMedication(dubbelId);
      await db.hardDeleteMedicationConfig(dubbelId);
      verwijderd++;
    }
  }
  return verwijderd;
}
