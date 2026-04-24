import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  final _db = DatabaseHelper.instance;
  final Color primaryTeal = const Color(0xFF4FB2C1);
  final Color textCharcoal = const Color(0xFF333333);
  final Color backgroundColor = const Color(0xFFFAFAFA);

  List<Map<String, dynamic>> _medications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    final meds = await _db.getMedications();
    setState(() {
      _medications = meds;
      _isLoading = false;
    });
  }

  void _changeAmount(int index, int change) {
    setState(() {
      int newAmount = (_medications[index]['aantal_ingenomen'] ?? 0) + change;
      if (newAmount >= 0) {
        _medications[index]['aantal_ingenomen'] = newAmount;
      }
    });
  }

  Future<void> _save() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    for (int i = 0; i < _medications.length; i++) {
      final med = _medications[i];
      final amount = med['aantal_ingenomen'] ?? 0;
      
      if (amount > 0) {
        await _db.upsertMedicationIntake({
          'medication_id': med['id'],
          'date': today,
          'time_slot': 'morning',
          'taken': amount,
          'taken_at': DateTime.now().toIso8601String(),
        });
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Medicatie inname succesvol opgeslagen!'),
          backgroundColor: primaryTeal,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryTeal,
        elevation: 0,
        title: const Text(
          'Medicatie Loggen',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wat heb je vandaag ingenomen?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textCharcoal),
            ),
            const SizedBox(height: 8),
            Text(
              'Noteer hieronder het totaal aantal tabletten / capsules dat je per dag hebt ingenomen.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            
            Expanded(
              child: _medications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.medication_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Geen medicatie ingesteld',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _medications.length,
                      itemBuilder: (context, index) {
                        final medicijn = _medications[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    medicijn['name'] ?? 'Onbekend',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textCharcoal),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${medicijn['dosage'] ?? ''} ${medicijn['frequency'] ?? ''}',
                                    style: TextStyle(fontSize: 14, color: primaryTeal),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
                                    onPressed: () => _changeAmount(index, -1),
                                  ),
                                  Container(
                                    width: 30,
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${medicijn['aantal_ingenomen'] ?? 0}',
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textCharcoal),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add_circle, color: primaryTeal),
                                    onPressed: () => _changeAmount(index, 1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Opslaan',
                  style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}