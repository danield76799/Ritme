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
        elevation: 0,
        title: Text(
          isDutch ? 'Gebruiksaanwijzing' : 'User Guide',
          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
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

              // Alles inklapbaar: kort scherm, details op aanvraag. De oude
              // tekst verwees nog naar tegels die niet meer bestaan
              // ("Stemming-tegel", "Activiteit & Slaap-tegel") — nu check-ins.
              _buildUitklap(
                icon: Icons.wb_sunny_outlined,
                title: isDutch ? 'Check-ins (ochtend & avond)' : 'Check-ins (morning & evening)',
                children: [
                  _bullets([
                    isDutch ? 'Ochtend: opstaantijd, slaap (behoefte + kwaliteit), stemming, gebeurtenis, eerste contact, werk/hobby' : 'Morning: wake time, sleep (need + quality), mood, event, first contact, work/hobby',
                    isDutch ? 'Avond: stemming (3x), gebeurtenis, avondeten, bedtijd' : 'Evening: mood (3x), event, dinner, bedtime',
                    isDutch ? 'Een afgeronde check-in kleurt de tegel groen op het dashboard' : 'A finished check-in turns the dashboard tile green',
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    isDutch ? 'Stemmingsschaal (−5 tot +5)' : 'Mood scale (−5 to +5)',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  _buildScaleItem(color: AppTheme.accentOn(Theme.of(context).brightness), label: isDutch ? '−5: Uiterst depressief' : '−5: Extremely depressed'),
                  _buildScaleItem(color: AppTheme.infoOn(Theme.of(context).brightness), label: isDutch ? '−3: Matig depressief' : '−3: Moderately depressed'),
                  _buildScaleItem(color: Theme.of(context).colorScheme.primary, label: '0: ${isDutch ? 'Neutraal' : 'Neutral'}'),
                  _buildScaleItem(color: AppTheme.streakText(Theme.of(context).brightness), label: isDutch ? '+3: Matig manisch' : '+3: Moderately manic'),
                  _buildScaleItem(color: AppTheme.dangerOn(Theme.of(context).brightness), label: isDutch ? '+5: Uiterst manisch' : '+5: Extremely manic'),
                ],
              ),
              const SizedBox(height: 12),

              _buildUitklap(
                icon: Icons.directions_walk,
                title: isDutch ? 'P-score legenda (sociaal ritme)' : 'P-score legend (social rhythm)',
                children: [
                  _buildPScoreItem(icon: Icons.check_circle, color: AppTheme.successOn(Theme.of(context).brightness), label: isDutch ? '✓✓ Binnen 15 min' : '✓✓ Within 15 min', points: '5 ${isDutch ? 'punten' : 'points'}'),
                  _buildPScoreItem(icon: Icons.check_circle_outline, color: AppTheme.successOn(Theme.of(context).brightness), label: isDutch ? '✓ Binnen 30 min' : '✓ Within 30 min', points: '4 ${isDutch ? 'punten' : 'points'}'),
                  _buildPScoreItem(icon: Icons.remove_circle_outline, color: AppTheme.streakText(Theme.of(context).brightness), label: isDutch ? '~ Binnen 45 min' : '~ Within 45 min', points: '3 ${isDutch ? 'punten' : 'points'}'),
                  _buildPScoreItem(icon: Icons.warning_amber, color: AppTheme.streakText(Theme.of(context).brightness), label: isDutch ? '! Binnen 60 min' : '! Within 60 min', points: '2 ${isDutch ? 'punten' : 'points'}'),
                  _buildPScoreItem(icon: Icons.error_outline, color: AppTheme.dangerOn(Theme.of(context).brightness), label: isDutch ? '!! Meer dan 60 min' : '!! More than 60 min', points: '1 ${isDutch ? 'punt' : 'point'}'),
                  _buildPScoreItem(icon: Icons.circle_outlined, color: Theme.of(context).colorScheme.outline, label: isDutch ? 'Geen activiteit' : 'No activity', points: '0 ${isDutch ? 'punten' : 'points'}'),
                ],
              ),
              const SizedBox(height: 12),

              _buildUitklap(
                icon: Icons.medication,
                title: isDutch ? 'Medicatie' : 'Medication',
                children: [
                  _bullets([
                    isDutch ? 'Voeg medicijnen toe met naam, dosering en vaste tijden' : 'Add medications with name, dosage and fixed times',
                    isDutch ? 'Herinneringen komen via notificaties; markeer als genomen of overgeslagen' : 'Reminders arrive via notifications; mark as taken or skipped',
                  ]),
                ],
              ),
              const SizedBox(height: 12),

              _buildUitklap(
                icon: Icons.schedule,
                title: AppLocalizations.of(context).srtScoreBegrijpen,
                children: [
                  Text(AppLocalizations.of(context).srtScoreDesc, style: const TextStyle(fontSize: 14, height: 1.5)),
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context).srtScoreInterpretatie, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  _buildScoreRange(range: '80-100%', color: Colors.green, label: isDutch ? 'Uitstekend stabiel' : 'Excellent stability', action: '✅ ${isDutch ? 'Blijf zo doorgaan' : 'Keep it up'}'),
                  _buildScoreRange(range: '60-79%', color: Colors.lightGreen, label: isDutch ? 'Goed, kleine variaties' : 'Good, small variations', action: '✅ ${isDutch ? 'Acceptabel' : 'Acceptable'}'),
                  _buildScoreRange(range: '40-59%', color: Colors.orange, label: isDutch ? 'Matig, aandacht nodig' : 'Moderate, attention needed', action: '⚠️ ${isDutch ? 'Monitor je ritme' : 'Monitor your rhythm'}'),
                  _buildScoreRange(range: '20-39%', color: Colors.deepOrange, label: isDutch ? 'Instabiel' : 'Unstable', action: '🔴 ${isDutch ? 'Bespreek met behandelaar' : 'Discuss with therapist'}'),
                  _buildScoreRange(range: '0-19%', color: Colors.red, label: isDutch ? 'Zeer instabiel' : 'Very unstable', action: '🚨 ${isDutch ? 'Hulp zoeken' : 'Seek help'}'),
                ],
              ),
              const SizedBox(height: 12),

              _buildUitklap(
                icon: Icons.explore_outlined,
                title: isDutch ? 'Rondkijken (statistieken, episodes, instellingen)' : 'Explore (statistics, episodes, settings)',
                children: [
                  _bullets([
                    isDutch ? 'Statistieken: weekgrafiek, slaap- en ritmedetails, SRT-trend' : 'Statistics: week graph, sleep and rhythm details, SRT trend',
                    isDutch ? 'Episodes, voortekenen, gewicht, afspraken en dagboek staan in het menu' : 'Episodes, prodromes, weight, appointments and journal live in the menu',
                    isDutch ? 'Doeltijden, thema en automatische backup stel je in bij Instellingen' : 'Target times, theme and automatic backup live in Settings',
                  ]),
                ],
              ),
              const SizedBox(height: 12),

              _buildUitklap(
                icon: Icons.lightbulb_outline,
                title: isDutch ? 'Tips voor succes' : 'Tips for success',
                children: [
                  _bullets([
                    isDutch ? 'Vul dagelijks in, liefst op vaste tijden — ook in het weekend' : 'Fill in daily, preferably at fixed times — weekends included',
                    isDutch ? 'Neem medicatie op de afgesproken tijden' : 'Take medication at the agreed times',
                    isDutch ? 'Bekijk je statistieken wekelijks om patronen te herkennen' : 'Review your statistics weekly to recognize patterns',
                    isDutch ? 'Alle gegevens blijven lokaal op je toestel (PIN/biometrie mogelijk)' : 'All data stays locally on your device (PIN/biometrics available)',
                  ]),
                ],
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
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
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

  /// Inklapbare Help-sectie: het scherm toont alleen koppen, details op
  /// aanvraag. Hoekentaal 12/16 uit de look-feel-sweep.
  Widget _buildUitklap({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
        ),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.smallRadius),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal,
          ),
        ),
        shape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: children,
      ),
    );
  }

  /// Korte bullet-lijst voor in een uitklap-sectie.
  Widget _bullets(List<String> regels) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: regels
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
                    Expanded(
                      child: Text(
                        r,
                        style: TextStyle(fontSize: 14, height: 1.5, color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
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
              color: Theme.of(context).colorScheme.onSurface,
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
                color: Theme.of(context).colorScheme.onSurface,
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
          borderRadius: BorderRadius.circular(AppTheme.smallRadius),
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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    action,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
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
