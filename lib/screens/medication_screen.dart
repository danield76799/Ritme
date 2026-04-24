import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../main.dart';

class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  final Color primaryTeal = const Color(0xFF4FB2C1);
  final Color textCharcoal = const Color(0xFF333333);
  final Color backgroundColor = const Color(0xFFFAFAFA);

  List<Map<String, dynamic>> _medications = [];
  Map<int, int> _intakeAmounts = {}; // medication_id -> amount taken
  bool _isLoading = true;

  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    final meds = await db.getMedicationConfigs();
    final intakes = await db.getMedicationIntake(_todayDate);
    
    // Build intake map for today
    Map<int, int> intakeMap = {};
    for (var intake in intakes) {
      intakeMap[intake['medication_id']] = intake['aantal_ingenomen'];
    }
    
    setState(() {
      _medications = meds;
      _intakeAmounts = intakeMap;
      _isLoading = false;
    });
  }

  void _changeAmount(int index, int change) {
    final medId = _medications[index]['id'];
    setState(() {
      int newAmount = (_intakeAmounts[medId] ?? 0) + change;
      if (newAmount >= 0) {
        _intakeAmounts[medId] = newAmount;
      }
    });
  }

  Future<void> _save() async {
    if (_isLoading) return;
    
    for (int i = 0; i < _medications.length; i++) {
      final med = _medications[i];
      final medId = med['id'];
      final amount = _intakeAmounts[medId] ?? 0;
      
      if (amount > 0) {
        await db.insertMedicationIntakeMap({
          'date': _todayDate,
          'medication_id': medId,
          'aantal_ingenomen': amount,
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
                        final medId = medicijn['id'];
                        final amount = _intakeAmounts[medId] ?? 0;
                        
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
                                    medicijn['naam'] ?? 'Onbekend',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textCharcoal),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${medicijn['dosering'] ?? ''} ${medicijn['eenheid'] ?? ''}',
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
                                      '$amount',
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
