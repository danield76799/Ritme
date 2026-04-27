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
      backgroundColor: const Color(0xFF4FB2C1),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.fingerprint,
                        size: 60,
                        color: Color(0xFF4FB2C1),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Title
                    const Text(
                      'Ritme',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Secure Access',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    // Error Message
                    if (_errorMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_errorMessage.isNotEmpty)
                      const SizedBox(height: 24),
                    
                    // Biometric Button
                    if (_biometricAvailable)
                      ElevatedButton.icon(
                        onPressed: _biometricEnabled ? _authenticate : _enableBiometric,
                        icon: const Icon(Icons.fingerprint, size: 28),
                        label: Text(
                          _biometricEnabled 
                              ? 'Authenticate with Biometrics'
                              : 'Enable Biometric Login',
                          style: const TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF4FB2C1),
                          padding: const EdgeInsets.symmetric(
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.white,
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Biometric authentication is not available on this device.',
                              style: TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // Skip Button
                    TextButton(
                      onPressed: widget.onAuthenticated,
                      child: const Text(
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

import '../service_locator.dart';