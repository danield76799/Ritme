import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';
import '../service_locator.dart';
import '../utils/logger.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final appointments = await db.getMedicalAppointments();
      setState(() {
        _appointments = appointments;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load appointments', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Kon afspraken niet laden. Probeer opnieuw.';
        _isLoading = false;
      });
    }
  }

  Future<void> _addAppointment() async {
    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _AppointmentDialog(),
      );

      if (result != null) {
        await db.insertMedicalAppointment(result);
        _loadAppointments();
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to add appointment', error: e, stackTrace: stackTrace);
      _showError('Kon afspraak niet toevoegen.');
    }
  }

  Future<void> _editAppointment(Map<String, dynamic> appointment) async {
    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _AppointmentDialog(appointment: appointment),
      );

      if (result != null) {
        await db.updateMedicalAppointment(appointment['id'], result);
        _loadAppointments();
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to edit appointment', error: e, stackTrace: stackTrace);
      _showError('Kon afspraak niet bewerken.');
    }
  }

  Future<void> _deleteAppointment(int id) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Afspraak verwijderen?'),
          content: const Text('Deze actie kan niet ongedaan worden.'),
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
        await db.deleteMedicalAppointment(id);
        _loadAppointments();
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete appointment', error: e, stackTrace: stackTrace);
      _showError('Kon afspraak niet verwijderen.');
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
        title: const Text('Afspraken', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : _errorMessage != null
              ? _buildErrorWidget()
              : _appointments.isEmpty
                  ? _buildEmptyState()
                  : _buildAppointmentsList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAppointment,
        backgroundColor: AppTheme.primaryTeal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nieuwe afspraak', style: TextStyle(color: Colors.white)),
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
            onPressed: _loadAppointments,
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
          Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Geen afspraken',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            'Tik + om een afspraak toe te voegen',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _appointments.length,
      itemBuilder: (context, index) {
        final appointment = _appointments[index];
        return _buildAppointmentCard(appointment);
      },
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final title = appointment['title'] ?? 'Onbekend';
    final doctor = appointment['doctor_name'] ?? '';
    final location = appointment['location'] ?? '';
    final date = appointment['appointment_date'] ?? '';
    final time = appointment['appointment_time'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryTeal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.calendar_today, color: AppTheme.primaryTeal),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (doctor.isNotEmpty) Text('Dokter: $doctor'),
            if (location.isNotEmpty) Text('Locatie: $location'),
            Text('$date ${time.isNotEmpty ? 'om $time' : ''}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _editAppointment(appointment),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _deleteAppointment(appointment['id']),
            ),
          ],
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
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _doctorController;
  late TextEditingController _locationController;
  late TextEditingController _dateController;
  late TextEditingController _timeController;

  DateTime _parseDate(String dateStr) {
    try {
      return DateFormat('dd-MM-yyyy').parse(dateStr);
    } catch (e) {
      return DateTime.now();
    }
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.appointment?['title'] ?? '');
    _doctorController = TextEditingController(text: widget.appointment?['doctor_name'] ?? '');
    _locationController = TextEditingController(text: widget.appointment?['location'] ?? '');
    _dateController = TextEditingController(text: widget.appointment?['appointment_date'] ?? '');
    _timeController = TextEditingController(text: widget.appointment?['appointment_time'] ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _doctorController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.appointment == null ? 'Nieuwe afspraak' : 'Afspraak bewerken'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Titel *'),
                validator: (value) => value?.isEmpty == true ? 'Titel is verplicht' : null,
              ),
              TextFormField(
                controller: _doctorController,
                decoration: const InputDecoration(labelText: 'Dokter'),
              ),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Locatie'),
              ),
              // Date picker with DD-MM-yyyy format
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dateController.text.isNotEmpty 
                      ? _parseDate(_dateController.text) 
                      : DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() {
                      _dateController.text = DateFormat('dd-MM-yyyy').format(picked);
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Datum (DD-MM-YYYY) *',
                  ),
                  child: Text(
                    _dateController.text.isEmpty ? 'Selecteer datum' : _dateController.text,
                    style: TextStyle(
                      color: _dateController.text.isEmpty ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
              ),
              // Time picker
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _timeController.text.isNotEmpty
                      ? TimeOfDay(
                          hour: int.parse(_timeController.text.split(':')[0]),
                          minute: int.parse(_timeController.text.split(':')[1]),
                        )
                      : TimeOfDay.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _timeController.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tijd (HH:MM)',
                  ),
                  child: Text(
                    _timeController.text.isEmpty ? 'Selecteer tijd' : _timeController.text,
                    style: TextStyle(
                      color: _timeController.text.isEmpty ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuleren'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_dateController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Datum is verplicht')),
              );
              return;
            }
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, {
                'title': _titleController.text,
                'doctor_name': _doctorController.text,
                'location': _locationController.text,
                'appointment_date': _dateController.text,
                'appointment_time': _timeController.text,
              });
            }
          },
          child: const Text('Opslaan'),
        ),
      ],
    );
  }
}
