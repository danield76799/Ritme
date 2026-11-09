import 'package:flutter/material.dart';
import '../generated/l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          l10n.helpTitel,
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
                title: l10n.helpCheckinsTitel,
                children: [
                  _bullets([
                    l10n.helpCheckinOchtend,
                    l10n.helpCheckinAvond,
                    l10n.helpCheckinGroen,
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    l10n.helpStemmingsschaalTitel,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  _buildScaleItem(color: AppTheme.accentOn(Theme.of(context).brightness), label: l10n.helpSchaalMin5),
                  _buildScaleItem(color: AppTheme.infoOn(Theme.of(context).brightness), label: l10n.helpSchaalMin3),
                  _buildScaleItem(color: Theme.of(context).colorScheme.primary, label: l10n.helpSchaalNul),
                  _buildScaleItem(color: AppTheme.streakText(Theme.of(context).brightness), label: l10n.helpSchaalPlus3),
                  _buildScaleItem(color: AppTheme.dangerOn(Theme.of(context).brightness), label: l10n.helpSchaalPlus5),
                ],
              ),
              const SizedBox(height: 12),

              _buildUitklap(
                icon: Icons.directions_walk,
                title: l10n.helpPScoreTitel,
                children: [
                  _buildPScoreItem(
                    icon: Icons.check_circle,
                    color: AppTheme.successOn(Theme.of(context).brightness),
                    label: l10n.helpPScore15,
                    points: '5 ${l10n.helpPunten}',
                  ),
                  _buildPScoreItem(
                    icon: Icons.check_circle_outline,
                    color: AppTheme.successOn(Theme.of(context).brightness),
                    label: l10n.helpPScore30,
                    points: '4 ${l10n.helpPunten}',
                  ),
                  _buildPScoreItem(
                    icon: Icons.remove_circle_outline,
                    color: AppTheme.streakText(Theme.of(context).brightness),
                    label: l10n.helpPScore45,
                    points: '3 ${l10n.helpPunten}',
                  ),
                  _buildPScoreItem(
                    icon: Icons.warning_amber,
                    color: AppTheme.streakText(Theme.of(context).brightness),
                    label: l10n.helpPScore60,
                    points: '2 ${l10n.helpPunten}',
                  ),
                  _buildPScoreItem(
                    icon: Icons.error_outline,
                    color: AppTheme.dangerOn(Theme.of(context).brightness),
                    label: l10n.helpPScoreMeer60,
                    points: '1 ${l10n.helpPunt}',
                  ),
                  _buildPScoreItem(
                    icon: Icons.circle_outlined,
                    color: Theme.of(context).colorScheme.outline,
                    label: l10n.helpPScoreGeen,
                    points: '0 ${l10n.helpPunten}',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildUitklap(
                icon: Icons.medication,
                title: l10n.helpMedicatieTitel,
                children: [
                  _bullets([
                    l10n.helpMedicatieToevoegen,
                    l10n.helpMedicatieHerinnering,
                  ]),
                ],
              ),
              const SizedBox(height: 12),

              _buildUitklap(
                icon: Icons.schedule,
                title: l10n.srtScoreBegrijpen,
                children: [
                  Text(l10n.srtScoreDesc, style: const TextStyle(fontSize: 14, height: 1.5)),
                  const SizedBox(height: 12),
                  Text(l10n.srtScoreInterpretatie, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  _buildScoreRange(range: '80-100%', color: Colors.green, label: l10n.helpSrtUitstekend, action: l10n.helpSrtUitstekendActie),
                  _buildScoreRange(range: '60-79%', color: Colors.lightGreen, label: l10n.helpSrtGoed, action: l10n.helpSrtGoedActie),
                  _buildScoreRange(range: '40-59%', color: Colors.orange, label: l10n.helpSrtMatig, action: l10n.helpSrtMatigActie),
                  _buildScoreRange(range: '20-39%', color: Colors.deepOrange, label: l10n.helpSrtInstabiel, action: l10n.helpSrtInstabielActie),
                  _buildScoreRange(range: '0-19%', color: Colors.red, label: l10n.helpSrtZeerInstabiel, action: l10n.helpSrtZeerInstabielActie),
                ],
              ),
              const SizedBox(height: 12),

              _buildUitklap(
                icon: Icons.explore_outlined,
                title: l10n.helpRondkijkenTitel,
                children: [
                  _bullets([
                    l10n.helpRondkijkenStatistieken,
                    l10n.helpRondkijkenMenu,
                    l10n.helpRondkijkenInstellingen,
                  ]),
                ],
              ),
              const SizedBox(height: 12),

              _buildUitklap(
                icon: Icons.lightbulb_outline,
                title: l10n.helpTipsTitel,
                children: [
                  _bullets([
                    l10n.helpTipDagelijks,
                    l10n.helpTipMedicatie,
                    l10n.helpTipStatistieken,
                    l10n.helpTipLokaal,
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
    final l10n = AppLocalizations.of(context);
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
            l10n.helpIntro,
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
