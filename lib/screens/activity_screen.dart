import 'package:flutter/material.dart';
import '../database/database_helper.dart';

const Color medicalTeal = Color(0xFF4FB2C1);
const Color medicalTealDark = Color(0xFF3A9AA8);

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _db = DatabaseHelper.instance;
  bool _isSaving = false;

  final _activityTypes = [
    'Werk',
    'Sociaal',
    'Ontspanning',
    'Sport',
    'Huishouden',
    'Creatief',
    'Overig',
  ];

  String? _selectedType;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  double _intensity = 5;
  double _socialContact = 5;
  double _satisfaction = 5;
  final _notesController = TextEditingController();

  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  int? _calculateDuration() {
    if (_startTime == null || _endTime == null) return null;
    int startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    int endMinutes = _endTime!.hour * 60 + _endTime!.minute;
    if (endMinutes < startMinutes) endMinutes += 24 * 60;
    return endMinutes - startMinutes;
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? TimeOfDay.now())
          : (_endTime ?? TimeOfDay.now()),
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
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kies een activiteit type'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecteer start- en eindtijd'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final activity = {
      'date': _todayDate,
      'activity_type': _selectedType,
      'start_time': _formatTime(_startTime!),
      'end_time': _formatTime(_endTime!),
      'duration_minutes': _calculateDuration(),
      'intensity': _intensity.round(),
      'social_contact': _socialContact.round(),
      'satisfaction': _satisfaction.round(),
      'notes': _notesController.text.trim(),
    };

    await _db.insertActivity(activity);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activiteit opgeslagen!'),
          backgroundColor: medicalTeal,
        ),
      );
      Navigator.pop(context);
    }
  }

  Widget _buildSliderSection({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    String? label,
    Color? activeColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        if (label != null)
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: activeColor ?? medicalTeal,
            ),
          ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: activeColor ?? medicalTeal,
          inactiveColor: medicalTeal.withValues(alpha: 0.2),
          label: value.round().toString(),
          onChanged: onChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(min.toInt().toString(), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text(max.toInt().toString(), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
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
          'Activiteit Loggen',
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
                      'Nieuwe activiteit',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // ignore: deprecated_member_use
                    DropdownButtonFormField<String>(
                      value: _selectedType, // ignore: deprecated_member_use
                      decoration: InputDecoration(
                        labelText: 'Activiteit type *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: medicalTeal, width: 2),
                        ),
                      ),
                      items: _activityTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedType = value),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickTime(true),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Starttijd',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _startTime != null
                                        ? _formatTime(_startTime!)
                                        : 'Selecteer',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _startTime != null
                                          ? const Color(0xFF333333)
                                          : Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickTime(false),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Eindtijd',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _endTime != null
                                        ? _formatTime(_endTime!)
                                        : 'Selecteer',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _endTime != null
                                          ? const Color(0xFF333333)
                                          : Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_startTime != null && _endTime != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Duur: ${_calculateDuration() ?? 0} minuten',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    _buildSliderSection(
                      title: 'Intensiteit',
                      value: _intensity,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '${_intensity.round()}/10',
                      onChanged: (v) => setState(() => _intensity = v),
                    ),
                    _buildSliderSection(
                      title: 'Sociaal contact',
                      value: _socialContact,
                      min: 0,
                      max: 10,
                      divisions: 10,
                      label: '${_socialContact.round()}/10',
                      onChanged: (v) => setState(() => _socialContact = v),
                    ),
                    _buildSliderSection(
                      title: 'Tevredenheid',
                      value: _satisfaction,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '${_satisfaction.round()}/10',
                      activeColor: _satisfaction >= 7 ? Colors.green : medicalTeal,
                      onChanged: (v) => setState(() => _satisfaction = v),
                    ),
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Notities (optioneel)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: medicalTeal, width: 2),
                        ),
                      ),
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
    _notesController.dispose();
    super.dispose();
  }
}
