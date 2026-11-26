import 'dart:ui';

/// Locale-aware strings for the LCM report generator (no BuildContext).
/// Report is user-facing (markdown / shared PDF), so it follows the UI language.
class RapportStrings {
  final bool nl;
  RapportStrings() : nl = PlatformDispatcher.instance.locale.languageCode.toLowerCase() == 'nl';
  RapportStrings.withLocale(String code) : nl = code.toLowerCase().startsWith('nl');

  String get lifeChartTitle =>
      nl ? '# Life Chart Methode — Ritme Rapport' : '# Life Chart Method — Ritme Report';
  String get disclaimer => nl
      ? '**Dit rapport is bedoeld als ondersteunend overzicht bij de behandeling van een Bipolaire Stoornis.**'
      : '**This report is intended as a supporting overview in the treatment of Bipolar Disorder.**';
  String get period => nl ? '**Periode:**' : '**Period:**';
  String get generated => nl ? '**Gegenereerd:**' : '**Generated:**';
  String get to => nl ? 't/m' : 'to';

  String get moodCheckTitle => nl
      ? '🧠 Stemmingscheck (5 vragen)'
      : '🧠 Mood check (5 questions)';

  String get correlationsTitle => nl ? '🧬 Correlaties' : '🧬 Correlations';
  String get correlationTitle => nl
      ? 'Medicatie-trouw vs Stemming'
      : 'Medication Adherence vs Mood';

  String correlationHighAdherence(double v, int n) =>
      nl ? 'Bij hoge trouw (>90%): gemiddelde stemming ${fmt1(v)} (n=$n ${_dagen(n)})'
         : 'With high adherence (>90%): average mood ${fmt1(v)} (n=$n ${_dagen(n)})';

  String get correlationNoHighData => nl
      ? 'Bij hoge trouw (>90%): geen data in deze periode'
      : 'With high adherence (>90%): no data in this period';

  String correlationLowAdherence(double v, int n) =>
      nl ? 'Bij lage trouw (<70%): gemiddelde stemming ${fmt1(v)} (n=$n ${_dagen(n)})'
         : 'With low adherence (<70%): average mood ${fmt1(v)} (n=$n ${_dagen(n)})';

  String get correlationNoLowData => nl
      ? 'Bij lage trouw (<70%): geen data in deze periode'
      : 'With low adherence (<70%): no data in this period';

  String correlationHighOnly(double v, int n) => nl
      ? 'Bij hoge trouw (>90%): gemiddelde stemming ${fmt1(v)} (n=$n ${_dagen(n)}; geen dagen met lage trouw in deze periode).'
      : 'With high adherence (>90%): average mood ${fmt1(v)} (n=$n ${_dagen(n)}; no low-adherence days in this period).';
  String correlationLowOnly(double v, int n) => nl
      ? 'Bij lage trouw (<70%): gemiddelde stemming ${fmt1(v)} (n=$n ${_dagen(n)}; geen dagen met hoge trouw in deze periode).'
      : 'With low adherence (<70%): average mood ${fmt1(v)} (n=$n ${_dagen(n)}; no high-adherence days in this period).';

  String get patientLabel => nl ? 'Patiënt' : 'Patient';
  String get summaryTitle => nl ? '📈 Samenvatting' : '📈 Summary';
  String get summaryMetric => nl ? 'Metriek' : 'Metric';
  String get summaryValue => nl ? 'Waarde' : 'Value';
  String get analysisSignalsTitle =>
      nl ? 'Bipolaire analyse-signalen' : 'Bipolar analysis signals';
  String get moodCheckNote => nl
      ? '_Opmerking: dit is de 5-vragen stemmingscheck, een apart instrument van de dagelijkse stemming-tracking (weekoverzicht)._'
      : '_Note: this is the 5-question mood check, a separate instrument from the daily mood tracking (weekly overview)._';
  String get ongoing => nl ? 'loopt nog' : 'ongoing';
  String pageOfTotal(int page, int total) =>
      nl ? 'Pagina $page van $total' : 'Page $page of $total';
  String get correlationAnalysisTitle =>
      nl ? '🧬 Correlatie Analyse' : '🧬 Correlation Analysis';


  String correlationDiff(double v) =>
      nl ? 'Verschil in stemming: ${fmt1(v)}' : 'Mood difference: ${fmt1(v)}';

