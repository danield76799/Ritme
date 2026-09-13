import 'package:flutter/material.dart';

/// Kaart voor een overzichtsmetriek (icoon + titel/waarde).
///
/// Op een telefoon staan "SRT Score" en "Activiteiten deze week" naast elkaar.
/// Elke kaart is dan ~160dp breed, waarvan 36dp padding, 48dp icoon en 16dp
/// tussenruimte afgaan: er blijft ~59dp over voor de titel. "Activiteiten"
/// heeft ~100dp nodig, dus brak Flutter midden in het woord af
/// ("Activiteite" / "n deze week").
///
/// Onder [stackBreakpoint] zet deze widget het icoon daarom BOVEN de tekst in
/// plaats van ernaast. De titel krijgt dan de volledige kaartbreedte en breekt
/// netjes op woordgrenzen. De drempel is een breedtemeting, geen check op een
/// specifiek label: een langere vertaling of een smaller toestel wordt hierdoor
/// automatisch opgevangen.
class MetricCardShell extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  /// De titel/waarde-inhoud van de kaart.
  final Widget content;

  const MetricCardShell({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.content,
  });

  /// Onder deze breedte stapelen we icoon en tekst.
  static const double stackBreakpoint = 240.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final iconBox = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 24),
    );

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < stackBreakpoint) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    iconBox,
                    const SizedBox(height: 12),
                    content,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  iconBox,
                  const SizedBox(width: 16),
                  Expanded(child: content),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
