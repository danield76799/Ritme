import 'package:flutter/material.dart';

import '../utils/adherentie_dagen.dart';

/// Compacte 30-daagse adherentie-heatmap: één vierkantje per dag.
///
/// Kleuren komen uit het thema (geen hardcoded wit/zwart), zodat de kaart in
/// licht en donker leesbaar blijft. Bij minder dan [dagen] dagen (jonge
/// medicatie) worden alleen de beschikbare dagen getoond.
class AdherentieHeatmap extends StatelessWidget {
  final List<AdherentieDag> dagen;

  const AdherentieHeatmap({super.key, required this.dagen});

  Color _kleur(BuildContext context, DagStatus status) {
    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case DagStatus.genomen:
        return cs.primary;
      case DagStatus.gemist:
        return cs.error;
      case DagStatus.open:
        return cs.outline;
      case DagStatus.nietGepland:
        return cs.surfaceContainerHighest;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (dagen.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Adherentie laatste ${dagen.length} dagen',
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 3.0;
          final beschikbaar = constraints.maxWidth - gap * (dagen.length - 1);
          final zijde = (beschikbaar / dagen.length).clamp(5.0, 9.0);
          return Row(
            children: [
              for (var i = 0; i < dagen.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Tooltip(
                  message:
                      '${dagen[i].datum.day}-${dagen[i].datum.month}',
                  child: Container(
                    width: zijde,
                    height: zijde,
                    decoration: BoxDecoration(
                      color: _kleur(context, dagen[i].status),
                      border: dagen[i].status == DagStatus.open
                          ? Border.all(color: cs.outlineVariant)
                          : null,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
