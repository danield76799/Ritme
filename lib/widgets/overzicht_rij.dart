import 'package:flutter/material.dart';

/// Eén rij in een overzichtsscherm: icoon + label + waarde.
/// Gedeeld door de ochtend- en avond check-in.
///
/// [accent] kleurt icoon en waarde (bv. de scorekleur bij een check-in
/// antwoord). Zonder accent blijft de standaard primaire kleur.
class OverzichtRij extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;

  const OverzichtRij({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final kleurtje = accent ?? Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent != null
              ? kleurtje.withValues(alpha: 0.45)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: kleurtje),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kleurtje),
            ),
          ),
        ],
      ),
    );
  }
}