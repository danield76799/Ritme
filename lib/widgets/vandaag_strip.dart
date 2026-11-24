import 'package:flutter/material.dart';

/// Eén KPI in de "Vandaag"-strook.
class VandaagItem {
  final IconData icon;
  final String label;
  final String value;
  final String? delta;
  final VoidCallback? onTap;

  const VandaagItem({
    required this.icon,
    required this.label,
    required this.value,
    this.delta,
    this.onTap,
  });
}

/// Compacte strook met de drie kerncijfers van vandaag: stemming, slaap en
/// medicatie. Tikken opent het bijbehorende detailscherm.
class VandaagStrip extends StatelessWidget {
  final List<VandaagItem> items;

  /// Toelichting onder de strook, bijvoorbeeld 'Verschillen t.o.v. vorige
  /// week'. Staat er alleen als er daadwerkelijk een verschil getoond wordt.
  final String? voetnoot;

  const VandaagStrip({super.key, required this.items, this.voetnoot});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 44,
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
            Expanded(
              child: InkWell(
                onTap: items[i].onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(items[i].icon, size: 14, color: cs.primary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              items[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              items[i].value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (items[i].delta != null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                items[i].delta!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: cs.outline,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ], // sluit de spread-lijst van de for
            ], // sluit de children van de Row
          ),
          if (voetnoot != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                voetnoot!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
