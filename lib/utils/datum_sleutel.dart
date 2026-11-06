/// Datumregels die het dashboard doorgeeft aan een scherm.
///
/// Apart gehouden van het dashboard zodat de regel getest kan worden: het
/// doorgeven van de juiste dag is precies het ding dat ooit misging.
library;

/// De dag als 'j-m-d' — hetzelfde formaat als de databasesleutel.
String datumSleutel(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// De dag om aan een scherm mee te geven, of null als het vandaag is.
///
/// Null betekent "vandaag" voor de schermen: die starten dan op vandaag.
///
/// LET OP: dit vergelijkt de dag zelf en leidt niets af uit een Duration.
/// `gisteren 23:00`.difference(`vandaag 01:00`) is -2 uur, en `.inDays`
/// truncateert dat naar 0 dagen — waarna een dag uit het verleden als
/// vandaag werd behandeld en een dagboeknotitie op de verkeerde dag belandde.
String? dagboekDatumArgument(DateTime geselecteerd, {DateTime? nu}) {
  final vandaag = nu ?? DateTime.now();
  final vandaagSleutel = datumSleutel(
    DateTime(vandaag.year, vandaag.month, vandaag.day),
  );
  final gekozen = datumSleutel(geselecteerd);
  return gekozen == vandaagSleutel ? null : gekozen;
}

/// Hoeveel dagen [datum] voor vandaag ligt (negatief) of er na (positief).
///
/// Gerekend op UTC-middernacht, zodat een DST-dag altijd exact 24 uur is en
/// de uitkomst niet afhangt van het tijdstip waarop je het vraagt. Dat is
/// precies wat er misging: `gisteren 23:00`.difference(`vandaag 01:00`) is
/// -2 uur en `.inDays` geeft 0 — waarna de datumkop "Vandaag" zei terwijl je
/// op een verleden dag zat.
int dagenVerschil(DateTime datum, {DateTime? nu}) {
  final vandaag = nu ?? DateTime.now();
  final a = DateTime.utc(datum.year, datum.month, datum.day);
  final b = DateTime.utc(vandaag.year, vandaag.month, vandaag.day);
  return a.difference(b).inDays;
}
