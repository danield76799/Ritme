// Adherentie per medicatie: het percentage dagen waarop de medicatie is
// ingenomen over de laatste N dagen (of sinds de aanmaakdatum als die
// recenter is). Medicijnen zonder intake-doel (zo nodig) worden overgeslagen.

class Adherentie {
  final int percentage; // 0..100
  final int dagen; // aantal meegenomen dagen (korter dan het venster bij recent toegevoegd)
  const Adherentie({required this.percentage, required this.dagen});
}

/// Berekent per medicijn-id het adherentiepercentage.
///
/// [intakes]: rijen uit medication_intake over de gewenste periode
/// (idealiter de laatste 30..35 dagen). [configs]: de medication_config-rijen.
Map<int, Adherentie> berekenAdherentie({
  required List<Map<String, dynamic>> intakes,
  required List<Map<String, dynamic>> configs,
  required DateTime vandaag,
  int dagenTerug = 29,
}) {
  final start = DateTime(vandaag.year, vandaag.month, vandaag.day)
      .subtract(Duration(days: dagenTerug));

  // Aantal ingenomen dagen per medicijn (unieke datums).
  final dagenPerMed = <int, Set<String>>{};
  for (final inname in intakes) {
    dynamic rawMedId = inname['medication_id'];
    final int? medId = rawMedId is int ? rawMedId : int.tryParse(rawMedId?.toString() ?? '');
    if (medId == null) continue;
    dynamic rawAantal = inname['aantal_ingenomen'];
    final int aantal = rawAantal is num
        ? rawAantal.toInt()
        : int.tryParse(rawAantal?.toString() ?? '') ?? 0;
    if (aantal <= 0) continue;
    final datum = inname['date']?.toString();
    if (datum == null || datum.isEmpty) continue;
    dagenPerMed.putIfAbsent(medId, () => <String>{}).add(datum);
  }

  final resultaat = <int, Adherentie>{};
  for (final config in configs) {
    final rawId = config['id'];
    final int? id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id == null) continue;

    // Zo-nodig-medicatie heeft geen dagelijks doel; overslaan.
    final zoNodig = _alsBool(config['zo_nodig']);
    if (zoNodig) continue;

    // Startdatum: aanmaakdatum van de kaart, begrensd op het venster.
    final created = DateTime.tryParse(config['created_at']?.toString() ?? '');
    DateTime first = start;
    if (created != null) {
      final c = DateTime(created.year, created.month, created.day);
      if (c.isAfter(start)) first = c;
    }
    final dagen = vandaag.difference(first).inDays + 1;
    if (dagen <= 0) continue;

    final ingenomen = dagenPerMed[id]?.length ?? 0;
    final genomen = ingenomen > dagen ? dagen : ingenomen;
    resultaat[id] = Adherentie(percentage: ((genomen * 100) / dagen).round(), dagen: dagen);
  }
  return resultaat;
}

bool _alsBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v?.toString();
  return s == '1' || s?.toLowerCase() == 'true';
}
