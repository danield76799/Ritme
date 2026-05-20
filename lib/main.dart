import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ==========================================
// Ritme App - NEW BUILD
// ==========================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  runApp(const RitmeApp());
}

class RitmeApp extends StatelessWidget {
  const RitmeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ritme',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4FB2C1)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// ==========================================
// HOME PAGE (Dashboard)
// ==========================================
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ritme'),
        backgroundColor: const Color(0xFF4FB2C1),
        foregroundColor: Colors.white,
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard(context, Icons.mood, 'Stemming', '/mood'),
          _buildCard(context, Icons.fitness_center, 'Activiteiten', '/activity'),
          _buildCard(context, Icons.medication, 'Medicatie', '/medication'),
          _buildCard(context, Icons.settings, 'Instellingen', '/settings'),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, IconData icon, String title, String route) {
    return Card(
      child: InkWell(
        onTap: () {
          if (route == '/mood') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const StemmingPage()));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title komt binnenkort')),
            );
          }
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: const Color(0xFF4FB2C1)),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// STEMMING PAGE
// ==========================================
class StemmingPage extends StatefulWidget {
  const StemmingPage({super.key});

  @override
  State<StemmingPage> createState() => _StemmingPageState();
}

class _StemmingPageState extends State<StemmingPage> {
  double _stemming = 50.0;
  int _stemmingsOmslagen = 0;
  bool _isLoading = false;
  String _status = '';

  String _getStemmingLabel() {
    if (_stemming <= 10) return 'Uiterst depressief';
    if (_stemming <= 25) return 'Depressief';
    if (_stemming <= 40) return 'Neerslachtig';
    if (_stemming <= 60) return 'Neutraal';
    if (_stemming <= 75) return 'Opgewekt';
    if (_stemming <= 90) return 'Manisch';
    return 'Uiterst manisch';
  }

  Color _getStemmingColor() {
    if (_stemming <= 10) return Colors.grey[700]!;
    if (_stemming <= 25) return Colors.grey[500]!;
    if (_stemming <= 40) return Colors.blue[300]!;
    if (_stemming <= 60) return Colors.green[400]!;
    if (_stemming <= 75) return Colors.orange[400]!;
    if (_stemming <= 90) return Colors.orange[700]!;
    return Colors.red[400]!;
  }

  void _save() async {
    setState(() {
      _isLoading = true;
      _status = 'Opslaan...';
    });

    // Save to Hive
    try {
      final box = Hive.box('daily_logs');
      final today = DateTime.now().toIso8601String().split('T')[0];
      final stemmed = ((_stemming / 100) * 10 - 5).round();
      
      await box.put(today, {
        'date': today,
        'stemming_ochtend': stemmed,
        'stemmingsomslagen': _stemmingsOmslagen,
      });

      setState(() {
        _isLoading = false;
        _status = 'Opgeslagen! ✅';
      });

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _status = '');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Fout: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stemming'),
        backgroundColor: const Color(0xFF4FB2C1),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: const Text('Opslaan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Mood display
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _getStemmingColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    _stemming.round().toString(),
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: _getStemmingColor(),
                    ),
                  ),
                  Text(
                    _getStemmingLabel(),
                    style: TextStyle(
                      fontSize: 18,
                      color: _getStemmingColor(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _getStemmingColor(),
                thumbColor: _getStemmingColor(),
              ),
              child: Slider(
                value: _stemming,
                min: 0,
                max: 100,
                onChanged: (v) => setState(() => _stemming = v),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('😞 Depressief', style: TextStyle(color: Colors.grey[600])),
                Text('Manisch 😄', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 32),

            // Mood swings
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Stemmingsomslagen: ', style: TextStyle(fontSize: 16)),
                  Text(
                    '$_stemmingsOmslagen',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () => setState(() => _stemmingsOmslagen--),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _stemmingsOmslagen++),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Status
            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _status.contains('Fout') ? Colors.red[100] : Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_status),
              ),
          ],
        ),
      ),
    );
  }
}