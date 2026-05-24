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
              _buildSection(
                icon: Icons.mood,
                title: 'Stemming bijhouden',
                description:
                    'Tik op het smiley-icoon om je stemming te registreren. '
                    'Gebruik de schuifbalk om aan te geven hoe je je voelt (-5 tot +5). '
                    'Je kunt ook aangeven hoeveel uur je hebt geslapen.',
              ),
              const SizedBox(height: 20),
              _buildSection(
                icon: Icons.bedtime,
                title: 'Slaap registreren',
                description:
                    'In het slaap-scherm kun je je bedtijd, wakkerwordtijd en '
                    'eventuele wakker-momenten invullen. Dit helpt om je slaappatroon '
                    'te analyseren en je slaapkwaliteit te verbeteren.',
              ),
              const SizedBox(height: 20),
              _buildSection(
                icon: Icons.local_activity,
                title: 'Activiteiten plannen',
                description:
                    'Voeg sociale en fysieke activiteiten toe aan je dag. '
                    'Dit helpt om een regelmatig ritme op te bouwen.',
              ),
              const SizedBox(height: 20),
              _buildSection(
                icon: Icons.schedule,
                title: 'SRT Score',
                description:
                    'De Social Rhythm Metric (SRT) meet hoe regelmatig je '
                    'activiteiten uitvoert. Een hogere score betekent een '
                    'stabieler dagelijks ritme.',
              ),
              const SizedBox(height: 20),
              _buildSection(
                icon: Icons.bar_chart,
                title: 'Statistieken bekijken',
                description:
                    'Tik op het grafiek-icoon om je voortgang te zien. '
                    'Je kunt hier trends in stemming, slaap en activiteiten volgen.',
              ),
              const SizedBox(height: 20),
              _buildSection(
                icon: Icons.settings,
                title: 'Instellingen',
                description:
                    'Pas je gebruikersnaam, notificaties en andere '
                    'voorkeuren aan in het instellingen-scherm.',
              ),
              const SizedBox(height: 30),
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
                      'Ritme helpt je om je dagelijks ritme bij te houden. '
                      'Regelmatigheid in slaap, activiteiten en sociale contacten '
                      'draagt bij aan een beter welbevinden.',
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
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
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
