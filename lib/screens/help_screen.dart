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
    // Auto-detect language based on system locale
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        title: Text(
          _isDutch ? 'Gebruiksaanwijzing' : 'User Guide',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: _toggleLanguage,
            icon: const Icon(Icons.language, color: Colors.white),
            label: Text(
              _isDutch ? 'EN' : 'NL',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
              // Intro
              _buildIntro(),
              const SizedBox(height: 24),

              _buildSection(
                icon: Icons.mood,
                title: _isDutch ? 'Stemming bijhouden' : 'Track Mood',
                description: _isDutch
                    ? 'Tik op het smiley-icoon om je stemming te registreren.\n\n'
                      '• Gebruik de schuifbalk om aan te geven hoe je je voelt\n'
                      '• Schaal loopt van -5 (heel slecht) tot +5 (heel goed)\n'
                      '• 0 is neutraal - geen bijzondere stemming\n'
                      '• Je kunt ook aangeven hoeveel uur je hebt geslapen\n'
                      '• Probeer dit dagelijks te doen voor het beste overzicht'
                    : 'Tap the smiley icon to register your mood.\n\n'
                      '• Use the slider to indicate how you feel\n'
                      '• Scale ranges from -5 (very bad) to +5 (very good)\n'
                      '• 0 is neutral - no particular mood\n'
                      '• You can also indicate how many hours you slept\n'
                      '• Try to do this daily for the best overview',
              ),
              const SizedBox(height: 20),
              
              // Mood scale details
              _buildDetailCard(
                title: _isDutch ? 'Stemmingsschaal (-5 tot +5)' : 'Mood Scale (-5 to +5)',
                children: [
                  _buildScaleItem(color: Colors.grey.shade800!, label: _isDutch ? '-5: Uiterst depressief' : '-5: Extremely depressed'),
                  _buildScaleItem(color: Colors.black!, label: _isDutch ? '-3: Matig depressief' : '-3: Moderately depressed'),
                  _buildScaleItem(color: AppTheme.primaryTeal, label: '0: ${_isDutch ? 'Neutraal' : 'Neutral'}'),
                  _buildScaleItem(color: Colors.orange, label: _isDutch ? '+3: Matig manisch' : '+3: Moderately manic'),
                  _buildScaleItem(color: Colors.red, label: _isDutch ? '+5: Uiterst manisch' : '+5: Extremely manic'),
                ],
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.bedtime,
                title: _isDutch ? 'Slaap registreren' : 'Track Sleep',
                description: _isDutch
                    ? 'In het slaap-scherm kun je je slaapgegevens invoeren.\n\n'
                      '• Vul je bedtijd in (wanneer ging je naar bed?)\n'
                      '• Vul je wakkerwordtijd in (wanneer stond je op?)\n'
                      '• Geef aan hoeveel minuten je wakker lag\n'
                      '• De app berekent automatisch je slaapduur\n'
                      '• Je slaapkwaliteit wordt bijgehouden in de statistieken'
                    : 'In the sleep screen you can enter your sleep data.\n\n'
                      '• Enter your bedtime (when did you go to bed?)\n'
                      '• Enter your wake-up time (when did you get up?)\n'
                      '• Indicate how many minutes you were awake\n'
                      '• The app automatically calculates your sleep duration\n'
                      '• Your sleep quality is tracked in statistics',
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.local_activity,
                title: _isDutch ? 'Activiteiten plannen' : 'Plan Activities',
                description: _isDutch
                    ? 'Voeg sociale en fysieke activiteiten toe aan je dag.\n\n'
                      '• Kies een activiteit (bijv. wandelen, koffie met vrienden)\n'
                      '• Stel een tijd in wanneer je dit wilt doen\n'
                      '• Geef aan of het een sociale of fysieke activiteit is\n'
                      '• Activiteiten helpen om structuur in je dag te brengen\n'
                      '• Je kunt activiteiten later als "voltooid" markeren'
                    : 'Add social and physical activities to your day.\n\n'
                      '• Choose an activity (e.g., walking, coffee with friends)\n'
                      '• Set a time when you want to do this\n'
                      '• Indicate whether it is a social or physical activity\n'
                      '• Activities help bring structure to your day\n'
                      '• You can mark activities as "completed" later',
              ),
              const SizedBox(height: 20),

              // P-Score Legend
              _buildDetailCard(
                title: _isDutch ? 'P-Score Legenda (Sociaal Ritme)' : 'P-Score Legend (Social Rhythm)',
                children: [
                  _buildPScoreItem(icon: Icons.check_circle, color: Colors.green, label: _isDutch ? '✓ Binnen 45 min' : '✓ Within 45 min', points: '3-5 ${_isDutch ? 'punten' : 'points'}'),
                  _buildPScoreItem(icon: Icons.remove_circle_outline, color: Colors.orange, label: _isDutch ? '~ Binnen 60 min' : '~ Within 60 min', points: '2 ${_isDutch ? 'punten' : 'points'}'),
                  _buildPScoreItem(icon: Icons.warning, color: Colors.red, label: _isDutch ? '! Meer dan 60 min' : '! More than 60 min', points: '1 ${_isDutch ? 'punt' : 'point'}'),
                  _buildPScoreItem(icon: Icons.cancel, color: Colors.grey, label: _isDutch ? 'Geen activiteit' : 'No activity', points: '0 ${_isDutch ? 'punten' : 'points'}'),
                ],
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.schedule,
                title: _isDutch ? 'SRT Score begrijpen' : 'Understanding SRT Score',
                description: _isDutch
                    ? 'De Social Rhythm Metric (SRT) meet je dagelijkse regelmaat.\n\n'
                      '• Score wordt berekend uit je activiteiten en slaap\n'
                      '• Hogere score = stabieler dagelijks ritme\n'
                      '• Doel: een consistent patroon van slapen en activiteiten\n'
                      '• Regelmatigheid helpt je biologische klok stabiliseren\n'
                      '• Dit kan bijdragen aan een betere stemming'
                    : 'The Social Rhythm Metric (SRT) measures your daily regularity.\n\n'
                      '• Score is calculated from your activities and sleep\n'
                      '• Higher score = more stable daily rhythm\n'
                      '• Goal: a consistent pattern of sleep and activities\n'
                      '• Regularity helps stabilize your biological clock\n'
                      '• This can contribute to better mood',
              ),
              const SizedBox(height: 20),

              // SRT Score Interpretation
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

              // Calculation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                  children: [
                    Text(
                      _isDutch ? 'Berekening' : 'Calculation',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textCharcoal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'SRT Score = (Average P-Score / 5) × 100%',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: AppTheme.textCharcoal,
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
                      '• Stemming trend: zie hoe je je de afgelopen week voelde\n'
                      '• Slaap overzicht: gemiddelde slaapduur en kwaliteit\n'
                      '• Activiteiten: hoeveel heb je deze week gedaan?\n'
                      '• SRT Score: je regelmaat over tijd\n'
                      '• Gebruik deze inzichten om je ritme te verbeteren'
                    : 'Tap the chart icon to see your progress.\n\n'
                      '• Mood trend: see how you felt last week\n'
                      '• Sleep overview: average sleep duration and quality\n'
                      '• Activities: how much did you do this week?\n'
                      '• SRT Score: your regularity over time\n'
                      '• Use these insights to improve your rhythm',
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.settings,
                title: _isDutch ? 'Instellingen' : 'Settings',
                description: _isDutch
                    ? 'Pas je voorkeuren aan in het instellingen-scherm.\n\n'
                      '• Wijzig je gebruikersnaam\n'
                      '• Stel notificaties in voor dagelijkse herinneringen\n'
                      '• Kies tussen licht en donker thema\n'
                      '• Beheer je accountgegevens'
                    : 'Adjust your preferences in the settings screen.\n\n'
                      '• Change your username\n'
                      '• Set notifications for daily reminders\n'
                      '• Choose between light and dark theme\n'
                      '• Manage your account details',
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.medication,
                title: _isDutch ? 'Medicatie bijhouden' : 'Track Medication',
                description: _isDutch
                    ? 'Houd je medicatie inname bij voor een compleet overzicht.\n\n'
                      '• Voeg je medicijnen toe met naam en dosering\n'
                      '• Stel herinneringen in voor vaste tijden\n'
                      '• Markeer medicatie als "genomen" of "overgeslagen"\n'
                      '• Consistente inname op vaste tijden is belangrijk'
                    : 'Track your medication intake for a complete overview.\n\n'
                      '• Add your medications with name and dosage\n'
                      '• Set reminders for fixed times\n'
                      '• Mark medication as "taken" or "skipped"\n'
                      '• Consistent intake at fixed times is important',
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.lightbulb_outline,
                title: _isDutch ? 'Tips voor succes' : 'Tips for Success',
                description: _isDutch
                    ? 'Maximaliseer het effect van Ritme met deze tips.\n\n'
                      '• Vul je stemming dagelijks in, liefst op hetzelfde tijdstip\n'
                      '• Houd je slaaptijden consistent, ook in het weekend\n'
                      '• Plan minimaal één sociale activiteit per dag\n'
                      '• Noteer belangrijke life events - die beïnvloeden je ritme\n'
                      '• Bekijk je statistieken wekelijks om patronen te herkennen\n'
                      '• Wees geduldig - verandering in ritme kost tijd'
                    : 'Maximize the effect of Ritme with these tips.\n\n'
                      '• Fill in your mood daily, preferably at the same time\n'
                      '• Keep your sleep times consistent, even on weekends\n'
                      '• Plan at least one social activity per day\n'
                      '• Note important life events - they affect your rhythm\n'
                      '• Review your statistics weekly to recognize patterns\n'
                      '• Be patient - changing rhythm takes time',
              ),
              const SizedBox(height: 20),

              // Privacy
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                        const SizedBox(width: 8),
                        Text(
                          _isDutch ? 'Privacy & Beveiliging' : 'Privacy & Security',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.textCharcoal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isDutch
                        ? '• Alle gegevens worden lokaal opgeslagen\n'
                          '• Optionele PIN-bescherming beschikbaar\n'
                          '• Geen data wordt naar externe servers gestuurd\n'
                          '• Exporteer je data als JSON voor backup'
                        : '• All data is stored locally\n'
                          '• Optional PIN protection available\n'
                          '• No data is sent to external servers\n'
                          '• Export your data as JSON for backup',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
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
          const SizedBox(height: 12),
          Text(
            _isDutch
              ? 'Ritme is gebaseerd op Social Rhythm Therapy (SRT), '
                'een bewezen methode om je dagelijks ritme te verbeteren. '
                'Door regelmatigheid in slaap, activiteiten en sociale contacten '
                'kun je je stemming en welbevinden positief beïnvloeden.'
              : 'Ritme is based on Social Rhythm Therapy (SRT), '
                'a proven method to improve your daily rhythm. '
                'Through regularity in sleep, activities, and social contacts '
                'you can positively influence your mood and well-being.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textCharcoal,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.textCharcoal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.textCharcoal,
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                range,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    action,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black,
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
