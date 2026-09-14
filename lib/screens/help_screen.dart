import 'package:flutter/material.dart';
import '../generated/l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  /// Dezelfde taal als de rest van de app — geen eigen schakelaar meer.
  /// Eerst had dit scherm een losse NL/EN-knop (met Platform.localeName),
  /// waardoor Help in een andere taal kon staan dan de app zelf.
  bool get _isNederlands =>
      Localizations.localeOf(context).languageCode == 'nl';

  @override
  Widget build(BuildContext context) {
    final isDutch = _isNederlands;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        title: Text(
          isDutch ? 'Gebruiksaanwijzing' : 'User Guide',
          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIntro(),
              const SizedBox(height: 24),

              _buildSection(
                icon: Icons.sentiment_satisfied_alt,
                title: isDutch ? 'Stemming bijhouden' : 'Track Mood',
                description: isDutch
                    ? 'Tik op de Stemming-tegel op je dashboard.\n\n'
                      '• Beantwoord de 5 korte vragen eerlijk\n'
                      '• Vraag 1 en 3 meten je stemming en energie op een schaal\n'
                      '• Vraag 2 is een globale energie-slider (depressief → manisch)\n'
                      '• Vraag 4 gaat over je slaapbehoefte\n'
                      '• Vraag 5 vraagt of er een belangrijke gebeurtenis is met invloed op je stemming\n'
                      '• Je krijgt een score (−5 tot +5) én persoonlijke bipolaire signalen'
                    : 'Tap the Mood tile on your dashboard.\n\n'
                      '• Answer the 5 short questions honestly\n'
                      '• Question 1 and 3 measure mood and energy on a scale\n'
                      '• Question 2 is a global energy slider (depressed → manic)\n'
                      '• Question 4 is about your sleep need\n'
                      '• Question 5 asks if an important event affects your mood\n'
                      '• You get a score (−5 to +5) and personal bipolar signals',
              ),
              const SizedBox(height: 20),

              _buildDetailCard(
                title: isDutch ? 'Stemmingsschaal (−5 tot +5)' : 'Mood Scale (−5 to +5)',
                children: [
                  _buildScaleItem(color: Colors.indigo.shade900, label: isDutch ? '−5: Uiterst depressief' : '−5: Extremely depressed'),
                  _buildScaleItem(color: Colors.indigo.shade400, label: isDutch ? '−3: Matig depressief' : '−3: Moderately depressed'),
                  _buildScaleItem(color: Theme.of(context).colorScheme.primary, label: '0: ${isDutch ? 'Neutraal' : 'Neutral'}'),
                  _buildScaleItem(color: Colors.orange.shade700, label: isDutch ? '+3: Matig manisch' : '+3: Moderately manic'),
                  _buildScaleItem(color: Colors.red.shade600, label: isDutch ? '+5: Uiterst manisch' : '+5: Extremely manic'),
                ],
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.directions_walk,
                title: isDutch ? 'Activiteit & Slaap' : 'Activity & Sleep',
                description: isDutch
                    ? 'Tik op de Activiteit & Slaap-tegel om je dagritme vast te leggen.\n\n'
                      '• Slaap: vul bedtijd, opstaantijd en wakker-gelegen-minuten in\n'
                      '• De app berekent automatisch je netto slaapduur\n'
                      '• Sociaal Ritme: registreer vaste momenten (opstaan, eerste contact, werk/hobby, eten, naar bed)\n'
                      '• Je krijgt een P-score per activiteit op basis van je doeltijd'
                    : 'Tap the Activity & Sleep tile to record your daily rhythm.\n\n'
                      '• Sleep: enter bedtime, wake time and minutes awake\n'
                      '• The app automatically calculates your net sleep duration\n'
                      '• Social Rhythm: register fixed moments (wake up, first contact, work/hobby, dinner, bed time)\n'
                      '• You get a P-score per activity based on your target time',
              ),
              const SizedBox(height: 20),

              _buildDetailCard(
                title: isDutch ? 'P-Score Legenda (Sociaal Ritme)' : 'P-Score Legend (Social Rhythm)',
                children: [
                  _buildPScoreItem(icon: Icons.check_circle, color: Colors.green, label: isDutch ? '✓✓ Binnen 15 min' : '✓✓ Within 15 min', points: '5 ${isDutch ? 'punten' : 'points'}'),
                  _buildPScoreItem(icon: Icons.check_circle_outline, color: Colors.green, label: isDutch ? '✓ Binnen 30 min' : '✓ Within 30 min', points: '4 ${isDutch ? 'punten' : 'points'}'),
                  _buildPScoreItem(icon: Icons.remove_circle_outline, color: Colors.orange, label: isDutch ? '~ Binnen 45 min' : '~ Within 45 min', points: '3 ${isDutch ? 'punten' : 'points'}'),
                  _buildPScoreItem(icon: Icons.warning_amber, color: Colors.orange, label: isDutch ? '! Binnen 60 min' : '! Within 60 min', points: '2 ${isDutch ? 'punten' : 'points'}'),
                  _buildPScoreItem(icon: Icons.error_outline, color: Colors.red, label: isDutch ? '!! Meer dan 60 min' : '!! More than 60 min', points: '1 ${isDutch ? 'punt' : 'point'}'),
                  _buildPScoreItem(icon: Icons.circle_outlined, color: Colors.grey, label: isDutch ? 'Geen activiteit' : 'No activity', points: '0 ${isDutch ? 'punten' : 'points'}'),
                ],
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.medication,
                title: isDutch ? 'Medicatie bijhouden' : 'Track Medication',
                description: isDutch
                    ? 'Tik op de Medicatie-tegel om je medicatie te registreren.\n\n'
                      '• Voeg medicijnen toe met naam, dosering en vaste tijden\n'
                      '• Ontvang herinneringen via notificaties\n'
                      '• Markeer medicatie als "genomen" of "overgeslagen"\n'
                      '• Consistente inname op vaste tijden ondersteunt je ritme'
                    : 'Tap the Medication tile to register your medication.\n\n'
                      '• Add medications with name, dosage and fixed times\n'
                      '• Receive reminders via notifications\n'
                      '• Mark medication as "taken" or "skipped"\n'
                      '• Consistent intake at fixed times supports your rhythm',
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.schedule,
                title: AppLocalizations.of(context).srtScoreBegrijpen,
                description: AppLocalizations.of(context).srtScoreDesc,
              ),
              const SizedBox(height: 20),

              _buildDetailCard(
                title: AppLocalizations.of(context).srtScoreInterpretatie,
                children: [
                  _buildScoreRange(range: '80-100%', color: Colors.green, label: isDutch ? 'Uitstekend stabiel' : 'Excellent stability', action: '✅ ${isDutch ? 'Blijf zo doorgaan' : 'Keep it up'}'),
                  _buildScoreRange(range: '60-79%', color: Colors.lightGreen, label: isDutch ? 'Goed, kleine variaties' : 'Good, small variations', action: '✅ ${isDutch ? 'Acceptabel' : 'Acceptable'}'),
                  _buildScoreRange(range: '40-59%', color: Colors.orange, label: isDutch ? 'Matig, aandacht nodig' : 'Moderate, attention needed', action: '⚠️ ${isDutch ? 'Monitor je ritme' : 'Monitor your rhythm'}'),
                  _buildScoreRange(range: '20-39%', color: Colors.deepOrange, label: isDutch ? 'Instabiel' : 'Unstable', action: '🔴 ${isDutch ? 'Bespreek met behandelaar' : 'Discuss with therapist'}'),
                  _buildScoreRange(range: '0-19%', color: Colors.red, label: isDutch ? 'Zeer instabiel' : 'Very unstable', action: '🚨 ${isDutch ? 'Hulp zoeken' : 'Seek help'}'),
                ],
              ),
              const SizedBox(height: 20),

              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      isDutch ? 'Berekening' : 'Calculation',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal,
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AppLocalizations.of(context).srtScoreFormula,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.bar_chart,
                title: isDutch ? 'Statistieken bekijken' : 'View Statistics',
                description: isDutch
                    ? 'Tik op het grafiek-icoon om je voortgang te zien.\n\n'
                      '• Weekgrafiek: stemming en slaap in één overzicht\n'
                      '• Slaapdetails: duur, kwaliteit en trend\n'
                      '• Ritme-details: je SRM-activiteiten en P-scores\n'
                      '• SRT-score: je regelmaat over tijd\n'
                      '• Gebruik deze inzichten om patronen te herkennen'
                    : 'Tap the chart icon to see your progress.\n\n'
                      '• Week graph: mood and sleep in one overview\n'
                      '• Sleep details: duration, quality and trend\n'
                      '• Rhythm details: your SRM activities and P-scores\n'
                      '• SRT score: your regularity over time\n'
                      '• Use these insights to recognize patterns',
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.settings,
                title: isDutch ? 'Instellingen' : 'Settings',
                description: isDutch
                    ? 'Pas je voorkeuren aan in het instellingen-scherm.\n\n'
                      '• Stel doeltijden in voor je SRM-activiteiten\n'
                      '• Zet notificaties aan voor herinneringen\n'
                      '• Kies tussen licht en donker thema\n'
                    : 'Adjust your preferences in the settings screen.\n\n'
                      '• Set target times for your SRM activities\n'
                      '• Enable notifications for reminders\n'
                      '• Choose between light and dark theme\n'
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.lightbulb_outline,
                title: isDutch ? 'Tips voor succes' : 'Tips for Success',
                description: isDutch
                    ? 'Maximaliseer het effect van Ritme met deze tips.\n\n'
                      '• Vul je stemming dagelijks in, liefst op hetzelfde tijdstip\n'
                      '• Houd je slaaptijden consistent, ook in het weekend\n'
                      '• Eet, sta op en plan sociale contacten op vaste tijden\n'
                      '• Noteer belangrijke gebeurtenissen met invloed op je stemming\n'
                      '• Neem je medicatie op de afgesproken tijden\n'
                      '• Bekijk je statistieken wekelijks om patronen te herkennen'
                    : 'Maximize the effect of Ritme with these tips.\n\n'
                      '• Fill in your mood daily, preferably at the same time\n'
                      '• Keep your sleep times consistent, even on weekends\n'
                      '• Eat, get up and plan social contact at fixed times\n'
                      '• Note important events that affect your mood\n'
                      '• Take your medication at the agreed times\n'
                      '• Review your statistics weekly to recognize patterns',
              ),
              const SizedBox(height: 20),

              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: Theme.of(context).colorScheme.primary),
                        SizedBox(width: 8),
                        Text(
                          isDutch ? 'Privacy & Beveiliging' : 'Privacy & Security',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      isDutch
                        ? '• Alle gegevens worden lokaal opgeslagen\n'
                          '• Optionele PIN-bescherming en biometrie beschikbaar\n'
                          '• Geen data wordt naar externe servers gestuurd\n'
                          '• Exporteer je data als JSON voor backup'
                        : '• All data is stored locally\n'
                          '• Optional PIN protection and biometrics available\n'
                          '• No data is sent to external servers\n'
                          '• Export your data as JSON for backup',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.primary,
            size: 32,
          ),
          SizedBox(height: 12),
          Text(
            _isNederlands
              ? 'Ritme is gebaseerd op Social Rhythm Therapy (SRT), '
                'een bewezen methode om je dagelijks ritme te verbeteren. '
                'Door regelmatigheid in slaap, activiteiten, sociale contacten en medicatie '
                'kun je je stemming en welbevinden positief beïnvloeden. '
                'Alle inzichten zijn bedoeld ter ondersteuning, niet als medisch advies.'
              : 'Ritme is based on Social Rhythm Therapy (SRT), '
                'a proven method to improve your daily rhythm. '
                'Through regularity in sleep, activities, social contact and medication '
                'you can positively influence your mood and well-being. '
                'All insights are meant as support, not medical advice.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildScaleItem({required Color color, required String label}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPScoreItem({
    required IconData icon,
    required Color color,
    required String label,
    required String points,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            points,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRange({
    required String range,
    required Color color,
    required String label,
    required String action,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                range,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.surface,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                    ),
                  ),
                  Text(
                    action,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
