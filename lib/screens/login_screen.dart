import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pinController = TextEditingController();
  final _db = DatabaseHelper.instance;
  final Color primaryTeal = const Color(0xFF4FB2C1);
  bool _isFirstTime = false;
  String _errorMessage = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    final pinSet = await _db.hasPinSet();
    setState(() {
      _isFirstTime = !pinSet;
      _isLoading = false;
    });
  }

  Future<void> _login() async {
    setState(() {
      _errorMessage = '';
    });

    final pin = _pinController.text.trim();

    if (pin.isEmpty) {
      setState(() {
        _errorMessage = 'Voer een PIN in';
      });
      return;
    }

    if (_isFirstTime) {
      if (pin.length < 4) {
        setState(() {
          _errorMessage = 'PIN moet minimaal 4 cijfers bevatten';
        });
        return;
      }
      await _db.updatePin(pin);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } else {
      final valid = await _db.validateLogin('gebruiker', pin);
      if (valid) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Onjuiste PIN';
        });
        _pinController.clear();
      }
    }
  }

  Future<void> _resetPin() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PIN Resetten'),
        content: const Text(
          'Weet je zeker dat je je PIN wilt resetten?\n\n'
          'Je moet daarna een nieuwe PIN instellen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () async {
              await _db.updatePin('');
              if (mounted) {
                Navigator.pop(context);
                setState(() {
                  _isFirstTime = true;
                  _errorMessage = 'PIN is gereset. Stel een nieuwe PIN in.';
                });
                _pinController.clear();
              }
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: primaryTeal,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: primaryTeal,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- LOGO ---
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 48),
                ),
              ),
              const SizedBox(height: 24),
              
              // --- TITELS ---
              const Text(
                'Ritme',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 40, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sociaal Ritme Therapie',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16, 
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              
              const SizedBox(height: 64),
              
              // --- PIN INVULVELD ---
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: _isFirstTime ? 'Kies een PIN' : 'Voer PIN in',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  counterText: '',
                ),
                onSubmitted: (_) => _login(),
              ),
              
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              
              // --- INLOGGEN KNOP ---
              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: primaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _isFirstTime ? 'Start' : 'Inloggen',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              
              if (!_isFirstTime) ...[
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: _resetPin,
                    child: Text(
                      'PIN vergeten?',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                    ),
                  ),
                ),
              ],
              
              if (_isFirstTime) ...[
                const SizedBox(height: 16),
                Text(
                  'Welkom! Kies een PIN om te beginnen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}