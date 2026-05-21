import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';
import '../service_locator.dart';
import '../utils/logger.dart';
import '../services/notification_helper.dart';

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
        print('Adding appointment: $result');
        final id = await db.insertMedicalAppointment(result);
        print('Appointment added with id: $id');
        
        // Schedule notification if reminder is set
        final reminderDays = result['reminder_days'] ?? 0;
        if (reminderDays > 0) {
          await NotificationHelper.instance.scheduleAppointmentReminder(
            appointmentId: id,
            title: result['title'] ?? '',
            doctorName: result['doctor_name'] ?? '',
            appointmentDate: result['appointment_date'] ?? '',
            appointmentTime: result['appointment_time'] ?? '',
            reminderDays: reminderDays,
          );
        }
        
        _loadAppointments();
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to add appointment', error: e, stackTrace: stackTrace);
      _showError('Kon afspraak niet toevoegen: $e');
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
        
        // Reschedule notification
        final reminderDays = result['reminder_days'] ?? 0;
        await NotificationHelper.instance.cancelAppointmentReminder(appointment['id']);
        if (reminderDays > 0) {
          await NotificationHelper.instance.scheduleAppointmentReminder(
            appointmentId: appointment['id'],
            title: result['title'] ?? '',
            doctorName: result['doctor_name'] ?? '',
            appointmentDate: result['appointment_date'] ?? '',
            appointmentTime: result['appointment_time'] ?? '',
            reminderDays: reminderDays,
          );
        }
        
        _loadAppointments();
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to edit appointment', error: e, stackTrace: stackTrace);
      _showError('Kon afspraak niet bewerken.');
    }
  }

  Future<void> _showDeleteConfirmation(int id) async {
    debugPrint('=== SHOW DELETE CONFIRMATION ===');
    debugPrint('ID to delete: $id');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Delete tapped voor ID $id'), duration: const Duration(seconds: 2)),
    );
    
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
      await _performDelete(id);
    }
  }

  Future<void> _performDelete(int id) async {
    debugPrint('=== PERFORM DELETE ===');
    debugPrint('ID: $id');
    try {
      // Cancel any scheduled notification
      await NotificationHelper.instance.cancelAppointmentReminder(id);
      
      // Delete from database
      await db.deleteMedicalAppointment(id);
      
      // Reload appointments and check remaining notifications
      _loadAppointments();
      
      // Show confirmation
      if (mounted) {
        final pending = await NotificationHelper.instance.getPendingNotificationCount();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Afspraak verwijderd. Nog $pending notificaties pending.')),
        );
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
      color: Colors.white,
      child: Row(
        children: [
          // Left side - tappable info area
          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              onTap: () => _editAppointment(appointment),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.calendar_today, color: AppTheme.primaryTeal),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          if (doctor.isNotEmpty) Text('Dokter: $doctor', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          if (location.isNotEmpty) Text('Locatie: $location', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          Text('$date ${time.isNotEmpty ? 'om $time' : ''}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Right side - action buttons (in their own mini-column)
          Container(
            color: Colors.grey[50],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _editAppointment(appointment),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: const Icon(Icons.edit, size: 24, color: Colors.blue),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      debugPrint('Delete icon tapped for appointment ${appointment['id']}');
                      _showDeleteConfirmation(appointment['id']);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: const Icon(Icons.delete, size: 24, color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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

  int _reminderDays = 0; // 0 = none, 1 = 1 day, 3 = 3 days, 7 = 7 days

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.appointment?['title'] ?? '');
    _doctorController = TextEditingController(text: widget.appointment?['doctor_name'] ?? '');
    _locationController = TextEditingController(text: widget.appointment?['location'] ?? '');
    _dateController = TextEditingController(text: widget.appointment?['appointment_date'] ?? '');
    _timeController = TextEditingController(text: widget.appointment?['appointment_time'] ?? '');
    _reminderDays = widget.appointment?['reminder_days'] ?? 0;
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
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            brightness: Brightness.light,
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryTeal,
              surface: Colors.white,
            ),
          ),
          child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.appointment == null ? 'Nieuwe afspraak' : 'Afspraak bewerken',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTextField('Titel *', _titleController, validator: (value) => value?.isEmpty == true ? 'Titel is verplicht' : null),
                        const SizedBox(height: 16),
                        _buildTextField('Dokter', _doctorController),
                        const SizedBox(height: 16),
                        _buildTextField('Locatie', _locationController),
                        const SizedBox(height: 16),
                        _buildDateField(),
                        const SizedBox(height: 16),
                        _buildTimeField(),
                        const SizedBox(height: 16),
                        _buildReminderDropdown(),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuleren', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        Navigator.pop(context, {
                          'title': _titleController.text,
                          'doctor_name': _doctorController.text,
                          'location': _locationController.text,
                          'appointment_date': _dateController.text,
                          'appointment_time': _timeController.text,
                          'reminder_days': _reminderDays,
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Opslaan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        validator: validator,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primaryTeal, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return FormField<String>(
      initialValue: _dateController.text,
      validator: (value) => value?.isEmpty == true ? 'Datum is verplicht' : null,
      builder: (field) => InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _dateController.text.isNotEmpty 
              ? _parseDate(_dateController.text) 
              : DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: AppTheme.primaryTeal,
                    surface: Colors.white,
                  ),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            setState(() {
              _dateController.text = DateFormat('dd-MM-yyyy').format(picked);
              field.didChange(_dateController.text);
            });
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: field.errorText != null ? Colors.red : Colors.grey[400]!),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Datum (DD-MM-YYYY) *',
                    style: TextStyle(
                      color: field.errorText != null ? Colors.red : Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _dateController.text.isEmpty ? 'Selecteer datum' : _dateController.text,
                    style: TextStyle(
                      color: _dateController.text.isEmpty ? Colors.grey[400] : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Icon(Icons.calendar_today, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeField() {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _timeController.text.isNotEmpty
            ? TimeOfDay(
                hour: int.tryParse(_timeController.text.split(':')[0]) ?? 9,
                minute: int.tryParse(_timeController.text.split(':')[1]) ?? 0,
              )
            : const TimeOfDay(hour: 9, minute: 0),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: AppTheme.primaryTeal,
                  surface: Colors.white,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() {
            _timeController.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[400]!),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tijd',
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  _timeController.text.isEmpty ? 'Selecteer tijd' : _timeController.text,
                  style: TextStyle(
                    color: _timeController.text.isEmpty ? Colors.grey[400] : Colors.black,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            Icon(Icons.access_time, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFCCCCCC)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Herinnering',
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                _reminderDays == 0 ? 'Geen herinnering' :
                _reminderDays == 1 ? '1 dag van tevoren' :
                _reminderDays == 3 ? '3 dagen van tevoren' :
                '7 dagen van tevoren',
                style: TextStyle(
                  color: _reminderDays == 0 ? Colors.grey[400] : Colors.black,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          DropdownButton<int>(
            value: _reminderDays,
            underline: SizedBox(),
            items: [
              DropdownMenuItem(value: 0, child: Text('Geen')),
              DropdownMenuItem(value: 1, child: Text('1 dag')),
              DropdownMenuItem(value: 3, child: Text('3 dagen')),
              DropdownMenuItem(value: 7, child: Text('7 dagen')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _reminderDays = value);
              }
            },
          ),
        ],
      ),
    );
  }
}
