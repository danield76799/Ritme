import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
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
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _settings = {
          'username': prefs.getString('username') ?? '',
          'target_opstaan': prefs.getString('target_opstaan') ?? '',
          'target_slapen': prefs.getString('target_slapen') ?? '',
          'target_contact': prefs.getString('target_contact') ?? '',
          'target_werk': prefs.getString('target_werk') ?? '',
          'target_eten': prefs.getString('target_eten') ?? '',
        };
        _isLoading = false;
        _usernameController.text = _settings!['username']?.toString() ?? '';
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load settings', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Kon instellingen niet laden: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('username', _usernameController.text);
      await prefs.setString('target_opstaan', _settings?['target_opstaan'] ?? '');
      await prefs.setString('target_slapen', _settings?['target_slapen'] ?? '');
      await prefs.setString('target_contact', _settings?['target_contact'] ?? '');
      await prefs.setString('target_werk', _settings?['target_werk'] ?? '');
      await prefs.setString('target_eten', _settings?['target_eten'] ?? '');
      
      _showSuccess('Instellingen opgeslagen!');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save settings', error: e, stackTrace: stackTrace);
      _showError('Kon instellingen niet opslaan: ${e.toString()}');
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
    if (_settings?[key] != null && _settings![key].toString().isNotEmpty) {
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryTeal,
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primaryTeal, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeField(String label, String key) {
    final timeValue = _settings?[key]?.toString() ?? '';
    final displayText = timeValue.isNotEmpty ? timeValue : 'Niet ingesteld';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showTimePicker(label, key),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            suffixIcon: const Icon(Icons.access_time),
          ),
          child: Text(
            displayText,
            style: TextStyle(
              fontSize: 16,
              color: timeValue.isNotEmpty ? Colors.black87 : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}