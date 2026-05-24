import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        title: const Text(
          'Gebruiksaanwijzing',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Intro
              Container(
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
                      'Ritme is gebaseerd op Social Rhythm Therapy (SRT), '
                      'een bewezen methode om je dagelijks ritme te verbeteren. '
                      'Door regelmatigheid in slaap, activiteiten en sociale contacten '
                      'kun je je stemming en welbevinden positief beïnvloeden.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textCharcoal,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildSection(
                icon: Icons.mood,
                title: 'Stemming bijhouden',
                description:
                    'Tik op het smiley-icoon om je stemming te registreren.\n\n'
                    '• Gebruik de schuifbalk om aan te geven hoe je je voelt\n'
                    '• Schaal loopt van -5 (heel slecht) tot +5 (heel goed)\n'
                    '• 0 is neutraal - geen bijzondere stemming\n'
                    '• Je kunt ook aangeven hoeveel uur je hebt geslapen\n'
                    '• Probeer dit dagelijks te doen voor het beste overzicht',
              ),
              const SizedBox(height: 20),
              
              // Stemmingsschaal details
              _buildDetailCard(
                title: 'Stemmingsschaal (-5 tot +5)',
                children: [
                  _buildScaleItem(color: Colors.grey[800]!, label: '-5: Uiterst depressief'),
                  _buildScaleItem(color: Colors.grey[600]!, label: '-3: Matig depressief'),
                  _buildScaleItem(color: AppTheme.primaryTeal, label: '0: Neutraal'),
                  _buildScaleItem(color: Colors.orange, label: '+3: Matig manisch'),
                  _buildScaleItem(color: Colors.red, label: '+5: Uiterst manisch'),
                ],
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.bedtime,
                title: 'Slaap registreren',
                description:
                    'In het slaap-scherm kun je je slaapgegevens invoeren.\n\n'
                    '• Vul je bedtijd in (wanneer ging je naar bed?)\n'
                    '• Vul je wakkerwordtijd in (wanneer stond je op?)\n'
                    '• Geef aan hoeveel minuten je wakker lag\n'
                    '• De app berekent automatisch je slaapduur\n'
                    '• Je slaapkwaliteit wordt bijgehouden in de statistieken',
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.local_activity,
                title: 'Activiteiten plannen',
                description:
                    'Voeg sociale en fysieke activiteiten toe aan je dag.\n\n'
                    '• Kies een activiteit (bijv. wandelen, koffie met vrienden)\n'
                    '• Stel een tijd in wanneer je dit wilt doen\n'
                    '• Geef aan of het een sociale of fysieke activiteit is\n'
                    '• Activiteiten helpen om structuur in je dag te brengen\n'
                    '• Je kunt activiteiten later als "voltooid" markeren',
              ),
              const SizedBox(height: 20),

              // P-Score Legenda
              _buildDetailCard(
                title: 'P-Score Legenda (Sociaal Ritme)',
                children: [
                  _buildPScoreItem(icon: Icons.check_circle, color: Colors.green, label: '✓ Binnen 45 min', points: '3-5 punten'),
                  _buildPScoreItem(icon: Icons.remove_circle_outline, color: Colors.orange, label: '~ Binnen 60 min', points: '2 punten'),
                  _buildPScoreItem(icon: Icons.warning, color: Colors.red, label: '! Meer dan 60 min', points: '1 punt'),
                  _buildPScoreItem(icon: Icons.cancel, color: Colors.grey, label: 'Geen activiteit', points: '0 punten'),
                ],
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.schedule,
                title: 'SRT Score begrijpen',
                description:
                    'De Social Rhythm Metric (SRT) meet je dagelijkse regelmaat.\n\n'
                    '• Score wordt berekend uit je activiteiten en slaap\n'
                    '• Hogere score = stabieler dagelijks ritme\n'
                    '• Doel: een consistent patroon van slapen en activiteiten\n'
                    '• Regelmatigheid helpt je biologische klok stabiliseren\n'
                    '• Dit kan bijdragen aan een betere stemming',
              ),
              const SizedBox(height: 20),

              // SRT Score Interpretatie
              _buildDetailCard(
                title: 'SRT Score Interpretatie',
                children: [
                  _buildScoreRange(range: '80-100%', color: Colors.green, label: 'Uitstekend stabiel', action: '✅ Blijf zo doorgaan'),
                  _buildScoreRange(range: '60-79%', color: Colors.lightGreen, label: 'Goed, kleine variaties', action: '✅ Acceptabel'),
                  _buildScoreRange(range: '40-59%', color: Colors.orange, label: 'Matig, aandacht nodig', action: '⚠️ Monitor je ritme'),
                  _buildScoreRange(range: '20-39%', color: Colors.deepOrange, label: 'Instabiel', action: '🔴 Bespreek met behandelaar'),
                  _buildScoreRange(range: '0-19%', color: Colors.red, label: 'Zeer instabiel', action: '🚨 Hulp zoeken'),
                ],
              ),
              const SizedBox(height: 20),

              // Berekening
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
                      'Berekening',
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
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'SRT Score = (Gemiddelde P-Score / 5) × 100%',
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
                title: 'Statistieken bekijken',
                description:
                    'Tik op het grafiek-icoon om je voortgang te zien.\n\n'
                    '• Stemming trend: zie hoe je je de afgelopen week voelde\n'
                    '• Slaap overzicht: gemiddelde slaapduur en kwaliteit\n'
                    '• Activiteiten: hoeveel heb je deze week gedaan?\n'
                    '• SRT Score: je regelmaat over tijd\n'
                    '• Gebruik deze inzichten om je ritme te verbeteren',
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.settings,
                title: 'Instellingen',
                description:
                    'Pas je voorkeuren aan in het instellingen-scherm.\n\n'
                    '• Wijzig je gebruikersnaam\n'
                    '• Stel notificaties in voor dagelijkse herinneringen\n'
                    '• Kies tussen licht en donker thema\n'
                    '• Beheer je accountgegevens',
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.medication,
                title: 'Medicatie bijhouden',
                description:
                    'Houd je medicatie inname bij voor een compleet overzicht.\n\n'
                    '• Voeg je medicijnen toe met naam en dosering\n'
                    '• Stel herinneringen in voor vaste tijden\n'
                    '• Markeer medicatie als "genomen" of "overgeslagen"\n'
                    '• Consistente inname op vaste tijden is belangrijk',
              ),
              const SizedBox(height: 20),

              _buildSection(
                icon: Icons.lightbulb_outline,
                title: 'Tips voor succes',
                description:
                    'Maximaliseer het effect van Ritme met deze tips.\n\n'
                    '• Vul je stemming dagelijks in, liefst op hetzelfde tijdstip\n'
                    '• Houd je slaaptijden consistent, ook in het weekend\n'
                    '• Plan minimaal één sociale activiteit per dag\n'
                    '• Noteer belangrijke life events - die beïnvloeden je ritme\n'
                    '• Bekijk je statistieken wekelijks om patronen te herkennen\n'
                    '• Wees geduldig - verandering in ritme kost tijd',
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
                          'Privacy & Beveiliging',
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
                      '• Alle gegevens worden lokaal opgeslagen\n'
                      '• Optionele PIN-bescherming beschikbaar\n'
                      '• Geen data wordt naar externe servers gestuurd\n'
                      '• Exporteer je data als JSON voor backup',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
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
                    color: Colors.grey[600],
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
              color: Colors.grey[700],
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
                color: Colors.grey[700],
              ),
            ),
          ),
          Text(
            points,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
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
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    action,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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
