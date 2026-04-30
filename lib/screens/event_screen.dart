import 'package:flutter/material.dart';
import '../service_locator.dart';
import '../utils/app_theme.dart';

class GebeurtenisScherm extends StatefulWidget {
  @override
  _GebeurtenisSchermState createState() => _GebeurtenisSchermState();
}

class _GebeurtenisSchermState extends State<GebeurtenisScherm> {

  final TextEditingController _omschrijvingController = TextEditingController();
  double _invloedWaarde = 0;

  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Color _haalKleurOp(double waarde) {
    if (waarde > 0) return Colors.green;
    if (waarde < 0) return Colors.orange;
    return AppTheme.primaryTeal;
  }

  String _haalLabelOp(double waarde) {
    if (waarde == 4) return 'Uiterst positief';
    if (waarde > 0) return 'Positief';
    if (waarde == -4) return 'Uiterst negatief';
    if (waarde < 0) return 'Negatief';
    return 'Neutraal';
  }

  Future<void> _opslaan() async {
    if (_omschrijvingController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vul eerst een korte omschrijving in.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      final event = {
        'date': _todayDate,
        'omschrijving': _omschrijvingController.text.trim(),
        'invloed': _invloedWaarde.round(),
      };
      
      await db.insertLifeEventMap(event);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gebeurtenis succesvol toegevoegd aan je Life Chart!'),
            backgroundColor: AppTheme.primaryTeal,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij opslaan: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _omschrijvingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColorAlt,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        title: Text('Gebeurtenis Loggen', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingrijpende gebeurtenis',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textCharcoal),
              ),
              const SizedBox(height: 8),
              Text(
                'Noteer hier belangrijke gebeurtenissen (bijv. ruzie met collega, dochter geslaagd) en de invloed daarvan.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),

              // --- OMSCHRIJVING VELD ---
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: TextField(
                  controller: _omschrijvingController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Wat is er gebeurd?',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // --- INVLOED SCHUIFREGELAAR ---
              Text(
                'Invloed op stemming',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textCharcoal),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      _invloedWaarde > 0 ? '+${_invloedWaarde.round()}' : '${_invloedWaarde.round()}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: _haalKleurOp(_invloedWaarde),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _haalLabelOp(_invloedWaarde),
                      style: TextStyle(fontSize: 16, color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 24),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _haalKleurOp(_invloedWaarde),
                        inactiveTrackColor: Colors.grey[200],
                        thumbColor: _haalKleurOp(_invloedWaarde),
                        valueIndicatorColor: _haalKleurOp(_invloedWaarde),
                        trackHeight: 8.0,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16.0),
                      ),
                      child: Slider(
                        value: _invloedWaarde,
                        min: -4,
                        max: 4,
                        divisions: 8,
                        label: _invloedWaarde > 0 ? '+${_invloedWaarde.round()}' : '${_invloedWaarde.round()}',
                        onChanged: (double nieuweWaarde) {
                          setState(() {
                            _invloedWaarde = nieuweWaarde;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('-4 (Negatief)', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          Text('0', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          Text('+4 (Positief)', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // --- OPSLAAN KNOP ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _opslaan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Opslaan in Life Chart', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
