import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../service_locator.dart';
import '../widgets/datum_navigator.dart';

class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  final Color primaryTeal = const Color(0xFF4FB2C1);
  final Color textCharcoal = const Color(0xFF333333);
  final Color backgroundColor = const Color(0xFFFAFAFA);

  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _configs = [];
  Map<int, int> _intakesForDay = {}; // configId -> count
  bool _isLoading = true;

  String get _formattedDate {
    return DateFormat('yyyy-MM-dd').format(_selectedDate);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final configs = await db.getMedicationConfigs();
    final intakes = await db.getMedicationIntake(_formattedDate);

    Map<int, int> intakeMap = {};
    for (var intake in intakes) {
      intakeMap[intake['medication_id']] = intake['aantal_ingenomen'];
    }

    setState(() {
      _configs = configs;
      _intakesForDay = intakeMap;
      _isLoading = false;
    });
  }

  void _onDatumVeranderd(DateTime nieuweDatum) {
    setState(() {
      _selectedDate = nieuweDatum;
    });
    _loadData();
  }

  // --- DATABASE ACTIES ---

  Future<void> _addMedication(String name, double dosage, String unit) async {
    await db.insertMedicationConfig(name, dosage.toString(), unit);
    _loadData();
  }

  Future<void> _updateIntake(int configId, int change) async {
    int current = _intakesForDay[configId] ?? 0;
    int newVal = current + change;
    if (newVal < 0) return;

    await db.insertMedicationIntakeMap({
      'medication_id': configId,
      'date': _formattedDate,
      'aantal_ingenomen': newVal,
    });
    _loadData();
  }

  // --- UI DIALOG ---

  void _showAddMedicationDialog() {
    String name = '';
    double dosage = 0;
    String unit = 'mg';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nieuwe Medicatie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Naam (bijv. Lithium)'),
              onChanged: (v) => name = v,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Dosering'),
              keyboardType: TextInputType.number,
              onChanged: (v) => dosage = double.tryParse(v) ?? 0,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Eenheid (mg, ml, stuks)'),
              onChanged: (v) => unit = v,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleer'),
          ),
          ElevatedButton(
            onPressed: () {
              if (name.isNotEmpty) _addMedication(name, dosage, unit);
              Navigator.pop(context);
            },
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Medicatie Logboek',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryTeal,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Datum Navigator
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: DatumNavigator(
              geselecteerdeDatum: _selectedDate,
              onDatumVeranderd: _onDatumVeranderd,
            ),
          ),
          
          // Content
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: primaryTeal),
                  )
                : _configs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.medication_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Nog geen medicatie toegevoegd.\nKlik op de + om te beginnen.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _configs.length,
                        itemBuilder: (context, i) => _buildMedCard(_configs[i]),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMedicationDialog,
        backgroundColor: primaryTeal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMedCard(Map<String, dynamic> config) {
    int configId = config['id'];
    int count = _intakesForDay[configId] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          config['naam'] ?? 'Onbekend',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textCharcoal),
        ),
        subtitle: Text(
          '${config['dosering'] ?? ''} ${config['eenheid'] ?? ''}',
          style: TextStyle(fontSize: 14, color: primaryTeal),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
              onPressed: () => _updateIntake(configId, -1),
            ),
            Container(
              width: 30,
              alignment: Alignment.center,
              child: Text(
                '$count',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textCharcoal),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle, color: primaryTeal),
              onPressed: () => _updateIntake(configId, 1),
            ),
          ],
        ),
      ),
    );
  }
}
