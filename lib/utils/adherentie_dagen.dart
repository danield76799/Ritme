// Dagstatus voor de adherentie-heatmap: per dag genomen, gemist, nog open
// (vandaag, dosis nog niet aan de beurt) of niet gepland.

enum DagStatus { genomen, gemist, open, nietGepland }

class AdherentieDag {
  final DateTime datum;
  final DagStatus status;
  const AdherentieDag(this.datum, this.status);
}

String _datumStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

List<int> _dagenVanWeek(String? raw) {
  final bron = (raw == null || raw.trim().isEmpty) ? '1,2,3,4,5,6,7' : raw;
  return bron.split(',').map((s) => int.tryParse(s.trim())).whereType<int>().toList();
}

/// Bouwt de status per dag voor de laatste [dagen] dagen (oud → nieuw).
///
/// Regels:
/// - een dag telt alleen mee als er op die weekdag een schema is;
/// - een dag met een inname (> 0) is [DagStatus.genomen];
/// - vandaag zonder inname is [DagStatus.open] (de dosis kan nog komen);
/// - overige geplande dagen zonder inname zijn [DagStatus.gemist].
/// Zonder schema's (zo nodig / PRN) is er geen dagdoel en blijft de lijst leeg.
List<AdherentieDag> berekenAdherentieDagen({
  required List<Map<String, dynamic>> intakes,
  required int medicatieId,
  required List<Map<String, dynamic>> schedules,
  required DateTime vandaag,
  int dagen = 30,
}) {
  if (schedules.isEmpty) return const [];

  final genomen = <String>{};
  for (final r in intakes) {
    final rawId = r['medication_id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id != medicatieId) continue;
    final rawAantal = r['aantal_ingenomen'];
    final aantal = rawAantal is num
        ? rawAantal.toInt()
        : int.tryParse(rawAantal?.toString() ?? '') ?? 0;
    if (aantal <= 0) continue;
    final datum = r['date']?.toString();
    if (datum != null && datum.isNotEmpty) genomen.add(datum);
  }

  final resultaat = <AdherentieDag>[];
  for (int i = dagen - 1; i >= 0; i--) {
    final d = DateTime(vandaag.year, vandaag.month, vandaag.day - i);
    final gepland = schedules.any((s) => _dagenVanWeek(s['days_of_week']?.toString()).contains(d.weekday));
    if (!gepland) {
      resultaat.add(AdherentieDag(d, DagStatus.nietGepland));
      continue;
    }
    if (genomen.contains(_datumStr(d))) {
      resultaat.add(AdherentieDag(d, DagStatus.genomen));
    } else if (i == 0) {
      resultaat.add(AdherentieDag(d, DagStatus.open));
    } else {
      resultaat.add(AdherentieDag(d, DagStatus.gemist));
    }
  }
  return resultaat;
}

/// Aantal innames per week voor de laatste [weken] weken (oud → nieuw).
/// Maandag is het begin van de week, net als in het rapport.
List<int> prnPerWeek({
  required List<Map<String, dynamic>> intakes,
  required int medicatieId,
  required DateTime vandaag,
  int weken = 8,
}) {
  final vandaagDag = DateTime(vandaag.year, vandaag.month, vandaag.day);
  final maandag = vandaagDag.subtract(Duration(days: vandaagDag.weekday - 1));
  final start = maandag.subtract(Duration(days: 7 * (weken - 1)));
  final telling = List<int>.filled(weken, 0);

  for (final r in intakes) {
    final rawId = r['medication_id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id != medicatieId) continue;
    final rawAantal = r['aantal_ingenomen'];
    final aantal = rawAantal is num
        ? rawAantal.toInt()
        : int.tryParse(rawAantal?.toString() ?? '') ?? 0;
    if (aantal <= 0) continue;
    final datum = DateTime.tryParse(r['date']?.toString() ?? '');
    if (datum == null) continue;
    final dag = DateTime(datum.year, datum.month, datum.day);
    final verschil = dag.difference(start).inDays;
    if (verschil < 0 || verschil >= weken * 7) continue;
    telling[verschil ~/ 7] += aantal;
  }
  return telling;
}