  String get sleepMoodTitle =>
      nl ? 'Slaap vs Stemming' : 'Sleep vs Mood';
  String sleepMoodShortSleep(double v, int n) => nl
      ? 'Bij korte slaap (<6 uur): gemiddelde stemming ${fmt1(v)} (n=$n ${_dagen(n)})'
      : 'Short sleep (<6h): average mood ${fmt1(v)} (n=$n ${_dagen(n)})';
  String get sleepMoodShortNoData => nl
      ? 'Bij korte slaap (<6 uur): geen data in deze periode (n=0 dagen).'
      : 'Short sleep (<6h): no data in this period (n=0 days).';
  String sleepMoodLongSleep(double v, int n) => nl
      ? 'Bij voldoende slaap (6+ uur): gemiddelde stemming ${fmt1(v)} (n=$n ${_dagen(n)})'
      : 'Enough sleep (6h+): average mood ${fmt1(v)} (n=$n ${_dagen(n)})';
  String get sleepMoodLongNoData => nl
      ? 'Bij voldoende slaap (6+ uur): geen data in deze periode (n=0 dagen).'
      : 'Enough sleep (6h+): no data in this period (n=0 days).';
  String sleepMoodPaired(int paired, int totaal) {
    if (paired < totaal) {
      return nl
          ? 'Gebaseerd op $paired van de $totaal dagen waarop zowel slaap als stemming is ingevuld.'
          : 'Based on $paired of the $totaal days with both sleep and mood recorded.';
    }
    return nl
        ? 'Gebaseerd op n=$paired ${_dagen(paired)} waarop zowel slaap als stemming is ingevuld.'
        : 'Based on n=$paired ${_dagen(paired)} on which both sleep and mood were entered.';
  }
  String _dagen(int n) => nl ? (n == 1 ? 'dag' : 'dagen') : (n == 1 ? 'day' : 'days');

  String intakeMoments(int n) =>
      nl ? (n == 1 ? 'invulmoment' : 'invulmomenten') : (n == 1 ? 'entry' : 'entries');

  String get metric => nl ? 'Metriek' : 'Metric';
  String get average => nl ? 'Gemiddelde' : 'Average';
  String get mood => nl ? 'Stemming' : 'Mood';
  String get energyLevel => nl ? 'Energie-niveau' : 'Energy level';
  String get sleepNeed => nl ? 'Slaapbehoefte' : 'Sleep need';
  String get importantEvent => nl ? 'Belangrijke gebeurtenis' : 'Important event';
  String get calculatedMood => nl ? 'Berekende stemming' : 'Calculated mood';

  String get legendaLine => nl
      ? '_Legenda: Stemming (-5 t/m +5) · P-Score (1–5, stabiliteit dagritme) · SRT (Social Rhythm Therapy-doelpercentage) · Dagboekscore (1 = zwaar, 5 = goed) · ⚠ = dagboeknotitie met score ≤ 2._'
      : '_Legend: Mood (-5 to +5) · P-score (1–5, day rhythm stability) · SRT (Social Rhythm Therapy goal percentage) · Journal score (1 = heavy, 5 = good) · ⚠ = journal note with score ≤ 2._';
  String get weekAnchors => nl ? 'Dagboek & Alerts' : 'Journal & Alerts';
  String notitieCount(int n) => nl
      ? '$n ${n == 1 ? 'notitie' : 'notities'}'
      : '$n ${n == 1 ? 'note' : 'notes'}';
  String get weeklyOverview => nl ? '📊 Weekoverzicht' : '📊 Weekly overview';
  String get week => nl ? 'Week' : 'Week';
  String get avgMood => nl ? 'Gem. stemming' : 'Avg. mood';
  String get avgSleep => nl ? 'Gem. slaap' : 'Avg. sleep';
  String get avgPScore => nl ? 'Gem. P-Score' : 'Avg. P-Score';
  String get medication => nl ? 'Medicatie' : 'Medication';

