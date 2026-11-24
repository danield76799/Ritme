import 'package:flutter/material.dart';

/// Mini-staafgrafiek voor zo-nodig-gebruik: innames per week (oud → nieuw).
class PrnWeekBars extends StatelessWidget {
  /// Aantallen per week, oud → nieuw.
  final List<int> waarden;

  const PrnWeekBars({super.key, required this.waarden});

  @override
  Widget build(BuildContext context) {
    if (waarden.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final maxWaarde = waarden.reduce((a, b) => a > b ? a : b);
    return Semantics(
      label: 'Gebruik per week: ${waarden.join(", ")}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < waarden.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Tooltip(
              message: '${waarden[i]}×',
              child: Container(
                width: 8,
                height: maxWaarde == 0 ? 3 : 3 + (21 * waarden[i] / maxWaarde),
                decoration: BoxDecoration(
                  color: waarden[i] == 0
                      ? cs.surfaceContainerHighest
                      : cs.tertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
