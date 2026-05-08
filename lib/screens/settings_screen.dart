import 'package:flutter/material.dart';
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
      final settings = await db.getSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
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
        await db.updateSettingsMap(_settings!);
        _showSuccess('Instellingen opgeslagen!');
      }
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

  Widget _buildTimeField(String label, String key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        initialValue: _settings?[key]?.toString() ?? '',
        onChanged: (value) {
          setState(() {
            _settings ??= {};
            _settings![key] = value;
          });
        },
      ),
    );
  }
}