  String get daysWithData => nl ? 'Dagen met data' : 'Days with data';
  String dagenVanKalender(int actief, int totaal) =>
      nl ? '$actief / $totaal kalenderdagen' : '$actief / $totaal calendar days';
  String get dosesUntilYesterday =>
      nl ? 't/m gisteravond' : 'through yesterday evening';
  String get dosesUntilToday => nl ? 't/m vandaag' : 'through today';
  String get avgMoodLong => nl ? 'Gem. stemming' : 'Avg. mood';
  String get avgSleepDuration => nl ? 'Gem. slaapduur' : 'Avg. sleep duration';
  String get medicationAdherence => nl ? 'Verwachte doses' : 'Expected doses';
  String get taken => nl ? 'ingenomen' : 'taken';
  String get unknown => nl ? 'Onbekend' : 'Unknown';
  String get lastBloodLevel => nl ? 'Laatste bloedspiegel' : 'Last blood level';

  String get warnings => nl ? '⚠️ Voortekenen' : '⚠️ Early warning signs';
  String totalWarnings(int n) =>
      nl ? 'Totaal voortekenen in periode: **$n**' : 'Total early warning signs in period: **$n**';
  String warningsCount(int n) => nl ? '$n voortekenen' : '$n warning signs';

  String get crisisPlan => nl ? '🚨 Crisisplan' : '🚨 Crisis plan';
  String get medOverviewTitle => nl ? '💊 Medicatie — Overzicht & Verloop' : '💊 Medication — Overview & Course';
  String get prnZeroTaken => nl ? '0× ingenomen in deze periode' : '0× taken in this period';
  String prnTakenOn(int n) => nl ? '$n× ingenomen op:' : '$n× taken on:';
  String get dateRangeJoiner => nl ? 't/m' : '–';

  /// Getal met één decimaal, zonder negatieve nul ('-0.0' → '0.0').
  static String fmt1(double v) {
    final r = (v * 10).round() / 10;
    return (r == 0 ? 0.0 : r).toStringAsFixed(1);
  }
  String get stoppedTag => nl ? 'gestopt' : 'stopped';
  String stoppedOn(String datum) =>
      nl ? 'gestopt op $datum' : 'stopped on $datum';
  String medDoseCount(int n) => nl
      ? (n == 1 ? 'dosis' : 'doses')
      : (n == 1 ? 'dose' : 'doses');
  String get missedOnLabel => nl ? '⚠️ Gemist op:' : '⚠️ Missed on:';
  String get takenWord => nl ? 'ingenomen' : 'taken';
  String get alternatingWord => nl ? 'afwisselend' : 'alternating';
  String get med => nl ? '💊 Medicatie' : '💊 Medication';
  /// Overzicht van wat er voorgeschreven staat (in plaats van de
  /// dubbele lijst met alleen namen en doseringen).
  String get medSchema => nl ? '📋 Actief Medicatieschema' : '📋 Active medication schedule';
  /// Vaste, dagelijkse medicatie.
  String get medFixed => nl ? 'Dagelijks (vast)' : 'Daily (fixed)';
  /// 'Zo nodig'-medicatie: geen dagelijkse dosis, dus geen percentage.
  String get medAsNeeded => nl ? 'Zo nodig (PRN)' : 'As needed (PRN)';
  String get episodesTitle => nl ? '🏥 Episodes' : '🏥 Episodes';

  // Dagboek
  String get dagboekTitle => nl ? '📓 Dagboek' : '📓 Journal';
  String get dagboekEntries => nl ? 'Dagboek-entries' : 'Journal entries';
  String get dagboekScore => nl ? 'Dagboekscore' : 'Journal score';
  String get dagboekGemiddeldeLabel =>
      nl ? 'Gemiddelde dagboekscore' : 'Average journal score';
  String get dagboekAantalLabel => nl ? 'Aantal entries' : 'Number of entries';
  String get noDagboek => nl ? 'Geen dagboek-entries in deze periode.' : 'No journal entries in this period.';
  String dagboekEntryLabel(String date, double? score) {
    if (score != null) {
      return nl ? '$date — score: ${score.toStringAsFixed(0)}' : '$date — score: ${score.toStringAsFixed(0)}';
    }
    return date;
  }

  String get footer => nl
      ? '*Rapport gegenereerd door Ritme — SRT Tracker*'
      : '*Report generated by Ritme — SRT Tracker*';

