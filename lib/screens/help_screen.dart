import 'package:flutter/material.dart';
import 'dart:io';
import '../theme/app_theme.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  bool _isDutch = true;

  @override
  void initState() {
    super.initState();
    final locale = Platform.localeName;
    _isDutch = locale.startsWith('nl');
  }

  void _toggleLanguage() {
    setState(() {
      _isDutch = !_isDutch;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        title: Text(
          _isDutch ? 'Gebruiksaanwijzing' : 'User Guide',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: _toggleLanguage,
            icon: Icon(Icons.language, color: Colors.white),
            label: Text(
              _isDutch ? 'EN' : 'NL',
              style: TextStyle(color: Theme.of(context).colorScheme.surface, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
                title: _isDutch ? 'Stemming bijhouden' : 'Track Mood',
                description: _isDutch
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
                title: _isDutch ? 'Stemmingsschaal (−5 tot +5)' : 'Mood Scale (−5 to +5)',
                children: [
                  _buildScaleItem(color: Colors.indigo.shade900, label: _isDutch ? '−5: Uiterst depressief' : '−5: Extremely depressed'),
                  _buildScaleItem(color: Colors.indigo.shade400, label: _isDutch ? '−3: Matig depressief' : '−3: Moderately depressed'),
                  _buildScaleItem(color: AppTheme.primaryTeal, label: '0: ${_isDutch ? 'Neutraal' : 'Neutral'}'),
                  _buildScaleItem(color: Colors.orange.shade700, label: _isDutch ? '+3: Matig manisch' : '+3: Moderately manic'),
                  _buildScaleItem(color: Colors.red.shade600, label: _isDutch ? '+5: Uiterst manisch' : '+5: Extremely manic'),
                ],
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.directions_walk,
                title: _isDutch ? 'Activiteit & Slaap' : 'Activity & Sleep',
                description: _isDutch
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
                title: _isDutch ? 'P-Score Legenda (Sociaal Ritme)' : 'P-Score Legend (Social Rhythm)',
                children: [
                  _buildPScoreItem(icon: Icons.check_circle, color: Colors.green, label: _isDutch ? '✓✓ Binnen 15 min' : '✓✓ Within 15 min', points: '5 ${_isDutch ? 'punten' : 'points'}'),
                  _buildPScoreItem(icon: Icons.check_circle_outline, color: Colors.green, label: _isDutch ? '✓ Binnen 30 min' : '✓ Within 30 min', points: '4 ${_isDutch ? 'punten' : 'points'}'),
                  _buildPScoreItem(icon: Icons.remove_circle_outline, color: Colors.orange, label: _isDutch ? '~ Binnen 45 min' : '~ Within 45 min', points: '3 ${_isDutch ? 'punten' : 'points'}'),
                  _buildPScoreItem(icon: Icons.warning_amber, color: Colors.orange, label: _isDutch ? '! Binnen 60 min' : '! Within 60 min', points: '2 ${_isDutch ? 'punten' : 'points'}'),
                  _buildPScoreItem(icon: Icons.error_outline, color: Colors.red, label: _isDutch ? '!! Meer dan 60 min' : '!! More than 60 min', points: '1 ${_isDutch ? 'punt' : 'point'}'),
                  _buildPScoreItem(icon: Icons.circle_outlined, color: Colors.grey, label: _isDutch ? 'Geen activiteit' : 'No activity', points: '0 ${_isDutch ? 'punten' : 'points'}'),
                ],
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.medication,
                title: _isDutch ? 'Medicatie bijhouden' : 'Track Medication',
                description: _isDutch
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
                title: _isDutch ? 'SRT Score begrijpen' : 'Understanding SRT Score',
                description: _isDutch
                    ? 'De Social Rhythm Metric (SRT) meet je dagelijkse regelmaat.\n\n'
                      '• Score wordt berekend uit je SRM-activiteiten\n'
                      '• Hogere score = stabieler dagelijks ritme\n'
                      '• Doel: consistente tijden voor slapen, opstaan, eten en sociale contacten\n'
                      '• Regelmatigheid helpt je biologische klok stabiliseren\n'
                      '• Dit kan bijdragen aan een betere stemming'
                    : 'The Social Rhythm Metric (SRT) measures your daily regularity.\n\n'
                      '• Score is calculated from your SRM activities\n'
                      '• Higher score = more stable daily rhythm\n'
                      '• Goal: consistent times for sleep, wake up, meals and social contact\n'
                      '• Regularity helps stabilize your biological clock\n'
                      '• This can contribute to better mood',
              ),
              const SizedBox(height: 20),

              _buildDetailCard(
                title: _isDutch ? 'SRT Score Interpretatie' : 'SRT Score Interpretation',
                children: [
                  _buildScoreRange(range: '80-100%', color: Colors.green, label: _isDutch ? 'Uitstekend stabiel' : 'Excellent stability', action: '✅ ${_isDutch ? 'Blijf zo doorgaan' : 'Keep it up'}'),
                  _buildScoreRange(range: '60-79%', color: Colors.lightGreen, label: _isDutch ? 'Goed, kleine variaties' : 'Good, small variations', action: '✅ ${_isDutch ? 'Acceptabel' : 'Acceptable'}'),
                  _buildScoreRange(range: '40-59%', color: Colors.orange, label: _isDutch ? 'Matig, aandacht nodig' : 'Moderate, attention needed', action: '⚠️ ${_isDutch ? 'Monitor je ritme' : 'Monitor your rhythm'}'),
                  _buildScoreRange(range: '20-39%', color: Colors.deepOrange, label: _isDutch ? 'Instabiel' : 'Unstable', action: '🔴 ${_isDutch ? 'Bespreek met behandelaar' : 'Discuss with therapist'}'),
                  _buildScoreRange(range: '0-19%', color: Colors.red, label: _isDutch ? 'Zeer instabiel' : 'Very unstable', action: '🚨 ${_isDutch ? 'Hulp zoeken' : 'Seek help'}'),
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
                      _isDutch ? 'Berekening' : 'Calculation',
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
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'SRT Score = (Average P-Score / 5) × 100%',
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
                title: _isDutch ? 'Statistieken bekijken' : 'View Statistics',
                description: _isDutch
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
                title: _isDutch ? 'Instellingen' : 'Settings',
                description: _isDutch
                    ? 'Pas je voorkeuren aan in het instellingen-scherm.\n\n'
                      '• Stel doeltijden in voor je SRM-activiteiten\n'
                      '• Zet notificaties aan voor herinneringen\n'
                      '• Kies tussen licht en donker thema\n'
                      '• Optionele menstruatie-vraag in- of uitschakelen'
                    : 'Adjust your preferences in the settings screen.\n\n'
                      '• Set target times for your SRM activities\n'
                      '• Enable notifications for reminders\n'
                      '• Choose between light and dark theme\n'
                      '• Optional menstruation question on/off',
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.lightbulb_outline,
                title: _isDutch ? 'Tips voor succes' : 'Tips for Success',
                description: _isDutch
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
                        Icon(Icons.security, color: AppTheme.primaryTeal),
                        SizedBox(width: 8),
                        Text(
                          _isDutch ? 'Privacy & Beveiliging' : 'Privacy & Security',
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
                      _isDutch
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
        color: AppTheme.primaryTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryTeal.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            color: AppTheme.primaryTeal,
            size: 32,
          ),
          SizedBox(height: 12),
          Text(
            _isDutch
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
              color: AppTheme.primaryTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryTeal,
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
              color: Colors.grey.shade500,
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
