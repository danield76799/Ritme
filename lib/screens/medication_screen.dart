import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';
import '../service_locator.dart';
import '../widgets/datum_navigator.dart';
import '../utils/logger.dart';

class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {

  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _configs = [];
  Map<int, int> _intakesForDay = {};
  bool _isLoading = true;
  String? _errorMessage;

  String get _formattedDate {
    return DateFormat('yyyy-MM-dd').format(_selectedDate);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
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
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load medication data', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Kon medicatiegegevens niet laden. Probeer opnieuw.';
        _isLoading = false;
      });
    }
  }

  void _onDatumVeranderd(DateTime nieuweDatum) {
    setState(() => _selectedDate = nieuweDatum);
    _loadData();
  }

  Future<void> _addMedication(String name, double dosage, String unit) async {
    try {
      await db.insertMedicationConfig(name, dosage.toString(), unit);
      _loadData();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to add medication', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kon medicatie niet toevoegen. Probeer opnieuw.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _updateIntake(int configId, int change) async {
    try {
      int current = _intakesForDay[configId] ?? 0;
      int newVal = current + change;
      if (newVal < 0) return;

      await db.insertMedicationIntakeMap({
        'medication_id': configId,
        'date': _formattedDate,
        'aantal_ingenomen': newVal,
      });
      _loadData();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update medication intake', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kon inname niet bijwerken. Probeer opnieuw.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _deleteMedication(int configId) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Medicatie verwijderen?'),
          content: const Text('Deze actie kan niet ongedaan worden. Alle innamegegevens voor deze medicatie worden ook verwijderd.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuleren'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Verwijderen', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await db.deleteMedicationConfig(configId);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Medicatie verwijderd'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete medication', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kon medicatie niet verwijderen. Probeer opnieuw.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Medicatie',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddMedicationDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: DatumNavigator(
              geselecteerdeDatum: _selectedDate,
              onDatumVeranderd: _onDatumVeranderd,
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
                : _errorMessage != null
                    ? _buildErrorState()
                    : _configs.isEmpty
                        ? _buildEmptyState()
                        : _buildMedList(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: TextStyle(fontSize: 16, color: Colors.red[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Opnieuw proberen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medication_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Geen medicatie',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            'Tik + om toe te voegen',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildMedList() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _configs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _buildCompactMedCard(_configs[i]),
    );
  }

  Widget _buildCompactMedCard(Map<String, dynamic> config) {
    // Handle both int and String ids from Hive
    dynamic rawId = config['id'];
    int? configId;
    if (rawId is int) {
      configId = rawId;
    } else if (rawId is String) {
      configId = int.tryParse(rawId);
    }
    if (configId == null) {
      print('Skipping invalid medication entry: $config');
      return const SizedBox.shrink(); // Skip invalid entries
    }
    int count = _intakesForDay[configId] ?? 0;
    String name = config['naam']?.toString() ?? 'Onbekend';
    String dosage = '${config['dosering']?.toString() ?? ''} ${config['eenheid']?.toString() ?? ''}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.medication, color: AppTheme.primaryTeal, size: 24),
          ),
          // Name & dosage
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textCharcoal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dosage,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
          // Counter
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCounterBtn(
                icon: Icons.remove,
                onPressed: count > 0 ? () => _updateIntake(configId!, -1) : null,
              ),
              Container(
                width: 36,
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textCharcoal,
                  ),
                ),
              ),
              _buildCounterBtn(
                icon: Icons.add,
                onPressed: () => _updateIntake(configId!, 1),
                isPrimary: true,
              ),
              const SizedBox(width: 8),
              _buildDeleteBtn(
                onPressed: () => _deleteMedication(configId!),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildCounterBtn({
    required IconData icon,
    required VoidCallback? onPressed,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isPrimary ? AppTheme.primaryTeal : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isPrimary ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteBtn({
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.delete_outline,
            size: 18,
            color: Colors.red[400],
          ),
        ),
      ),
    );
  }
}
