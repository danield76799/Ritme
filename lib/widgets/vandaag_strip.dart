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

  const VandaagStrip({super.key, required this.items});

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
      child: Row(
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      Text(
                        items[i].value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (items[i].delta != null)
                        Text(
                          items[i].delta!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.outline,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