  String formatHours(double uren) {
    final min = (uren * 60).round();
    final h = min ~/ 60;
    final m = min % 60;
    final u = nl ? 'u' : 'h';
    if (m == 0) return '$h$u';
    return '$h$u ${m.toString().padLeft(2, '0')}m';
  }

  /// Eén datumnotatie voor het hele rapport: 24-11-2026.
  static String fmtDatum(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.year}';

  /// Korte datum voor periodes, medicatieverloop en alerts: 20-11.
  static String fmtDatumKort(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}';

  /// Volledige datum uit een opgeslagen yyyy-MM-dd.
  static String fmtDatumStr(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : fmtDatum(d);
  }

  /// Zelfde korte notatie, maar uit een opgeslagen yyyy-MM-dd.
  static String fmtDatumKortStr(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : fmtDatumKort(d);
  }

  /// Medicatiedosering zonder overbodige decimalen: 1000.0 -> 1000,
  /// 37.5 blijft 37.5.
  static String fmtDose(String raw) {
    final genormaliseerd = raw.trim().replaceAll(',', '.');
    final v = double.tryParse(genormaliseerd);
    if (v == null) return raw.trim();
    if (v % 1 == 0) return v.toInt().toString();
    return v.toString();
  }

  String episodeLabel(String type) {
    switch (type) {
      case 'hypomanie': return nl ? 'Hypomanie' : 'Hypomania';
      case 'manie': return nl ? 'Manie' : 'Mania';
      case 'depressie': return nl ? 'Depressie' : 'Depression';
      case 'gemengd': return nl ? 'Gemengd' : 'Mixed';
      case 'euthym': return nl ? 'Stabiel' : 'Stable';
      default: return type;
    }
  }

  String? flagLabel(String id) {
    if (nl) {
      switch (id) {
        case 'maniaShift': return 'Mogelijke manische shift';
        case 'probableMania': return 'Waarschijnlijke manie (triade)';
        case 'sleepReductionAlone': return 'Verminderde slaapbehoefte (vroeg manie-signaal)';
        case 'depressionShift': return 'Mogelijke depressieve shift';
        case 'probableDepression': return 'Waarschijnlijke depressie (triade)';
        case 'positiveLifeEventTrigger': return 'Positieve gebeurtenis als manie-trigger';
        case 'negativeLifeEventTrigger': return 'Negatieve gebeurtenis als depressie-trigger';
        case 'mixedEpisode': return 'Mogelijke gemengde episode';
        case 'opposingSignals': return 'Tegenstrijdige signalen';
        default: return null;
      }
    }
    switch (id) {
      case 'maniaShift': return 'Possible manic shift';
      case 'probableMania': return 'Probable mania (triad)';
      case 'sleepReductionAlone': return 'Reduced need for sleep (early mania sign)';
      case 'depressionShift': return 'Possible depressive shift';
      case 'probableDepression': return 'Probable depression (triad)';
      case 'positiveLifeEventTrigger': return 'Positive event as mania trigger';
      case 'negativeLifeEventTrigger': return 'Negative event as depression trigger';
      case 'mixedEpisode': return 'Possible mixed episode';
      case 'opposingSignals': return 'Opposing signals';
      default: return null;
    }
  }

  String sectionTitle(String section) {
    if (nl) {
      switch (section) {
        case 'manie_vroeg': return 'Bij eerste tekenen van manie';
        case 'manie_ernstig': return 'Bij ernstige manie';
        case 'depressie_vroeg': return 'Bij eerste tekenen van depressie';
        case 'depressie_ernstig': return 'Bij ernstige depressie';
        case 'gemengd': return 'Bij gemengde episode';
        case 'contacten': return 'Belangrijke contacten';
        case 'medicatie_nood': return 'Medicatie noodplan';
        case 'wat_helpt': return 'Wat helpt mij';
        default: return section;
      }
    }
    switch (section) {
      case 'manie_vroeg': return 'At first signs of mania';
      case 'manie_ernstig': return 'In severe mania';
      case 'depressie_vroeg': return 'At first signs of depression';
      case 'depressie_ernstig': return 'In severe depression';
      case 'gemengd': return 'In a mixed episode';
      case 'contacten': return 'Important contacts';
      case 'medicatie_nood': return 'Medication emergency plan';
      case 'wat_helpt': return 'What helps me';
      default: return section;
    }
  }
}
