import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../service_locator.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  
  final Color primaryTeal = const Color(0xFF4FB2C1);
  final Color textCharcoal = const Color(0xFF333333);
  final Color backgroundColor = const Color(0xFFF7F9FA);

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    final appointments = await db.getMedicalAppointments();
    setState(() {
      _appointments = appointments;
      _isLoading = false;
    });
  }

  Future<void> _addAppointment() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AppointmentDialog(),
    );

    if (result != null) {
      await db.insertMedicalAppointment(result);
      _loadAppointments();
    }
  }

  Future<void> _editAppointment(Map<String, dynamic> appointment) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AppointmentDialog(appointment: appointment),
    );

    if (result != null) {
      await db.updateMedicalAppointment(appointment['id'], result);
      _loadAppointments();
    }
  }

  Future<void> _deleteAppointment(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Afspraak verwijderen'),
        content: const Text('Weet je zeker dat je deze afspraak wilt verwijderen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Verwijderen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await db.deleteMedicalAppointment(id);
      _loadAppointments();
    }
  }

  List<Map<String, dynamic>> _getUpcomingAppointments() {
    final today = DateTime.now();
    return _appointments.where((apt) {
      final aptDate = DateTime.parse(apt['appointment_date']);
      return aptDate.isAfter(today) || aptDate.isAtSameMomentAs(today);
    }).toList();
  }

  List<Map<String, dynamic>> _getPastAppointments() {
    final today = DateTime.now();
    return _appointments.where((apt) {
      final aptDate = DateTime.parse(apt['appointment_date']);
      return aptDate.isBefore(today);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _getUpcomingAppointments();
    final past = _getPastAppointments();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryTeal,
        elevation: 0,
        title: const Text(
          'Medische Afspraken',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4FB2C1)))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Aankomende afspraken
                    if (upcoming.isNotEmpty) ...[
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: primaryTeal,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Aankomende afspraken',
                            style: TextStyle(
                              color: textCharcoal,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...upcoming.map((apt) => _buildAppointmentCard(apt, isUpcoming: true)),
                      const SizedBox(height: 24),
                    ],

                    // Verleden afspraken
                    if (past.isNotEmpty) ...[
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Verleden afspraken',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...past.map((apt) => _buildAppointmentCard(apt, isUpcoming: false)),
                    ],

                    if (_appointments.isEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 80),
                            Icon(Icons.calendar_today_outlined, size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 20),
                            Text(
                              'Nog geen afspraken',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Voeg je eerste medische afspraak toe',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAppointment,
        backgroundColor: primaryTeal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Afspraak toevoegen',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment, {required bool isUpcoming}) {
    final date = DateTime.parse(appointment['appointment_date']);
    final time = appointment['appointment_time']?.toString() ?? '';
    final daysUntil = date.difference(DateTime.now()).inDays;
    
    String daysText;
    if (daysUntil == 0) {
      daysText = 'Vandaag';
    } else if (daysUntil == 1) {
      daysText = 'Morgen';
    } else {
      daysText = 'Over $daysUntil dagen';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _editAppointment(appointment),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Datum indicator
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isUpcoming 
                      ? [primaryTeal, primaryTeal.withOpacity(0.8)]
                      : [Colors.grey[400]!, Colors.grey[500]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('d').format(date),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(date).toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment['title'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textCharcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (appointment['doctor_name'] != null)
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            appointment['doctor_name'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    if (appointment['location'] != null)
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            appointment['location'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isUpcoming 
                              ? primaryTeal.withOpacity(0.1)
                              : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isUpcoming ? daysText : DateFormat('d MMM yyyy').format(date),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isUpcoming ? primaryTeal : Colors.grey[600],
                            ),
                          ),
                        ),
                        if (time.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time, size: 12, color: Colors.orange[700]),
                                const SizedBox(width: 4),
                                Text(
                                  time,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Delete button
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.grey[400]),
                onPressed: () => _deleteAppointment(appointment['id']),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentDialog extends StatefulWidget {
  final Map<String, dynamic>? appointment;
  
  const _AppointmentDialog({this.appointment});

  @override
  State<_AppointmentDialog> createState() => _AppointmentDialogState();
}

class _AppointmentDialogState extends State<_AppointmentDialog> {
  final _titleController = TextEditingController();
  final _doctorController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;
  bool _reminderEnabled = true;

  @override
  void initState() {
    super.initState();
    if (widget.appointment != null) {
      _titleController.text = widget.appointment!['title'];
      _doctorController.text = widget.appointment!['doctor_name'] ?? '';
      _locationController.text = widget.appointment!['location'] ?? '';
      _notesController.text = widget.appointment!['notes'] ?? '';
      _selectedDate = DateTime.parse(widget.appointment!['appointment_date']);
      if (widget.appointment!['appointment_time'] != null) {
        final parts = widget.appointment!['appointment_time'].toString().split(':');
        _selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      _reminderEnabled = widget.appointment!['reminder_enabled'] == 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.appointment == null ? 'Afspraak toevoegen' : 'Afspraak bewerken'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Titel *',
                prefixIcon: const Icon(Icons.title),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _doctorController,
              decoration: InputDecoration(
                labelText: 'Dokter/Arts',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Locatie',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            
            // Datum picker
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Datum *',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(DateFormat('d MMMM yyyy').format(_selectedDate)),
              ),
            ),
            const SizedBox(height: 12),
            
            // Tijd picker
            InkWell(
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime ?? TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() => _selectedTime = time);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Tijd (optioneel)',
                  prefixIcon: const Icon(Icons.access_time),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_selectedTime != null 
                  ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                  : 'Selecteer tijd'),
              ),
            ),
            const SizedBox(height: 12),
            
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notities',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            
            // Reminder toggle
            SwitchListTile(
              title: const Text('Herinnering'),
              subtitle: const Text('Krijg een melding voor de afspraak'),
              value: _reminderEnabled,
              onChanged: (value) => setState(() => _reminderEnabled = value),
              activeColor: const Color(0xFF4FB2C1),
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
            if (_titleController.text.isNotEmpty) {
              Navigator.pop(context, {
                'title': _titleController.text,
                'doctor_name': _doctorController.text.isEmpty ? null : _doctorController.text,
                'location': _locationController.text.isEmpty ? null : _locationController.text,
                'appointment_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
                'appointment_time': _selectedTime != null 
                  ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                  : null,
                'notes': _notesController.text.isEmpty ? null : _notesController.text,
                'reminder_enabled': _reminderEnabled ? 1 : 0,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4FB2C1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Opslaan', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}