import 'package:flutter/material.dart';
import '../database/database_helper.dart';

const Color medicalTeal = Color(0xFF4FB2C1);
const Color medicalTealDark = Color(0xFF3A9AA8);

class EventScreen extends StatefulWidget {
  const EventScreen({super.key});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  final _db = DatabaseHelper.instance;
  bool _isSaving = false;

  DateTime _selectedDate = DateTime.now();
  final _descriptionController = TextEditingController();
  final _eventTypeController = TextEditingController();
  double _impactLevel = 0;

  final _eventTypes = [
    'Positief',
    'Negatief',
    'Neutraal',
    'Stressvol',
    'Verrassend',
    'Belangrijk',
    'Routine',
  ];

  String get _formattedDate {
    return '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: medicalTeal,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Omschrijving is verplicht'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (_eventTypeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event type is verplicht'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final event = {
      'date': _formattedDate,
      'event_type': _eventTypeController.text.trim(),
      'impact_level': _impactLevel.round(),
      'description': _descriptionController.text.trim(),
      'category': null,
    };

    await _db.insertLifeEvent(event);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gebeurtenis opgeslagen!'),
          backgroundColor: medicalTeal,
        ),
      );
      Navigator.pop(context);
    }
  }

  String _impactLabel(double value) {
    if (value <= -3) return 'Zeer negatief';
    if (value <= -1) return 'Negatief';
    if (value == 0) return 'Neutraal';
    if (value <= 3) return 'Positief';
    return 'Zeer positief';
  }

  Color _impactColor(double value) {
    if (value < -1) return Colors.redAccent;
    if (value < 1) return Colors.grey;
    if (value <= 3) return Colors.lightGreen;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: medicalTeal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Life Event',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nieuwe gebeurtenis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: medicalTeal),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Datum',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ignore: deprecated_member_use
                    DropdownButtonFormField<String>(
                      value: _eventTypeController.text.isNotEmpty ? _eventTypeController.text : null, // ignore: deprecated_member_use
                      decoration: InputDecoration(
                        labelText: 'Event type *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: medicalTeal, width: 2),
                        ),
                      ),
                      items: _eventTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _eventTypeController.text = value ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Omschrijving *',
                        hintText: 'Beschrijf wat er is gebeurd...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: medicalTeal, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Impact',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_impactLabel(_impactLevel)} (${_impactLevel.round()})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _impactColor(_impactLevel),
                      ),
                    ),
                    Slider(
                      value: _impactLevel,
                      min: -4,
                      max: 4,
                      divisions: 8,
                      activeColor: _impactColor(_impactLevel),
                      inactiveColor: medicalTeal.withValues(alpha: 0.2),
                      label: _impactLevel.round().toString(),
                      onChanged: (v) => setState(() => _impactLevel = v),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('-4', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text('0', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text('+4', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Opslaan...' : 'Opslaan'),
                  style: FilledButton.styleFrom(
                    backgroundColor: medicalTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _eventTypeController.dispose();
    super.dispose();
  }
}
