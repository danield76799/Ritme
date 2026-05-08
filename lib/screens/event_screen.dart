import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../service_locator.dart';
import '../utils/logger.dart';

class GebeurtenisScherm extends StatefulWidget {
  @override
  _GebeurtenisSchermState createState() => _GebeurtenisSchermState();
}

class _GebeurtenisSchermState extends State<GebeurtenisScherm> {

  final TextEditingController _omschrijvingController = TextEditingController();
  double _invloedWaarde = 0;
  bool _isLoading = false;

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

    setState(() => _isLoading = true);

    try {
      await db.insertLifeEvent(_todayDate, _omschrijvingController.text.trim(), _invloedWaarde.toInt());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gebeurtenis opgeslagen!'),
          backgroundColor: AppTheme.primaryTeal,
        ),
      );

      _omschrijvingController.clear();
      setState(() => _invloedWaarde = 0);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save event', error: e, stackTrace: stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kon gebeurtenis niet opslaan. Probeer opnieuw.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Gebeurtenis', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Beschrijf een belangrijke gebeurtenis van vandaag:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _omschrijvingController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Bijv. Goed gesprek gehad met...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Invloed op stemming:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Slider(
              value: _invloedWaarde,
              min: -4,
              max: 4,
              divisions: 8,
              label: _haalLabelOp(_invloedWaarde),
              onChanged: (value) {
                setState(() => _invloedWaarde = value);
              },
            ),
            Center(
              child: Text(
                _haalLabelOp(_invloedWaarde),
                style: TextStyle(
                  color: _haalKleurOp(_invloedWaarde),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _opslaan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text('Opslaan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
