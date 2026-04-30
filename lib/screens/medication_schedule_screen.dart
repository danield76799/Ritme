import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../service_locator.dart';

class MedicationScheduleScreen extends StatefulWidget {
  const MedicationScheduleScreen({super.key});

  @override
  State<MedicationScheduleScreen> createState() => _MedicationScheduleScreenState();
}

class _MedicationScheduleScreenState extends State<MedicationScheduleScreen> {




  List<Map<String, dynamic>> _medications = [];
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;

  // Form controllers
  final _naamController = TextEditingController();
  final _doseringController = TextEditingController();
  final _tijdController = TextEditingController(text: '21:00');
  
  // Dagen van de week
  final List<String> _dagen = ['Ma', 'Di', 'Wo', 'Do', 'Vr', 'Za', 'Zo'];
  final List<int> _selectedDagen = [1, 2, 3, 4, 5, 6, 7]; // Alle dagen standaard

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    _medications = await db.getMedicationConfigs();
    _schedules = await db.getMedicationSchedules();
    
    setState(() => _isLoading = false);
  }

  String _getDayName(int dag) {
    switch (dag) {
      case 1: return 'Ma';
      case 2: return 'Di';
      case 3: return 'Wo';
      case 4: return 'Do';
      case 5: return 'Vr';
      case 6: return 'Za';
      case 7: return 'Zo';
      default: return '';
    }
  }

  void _toggleDag(int dag) {
    setState(() {
      if (_selectedDagen.contains(dag)) {
        _selectedDagen.remove(dag);
      } else {
        _selectedDagen.add(dag);
        _selectedDagen.sort();
      }
    });
  }

  Future<void> _addMedicatie() async {
    if (_naamController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vul een naam in'), AppTheme.backgroundColor: Colors.red),
      );
      return;
    }

    await db.insertMedicationConfig(
      _naamController.text,
      _doseringController.text.isNotEmpty ? _doseringController.text : null,
      null,
    );

    _naamController.clear();
    _doseringController.clear();
    
    await _loadData();
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _addSchedule(int medicationId, String medicatieNaam) async {
    if (_selectedDagen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selecteer minimaal één dag'), AppTheme.backgroundColor: Colors.red),
      );
      return;
    }

    await db.insertMedicationSchedule(
      medicationId,
      _tijdController.text,
      _selectedDagen.join(','),
    );

    await _loadData();
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$medicatieNaam toegevoegd om ${_tijdController.text}'),
          AppTheme.backgroundColor: AppTheme.primaryTeal,
        ),
      );
    }
  }

  Future<void> _deleteSchedule(int id) async {
    await db.deleteMedicationSchedule(id);
    await _loadData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Schema verwijderd'), AppTheme.backgroundColor: Colors.orange),
      );
    }
  }

  void _showAddMedicatieDialog() {
    _naamController.clear();
    _doseringController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nieuwe Medicatie', style: TextStyle(color: AppTheme.primaryTeal)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _naamController,
              decoration: InputDecoration(
                labelText: 'Naam medicatie',
                hintText: 'Bijv. Lithium',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _doseringController,
              decoration: InputDecoration(
                labelText: 'Dosering',
                hintText: 'Bijv. 1000mg',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.text,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuleren', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: _addMedicatie,
            style: ElevatedButton.styleFrom(AppTheme.backgroundColor: AppTheme.primaryTeal),
            child: Text('Toevoegen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddScheduleDialog(int medicationId, String medicatieNaam) {
    _selectedDagen.clear();
    _selectedDagen.addAll([1, 2, 3, 4, 5, 6, 7]); // Reset naar alle dagen
    _tijdController.text = '21:00';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$medicatieNaam - Schema', style: TextStyle(color: AppTheme.primaryTeal)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tijd input
              Text('Herinneringstijd', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _tijdController,
                decoration: InputDecoration(
                  hintText: '21:00',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: Icon(Icons.access_time, color: AppTheme.primaryTeal),
                ),
                keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: 24),
              
              // Dagen selector
              Text('Dagen', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _dagen.asMap().entries.map((entry) {
                  final dagIndex = entry.key + 1;
                  final isSelected = _selectedDagen.contains(dagIndex);
                  return FilterChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    onSelected: (_) => _toggleDag(dagIndex),
                    selectedColor: primaryTeal.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.primaryTeal,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.primaryTeal : AppTheme.textCharcoal,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuleren', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => _addSchedule(medicationId, medicatieNaam),
            style: ElevatedButton.styleFrom(AppTheme.backgroundColor: AppTheme.primaryTeal),
            child: Text('Schema Toevoegen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        title: const Text(
          'Medicatie Schema',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMedicatieDialog,
        AppTheme.backgroundColor: AppTheme.primaryTeal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Medicatie Toevoegen', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : _medications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.medication_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Nog geen medicatie toegevoegd',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Druk op + om te beginnen',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _medications.length,
                  itemBuilder: (context, index) {
                    final medication = _medications[index];
                    final medicationId = medication['id'] as int;
                    final naam = medication['naam'] as String;
                    final dosering = medication['dosering'] as String?;
                    
                    // Get schedules for this medication
                    final medSchedules = _schedules
                        .where((s) => s['medication_id'] == medicationId)
                        .toList();
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: primaryTeal.withValues(alpha: 0.1),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.medication, color: AppTheme.primaryTeal, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        naam,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textCharcoal,
                                        ),
                                      ),
                                      if (dosering != null)
                                        Text(
                                          dosering,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.add_alarm, color: AppTheme.primaryTeal),
                                  onPressed: () => _showAddScheduleDialog(medicationId, naam),
                                  tooltip: 'Schema toevoegen',
                                ),
                              ],
                            ),
                          ),
                          
                          // Schedules
                          if (medSchedules.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Geen schema ingesteld. Druk op het klokje om een herinnering toe te voegen.',
                                style: TextStyle(color: Colors.grey[500], fontSize: 13),
                              ),
                            )
                          else
                            ...medSchedules.map((schedule) {
                              final reminderTime = schedule['reminder_time'] as String;
                              final daysOfWeek = schedule['days_of_week'] as String;
                              final enabled = schedule['enabled'] == 1;
                              final scheduleId = schedule['id'] as int;
                              
                              final daysList = daysOfWeek.split(',').map((d) => int.parse(d)).toList();
                              final daysText = daysList.map((d) => _getDayName(d)).join(', ');
                              
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: Colors.grey[200]!),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: enabled 
                                            ? Colors.green.withValues(alpha: 0.1) 
                                            : Colors.grey.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.access_time,
                                        color: enabled ? Colors.green : Colors.grey,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            reminderTime,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: enabled ? AppTheme.textCharcoal : Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            daysText,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                                      onPressed: () => _deleteSchedule(scheduleId),
                                      tooltip: 'Schema verwijderen',
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}


