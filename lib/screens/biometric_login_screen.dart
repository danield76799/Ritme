import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ritme/utils/biometric_auth.dart';

class BiometricLoginScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  
  const BiometricLoginScreen({
    Key? key,
    required this.onAuthenticated,
  }) : super(key: key);

  @override
  State<BiometricLoginScreen> createState() => _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends State<BiometricLoginScreen> {
  bool _isLoading = true;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
  }

  Future<void> _checkBiometricStatus() async {
    try {
      final bool isSupported = await BiometricAuth.isDeviceSupported();
      final bool canCheck = await BiometricAuth.canCheckBiometrics();
      final bool isEnabled = await BiometricAuth.isBiometricEnabled();
      final List<BiometricType> availableBiometrics = 
          await BiometricAuth.getAvailableBiometrics();

      setState(() {
        _biometricAvailable = isSupported && canCheck;
        _biometricEnabled = isEnabled;
        _isLoading = false;
      });

      // If biometric is enabled, try to authenticate automatically
      if (_biometricEnabled && _biometricAvailable) {
        _authenticate();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking biometric status: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _authenticate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final bool didAuthenticate = await BiometricAuth.authenticate();
      
      if (didAuthenticate) {
        widget.onAuthenticated();
      } else {
        setState(() {
          _errorMessage = 'Authentication failed. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Authentication error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _enableBiometric() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bool didAuthenticate = await BiometricAuth.authenticate();
      
      if (didAuthenticate) {
        await BiometricAuth.enableBiometric();
        setState(() {
          _biometricEnabled = true;
          _isLoading = false;
        });
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric authentication enabled!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Please authenticate to enable biometric login';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error enabling biometric: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF4FB2C1),
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
            : Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.fingerprint,
                        size: 60,
                        color: Color(0xFF4FB2C1),
                      ),
                    ),
                    SizedBox(height: 32),
                    
                    // Title
                    Text(
                      'Ritme',
                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Secure Access',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: 48),
                    
                    // Error Message
                    if (_errorMessage.isNotEmpty)
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_errorMessage.isNotEmpty)
                      SizedBox(height: 24),
                    
                    // Biometric Button
                    if (_biometricAvailable)
                      ElevatedButton.icon(
                        onPressed: _biometricEnabled ? _authenticate : _enableBiometric,
                        icon: Icon(Icons.lock_outline, size: 28),
                        label: Text(
                          _biometricEnabled 
                              ? 'Authenticate with Biometrics'
                              : 'Enable Biometric Login',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Color(0xFF4FB2C1),
                          padding: EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.surface,
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Biometric authentication is not available on this device.',
                              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    
                    SizedBox(height: 24),
                    
                    // Skip Button
                    TextButton(
                      onPressed: widget.onAuthenticated,
                      child: Text(
                        'Skip for now',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}