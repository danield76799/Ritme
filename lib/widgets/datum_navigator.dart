import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
      return DateFormat('EEEE d MMMM', 'nl_NL').format(datum);
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
            color: const Color(0xFF4FB2C1),
          ),
          
          // Datum weergave
          Expanded(
            child: Column(
              children: [
                Text(
                  _formatteerDatum(geselecteerdeDatum),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
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
                    child: const Text(
                      'Ga naar vandaag',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4FB2C1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Pijl vooruit
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 28),
            onPressed: _kanVooruit() ? _gaDagVooruit : null,
            color: _kanVooruit() ? const Color(0xFF4FB2C1) : Colors.grey[400],
          ),
        ],
      ),
    );
  }
}
