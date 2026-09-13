import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Kleuraccent voor een dashboardtegel.
///
/// De pastelkleuren die op de donkere kaart (#223236) ruim boven de WCAG-norm
/// zitten, halen op een witte kaart maar ~2:1. Daarom houdt dit object twee
/// varianten bij: [dark] voor dark mode, [light] voor light mode. Beide zijn
/// doorgerekend op >=3:1 tegen de eigen kaartachtergrond (non-text contrast).
class TileAccent {
  /// Icoonkleur in dark mode (pastel, rustig).
  final Color dark;

  /// Icoonkleur in light mode (verzadigde variant met >=4.5:1 op wit).
  final Color light;

  const TileAccent({required this.dark, required this.light});

  /// Resolve de juiste variant voor de huidige brightness.
  Color colorFor(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  // --- Vaste accenten per tegel -------------------------------------------

  /// Ochtend — zacht warm amber.
  static const morning = TileAccent(dark: Color(0xFFF2C879), light: Color(0xFF8A5A00));

  /// Avond — diep indigo / lavendel.
  static const evening = TileAccent(dark: Color(0xFF9B8FD4), light: Color(0xFF5A4F8A));

  /// Medicatie — subtiel pastel mint.
  static const medication = TileAccent(dark: Color(0xFF7FC8A9), light: Color(0xFF1F7A5A));

  /// Dagboek — zacht saliegroen.
  static const journal = TileAccent(dark: Color(0xFF8FBF9F), light: Color(0xFF2E7D4F));

  /// Rapport — rustig leisteenblauw.
  static const report = TileAccent(dark: Color(0xFF8FB8C9), light: Color(0xFF2F6675));

  /// Afspraken — rustig leisteenblauw (iets koeler, zodat de twee
  /// leisteen-tegels toch van elkaar te onderscheiden zijn).
  static const appointments = TileAccent(dark: Color(0xFF8FA9C9), light: Color(0xFF2F5A75));
}

/// Ronde icoon-container met zachte thematische achtergrond + complementair
/// icoon. Dit is de bouwsteen voor elke dashboardtegel, zodat alle tegels
/// dezelfde vorm, maat en gelaagdheid houden.
class TileIconBadge extends StatelessWidget {
  final IconData icon;
  final TileAccent accent;
  final double size;
  final double iconSize;

  /// Voltooid: toont een klein groen vinkje rechtsboven, passend bij de
  /// teller bovenaan ("X/4 ingevuld").
  final bool isCompleted;

  const TileIconBadge({
    super.key,
    required this.icon,
    required this.accent,
    this.size = 60,
    this.iconSize = 28,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = accent.colorFor(brightness);
    final cardColor = Theme.of(context).cardColor;
    final success = AppTheme.successOn(brightness);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            // Gedempte, zachte achtergrond in dezelfde tint als het icoon.
            color: color.withValues(alpha: brightness == Brightness.dark ? 0.16 : 0.12),
            shape: BoxShape.circle,
            border: isCompleted
                ? Border.all(color: success.withValues(alpha: 0.55), width: 1.5)
                : null,
          ),
          child: Icon(icon, color: color, size: iconSize),
        ),
        if (isCompleted)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle),
              child: Icon(Icons.check_circle, color: success, size: 18),
            ),
          ),
      ],
    );
  }
}
