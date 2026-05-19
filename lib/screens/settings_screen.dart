import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../utils/app_theme.dart';
import '../service_locator.dart';
import '../utils/logger.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _settings;
  bool _isLoading = true;
  String? _errorMessage;

  // Controllers for text fields
  final _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final settings = await db.getSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
        // Update controllers with loaded values
        _usernameController.text = settings?['username']?.toString() ?? '';
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load settings', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Kon instellingen niet laden.';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      if (_settings != null) {
        // Update username from controller
        _settings!['username'] = _usernameController.text;
        await db.updateSettingsMap(_settings!);
      } else {
        // No existing settings, create new map
        final newSettings = {'username': _usernameController.text};
        await db.updateSettingsMap(newSettings);
      }
      _showSuccess('Instellingen opgeslagen!');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save settings', error: e, stackTrace: stackTrace);
      _showError('Kon instellingen niet opslaan.');
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
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

  Future<void> _showTimePicker(String label, String key) async {
    // Parse current time or use default
    TimeOfDay currentTime;
    if (_settings?[key] != null) {
      final parts = _settings![key].toString().split(':');
      if (parts.length >= 2) {
        currentTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 8,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      } else {
        currentTime = const TimeOfDay(hour: 8, minute: 0);
      }
    } else {
      currentTime = const TimeOfDay(hour: 8, minute: 0);
    }

    final Duration initialDuration = Duration(hours: currentTime.hour, minutes: currentTime.minute);
    Duration selectedDuration = initialDuration;

    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          color: Colors.white,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuleer'),
                    ),
                    Text(
                      label,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    TextButton(
                      onPressed: () {
                        // Save the selected time
                        final hours = selectedDuration.inHours;
                        final minutes = selectedDuration.inMinutes % 60;
                        final timeString = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
                        setState(() {
                          _settings ??= {};
                          _settings![key] = timeString;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Klaar'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hm,
                  minuteInterval: 15,
                  initialTimerDuration: initialDuration,
                  onTimerDurationChanged: (Duration newDuration) {
                    selectedDuration = newDuration;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Instellingen', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : _errorMessage != null
              ? _buildErrorWidget()
              : _buildSettingsForm(),
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

  Widget _buildSettingsForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Profiel'),
          _buildTextField('Gebruikersnaam', _usernameController),
          const SizedBox(height: 24),
          _buildSectionHeader('Slaapschema'),
          _buildTimeField('Opstaan', 'target_opstaan'),
          _buildTimeField('Slapen', 'target_slapen'),
          const SizedBox(height: 24),
          _buildSectionHeader('Dagelijkse Doelen'),
          _buildTimeField('Eerste contact', 'target_contact'),
          _buildTimeField('Werk / Hobby', 'target_werk'),
          _buildTimeField('Avondeten', 'target_eten'),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Opslaan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.textCharcoal,
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildTimeField(String label, String key) {
    final displayValue = _settings?[key]?.toString() ?? '--:--';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showTimePicker(label, key),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              Row(
                children: [
                  Text(
                    displayValue,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.access_time, color: Colors.grey[600]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}