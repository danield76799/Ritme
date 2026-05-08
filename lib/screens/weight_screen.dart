import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../service_locator.dart';
import '../utils/logger.dart';

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  List<Map<String, dynamic>> _weightLogs = [];
  bool _isLoading = true;
  String? _errorMessage;

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
      final logs = await (db as dynamic).getWeightLogs();
      setState(() {
        _weightLogs = logs;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load weight data', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Kon gewichtsgegevens niet laden.';
        _isLoading = false;
      });
    }
  }

  Future<void> _addWeightLog() async {
    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _WeightDialog(),
      );

      if (result != null) {
        await (db as dynamic).insertWeightLog(
          result['date'],
          result['weight'],
          result['notes'],
        );
        _loadData();
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to add weight log', error: e, stackTrace: stackTrace);
      _showError('Kon gewicht niet toevoegen.');
    }
  }

  Future<void> _deleteWeightLog(int id) async {
    try {
      await (db as dynamic).deleteWeightLog(id);
      _loadData();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete weight log', error: e, stackTrace: stackTrace);
      _showError('Kon gewichtslog niet verwijderen.');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Gewicht', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : _errorMessage != null
              ? _buildErrorWidget()
              : _weightLogs.isEmpty
                  ? _buildEmptyState()
                  : _buildWeightList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addWeightLog,
        backgroundColor: AppTheme.primaryTeal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Toevoegen', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Opnieuw proberen'),
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
          Icon(Icons.monitor_weight_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Geen gewichtsgegevens',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            'Tik + om je gewicht toe te voegen',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _weightLogs.length,
      itemBuilder: (context, index) {
        final log = _weightLogs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.monitor_weight, color: AppTheme.primaryTeal),
            ),
            title: Text(
              '${log['weight']} kg',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(log['date'] ?? ''),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteWeightLog(log['id']),
            ),
          ),
        );
      },
    );
  }
}

class _WeightDialog extends StatefulWidget {
  @override
  State<_WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<_WeightDialog> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gewicht toevoegen'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(labelText: 'Gewicht (kg) *'),
              keyboardType: TextInputType.number,
              validator: (value) => value?.isEmpty == true ? 'Gewicht is verplicht' : null,
            ),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notities'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuleren'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, {
                'date': DateTime.now().toIso8601String().split('T')[0],
                'weight': double.tryParse(_weightController.text) ?? 0,
                'notes': _notesController.text,
              });
            }
          },
          child: const Text('Opslaan'),
        ),
      ],
    );
  }
}
