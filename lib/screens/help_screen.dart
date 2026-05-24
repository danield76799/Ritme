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
                icon: Icons.lightbulb_outline,
                title: 'Tips voor succes',
                description:
                    'Maximaliseer het effect van Ritme met deze tips.\n\n'
                    '• Vul je stemming dagelijks in, liefst op hetzelfde tijdstip\n'
                    '• Houd je slaaptijden consistent, ook in het weekend\n'
                    '• Plan minimaal één sociale activiteit per dag\n'
                    '• Bekijk je statistieken wekelijks om patronen te herkennen\n'
                    '• Wees geduldig - verandering in ritme kost tijd',
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
}
