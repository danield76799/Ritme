import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../generated/l10n/app_localizations.dart';

class DatumNavigator extends StatelessWidget {
  final DateTime geselecteerdeDatum;
  final ValueChanged<DateTime> onDatumVeranderd;
  final DateTime? maximaleDatum;

  const DatumNavigator({
    Key? key,
    required this.geselecteerdeDatum,
    required this.onDatumVeranderd,
    this.maximaleDatum,
  }) : super(key: key);

  String _formatteerDatum(DateTime datum) {
    final vandaag = DateTime.now();
    final gisteren = vandaag.subtract(const Duration(days: 1));
    
    if (datum.year == vandaag.year && datum.month == vandaag.month && datum.day == vandaag.day) {
      return 'Vandaag, ${DateFormat('d MMMM').format(datum)}';
    } else if (datum.year == gisteren.year && datum.month == gisteren.month && datum.day == gisteren.day) {
      return 'Gisteren, ${DateFormat('d MMMM').format(datum)}';
    } else {
      return DateFormat('EEEE d MMMM').format(datum);
    }
  }

  void _gaDagTerug() {
    final nieuweDatum = geselecteerdeDatum.subtract(const Duration(days: 1));
    onDatumVeranderd(nieuweDatum);
  }

  void _gaDagVooruit() {
    final vandaag = maximaleDatum ?? DateTime.now();
    final nieuweDatum = geselecteerdeDatum.add(const Duration(days: 1));
    
    // Controleer of we niet verder dan vandaag gaan
    if (nieuweDatum.isAfter(vandaag)) {
      return; // Niet toestaan om in de toekomst te gaan
    }
    
    onDatumVeranderd(nieuweDatum);
  }

  void _gaNaarVandaag() {
    onDatumVeranderd(DateTime.now());
  }

  bool _kanVooruit() {
    final vandaag = maximaleDatum ?? DateTime.now();
    final morgen = geselecteerdeDatum.add(const Duration(days: 1));
    return !morgen.isAfter(vandaag);
  }

  bool _isVandaag() {
    final vandaag = DateTime.now();
    return geselecteerdeDatum.year == vandaag.year && 
           geselecteerdeDatum.month == vandaag.month && 
           geselecteerdeDatum.day == vandaag.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Pijl terug
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 28),
            onPressed: _gaDagTerug,
            color: theme.colorScheme.primary,
          ),
          
          // Datum weergave (tik om datum te kiezen)
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: geselecteerdeDatum,
                  firstDate: DateTime(2020),
                  lastDate: maximaleDatum ?? DateTime.now(),
                );
                if (picked != null) {
                  onDatumVeranderd(picked);
                }
              },
              child: Column(
                children: [
                  Text(
                    _formatteerDatum(geselecteerdeDatum),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!_isVandaag())
                    TextButton(
                      onPressed: _gaNaarVandaag,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        AppLocalizations.of(context).gaNaarVandaag,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Pijl vooruit
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 28),
            onPressed: _kanVooruit() ? _gaDagVooruit : null,
            color: _kanVooruit() ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}
