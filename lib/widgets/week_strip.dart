import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

/// Weekstrip om snel een dag te kiezen.
///
/// Vervangt het "tik op de datum, dan opent een dialoog"-patroon: de
/// dagen van de week staan meteen zichtbaar, en met de pijltjes ga je naar
/// de vorige of volgende week. De datumkiezer blijft bereikbaar via het
/// kalendericoon, voor wanneer je ver terug wilt.
class WeekStrip extends StatelessWidget {
  /// De maandag van de week die getoond wordt.
  final DateTime weekStart;

  /// De gekozen dag.
  final DateTime selected;

  /// Wordt aangeroepen als de gebruiker een dag kiest.
  final ValueChanged<DateTime> onSelected;

  /// Wordt aangeroepen als de gebruiker naar de vorige (-1) of volgende
  /// (+1) week gaat.
  final ValueChanged<int> onShiftWeek;

  const WeekStrip({
    super.key,
    required this.weekStart,
    required this.selected,
    required this.onSelected,
    required this.onShiftWeek,
  });

  /// De maandag van de week waarin de gegeven dag valt.
  static DateTime mondayOf(DateTime dag) {
    final middernacht = DateTime(dag.year, dag.month, dag.day);
    return middernacht.subtract(
      Duration(days: middernacht.weekday - DateTime.monday),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString().split('_').first;
    final vandaag = DateTime.now();

    return SizedBox(
      height: 68,
      child: Row(
        children: [
          _pijl(context, icon: Icons.chevron_left, onTap: () => onShiftWeek(-1)),
          for (int i = 0; i < 7; i++)
            Expanded(
              child: _dagChip(
                context,
                theme,
                locale,
                weekStart.add(Duration(days: i)),
                vandaag,
              ),
            ),
          _pijl(context, icon: Icons.chevron_right, onTap: () => onShiftWeek(1)),
        ],
      ),
    );
  }

  Widget _pijl(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      color: AppTheme.secondaryText(context),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
    );
  }

  Widget _dagChip(
    BuildContext context,
    ThemeData theme,
    String locale,
    DateTime dag,
    DateTime vandaag,
  ) {
    final geselecteerd =
        dag.year == selected.year &&
        dag.month == selected.month &&
        dag.day == selected.day;
    final isVandaag =
        dag.year == vandaag.year &&
        dag.month == vandaag.month &&
        dag.day == vandaag.day;
    final accent = theme.colorScheme.primary;
    final opAccent = theme.colorScheme.onPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () => onSelected(dag),
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        child: Container(
          decoration: BoxDecoration(
            color: geselecteerd ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.smallRadius),
            border: Border.all(
              color: geselecteerd
                  ? accent
                  : (isVandaag
                        ? accent.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.06)),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('EEE', locale).format(dag).substring(0, 2),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: geselecteerd
                      ? opAccent
                      : AppTheme.secondaryText(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${dag.day}',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: geselecteerd ? opAccent : AppTheme.primaryText(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
