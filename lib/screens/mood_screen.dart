import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../service_locator.dart';

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  DateTime _geselecteerdeDatum = DateTime.now();
  double _stemmingWaarde = 50.0;
  int _stemmingsOmslagen = 0;
  bool _isLoading = true;
  String? _error;

  String get _formattedDate {
    return '${_geselecteerdeDatum.year}-${_geselecteerdeDatum.month.toString().padLeft(2, '0')}-${_geselecteerdeDatum.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    print('MoodScreen: initState called');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('MoodScreen: after frame');
      _loadData();
    });
  }

  Future<void> _loadData() async {
    print('MoodScreen: _loadData started');
    if (!mounted) {
      print('MoodScreen: not mounted, returning');
      return;
    }
    setState(() => _isLoading = true);

    try {
      print('MoodScreen: calling db.getDailyLog with date: $_formattedDate');
      final log = await db.getDailyLog(_formattedDate);
      print('MoodScreen: db.getDailyLog returned: $log');
      if (!mounted) return;

      if (log != null) {
        final stemming = log['stemming_ochtend'] as int?;
        if (stemming != null) {
          _stemmingWaarde = ((stemming + 5) / 10 * 100).clamp(0.0, 100.0);
        }
        final omslagen = log['stemmingsomslagen'] as int?;
        if (omslagen != null) _stemmingsOmslagen = omslagen;
      }
    } catch (e, stack) {
      print('MoodScreen: ERROR in _loadData: $e');
      print('MoodScreen: stack: $stack');
      if (mounted) setState(() => _error = e.toString());
    }

    print('MoodScreen: setting _isLoading = false');
    if (mounted) setState(() => _isLoading = false);
    print('MoodScreen: _loadData completed');
  }

  String _getStemmingLabel(double waarde) {
    if (waarde <= 10) return 'Uiterst depressief';
    if (waarde <= 25) return 'Depressief';
    if (waarde <= 40) return 'Neerslachtig';
    if (waarde <= 60) return 'Neutraal';
    if (waarde <= 75) return 'Opgewekt';
    if (waarde <= 90) return 'Manisch';
    return 'Uiterst manisch';
  }

  Color _getStemmingKleur(double waarde) {
    if (waarde <= 10) return Colors.grey[700]!;
    if (waarde <= 25) return Colors.grey[500]!;
    if (waarde <= 40) return Colors.blue[300]!;
    if (waarde <= 60) return Colors.green[400]!;
    if (waarde <= 75) return Colors.orange[400]!;
    if (waarde <= 90) return Colors.orange[700]!;
    return Colors.red[400]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Stemming', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: AppTheme.primaryTeal,
      ),
      body: _error != null
          ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
          : _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Date display
          Text(
            DateFormat('EEEE d MMMM', 'nl_NL').format(_geselecteerdeDatum),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          // Mood value
          Text(
            _stemmingWaarde.round().toString(),
            style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: _getStemmingKleur(_stemmingWaarde)),
          ),
          Text(
            _getStemmingLabel(_stemmingWaarde),
            style: TextStyle(fontSize: 20, color: _getStemmingKleur(_stemmingWaarde)),
          ),
          const SizedBox(height: 24),
          // Slider
          Slider(
            value: _stemmingWaarde,
            min: 0,
            max: 100,
            activeColor: _getStemmingKleur(_stemmingWaarde),
            onChanged: (v) => setState(() => _stemmingWaarde = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('😞', style: TextStyle(fontSize: 24)),
              Text('😄', style: TextStyle(fontSize: 24)),
            ],
          ),
          const SizedBox(height: 32),
          // Mood swings
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Stemmingsomslagen: ', style: TextStyle(fontSize: 16)),
              Text('$_stemmingsOmslagen', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 32),
                onPressed: _stemmingsOmslagen > 0 ? () => setState(() => _stemmingsOmslagen--) : null,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 32),
                onPressed: () => setState(() => _stemmingsOmslagen++),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Save button
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal, foregroundColor: Colors.white),
            onPressed: () async {
              final stemming = ((_stemmingWaarde / 100) * 10 - 5).round();
              try {
                await db.upsertDailyLog({
                  'date': _formattedDate,
                  'stemming_ochtend': stemming,
                  'stemmingsomslagen': _stemmingsOmslagen,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opgeslagen!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Fout: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );
  }
}