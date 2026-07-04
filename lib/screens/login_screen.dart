import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import '../service_locator.dart';
import '../utils/logger.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pinController = TextEditingController();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  bool _isFirstTime = false;
  String _errorMessage = '';
  bool _isLoading = true;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    try {
      final pinSet = await db.hasPinSet();
      
      // Check biometrie (alleen op mobile)
      if (!kIsWeb) {
        try {
          final canCheckBiometrics = await _localAuth.canCheckBiometrics;
          final isDeviceSupported = await _localAuth.isDeviceSupported();
          
          _biometricAvailable = canCheckBiometrics || isDeviceSupported;
          
          if (_biometricAvailable) {
            final biometricEnabled = await _secureStorage.read(key: 'biometric_enabled');
            _biometricEnabled = biometricEnabled == 'true';
          }
        } on PlatformException catch (e) {
          AppLogger.warning('Biometric check error', error: e);
        }
      }
      
      setState(() {
        _isFirstTime = !pinSet;
        _isLoading = false;
      });
      
      // Probeer biometrische login als beschikbaar (alleen als er al een PIN is ingesteld).
      // Wacht tot de eerste frame is gerenderd zodat de native prompt betrouwbaar opent.
      if (!kIsWeb && _biometricEnabled && _biometricAvailable && pinSet) {
        AppLogger.info('Triggering biometric login: enabled=$biometricEnabled, available=$biometricAvailable, pinSet=$pinSet');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _authenticateWithBiometrics();
        });
      } else {
        AppLogger.info('Skipping biometric login: enabled=$biometricEnabled, available=$biometricAvailable, pinSet=$pinSet, kIsWeb=$kIsWeb');
      }
    } catch (e) {
      AppLogger.error('Failed to check setup', error: e);
      setState(() {
        _errorMessage = 'Kon app niet initialiseren. Probeer opnieuw.';
        _isLoading = false;
      });
    }
  }

  Future<bool> _authenticateWithBiometrics() async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticateer om Ritme te openen',
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Biometrische login',
            cancelButton: 'Annuleer',
            biometricHint: 'Verifieer je identiteit',
            biometricNotRecognized: 'Niet herkend, probeer opnieuw',
            biometricRequiredTitle: 'Biometrische authenticatie vereist',
            biometricSuccess: 'Authenticatie geslaagd',
            deviceCredentialsRequiredTitle: 'Apparaatcode vereist',
            deviceCredentialsSetupDescription: 'Stel eerst een schermvergrendeling in',
            goToSettingsButton: 'Naar Instellingen',
            goToSettingsDescription: 'Stel biometrische authenticatie in via je apparaatinstellingen',
          ),
          IOSAuthMessages(
            cancelButton: 'Annuleer',
            goToSettingsButton: 'Naar Instellingen',
            goToSettingsDescription: 'Stel Face ID / Touch ID in via je apparaatinstellingen',
            lockOut: 'Schakel biometrische authenticatie opnieuw in',
          ),
        ],
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (didAuthenticate && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
      return didAuthenticate;
    } on PlatformException catch (e, stackTrace) {
      AppLogger.error('Biometric auth error', error: e, stackTrace: stackTrace);
      return false;
    }
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

    try {
      if (_isFirstTime) {
        if (pin.length < 4) {
          setState(() {
            _errorMessage = 'PIN moet minimaal 4 cijfers bevatten';
          });
          return;
        }
        await db.updatePin(pin);
        
        // Vraag of biometrie ingeschakeld moet worden
        if (!kIsWeb && _biometricAvailable) {
          _showEnableBiometricDialog();
          return;
        }
        
        // Als geen biometrie, vraag om notificaties
        _showNotificationDialog();
        return;
      }

      final isValid = await db.validateLoginPin(pin);
      if (isValid != null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Ongeldige PIN';
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Login error', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Inloggen mislukt. Probeer opnieuw.';
      });
    }
  }

  void _showEnableBiometricDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Biometrische Authenticatie'),
        content: const Text(
          'Wil je biometrische authenticatie (vingerafdruk/gezichtsherkenning) inschakelen voor snellere toegang?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showNotificationDialog();
            },
            child: Text('Nee, bedankt'),
          ),
          ElevatedButton(
            onPressed: () async {
              final bool didAuthenticate = await _authenticateWithBiometrics();
              if (didAuthenticate) {
                await _secureStorage.write(key: 'biometric_enabled', value: 'true');
                if (mounted) {
                  Navigator.pop(context);
                  _showNotificationDialog();
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
            child: Text('Ja, inschakelen', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      ),
    );
  }

  void _showNotificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Notificaties'),
        content: const Text(
          'Wil je notificaties ontvangen voor herinneringen en updates?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              );
            },
            child: const Text('Nee, bedankt'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Request notification permission
              final status = await Permission.notification.request();
              if (mounted) {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => DashboardScreen()),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
            child: Text('Ja, inschakelen', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      ),
    );
  }

  void _showForgotPinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('PIN Vergeten?'),
          ],
        ),
        content: const Text(
          'Omdat uw medische gegevens veilig en lokaal op uw eigen telefoon worden opgeslagen, kunnen wij uw PIN helaas niet voor u herstellen.\n\n'
          'Als u uw PIN echt niet meer weet, is de enige optie om de app volledig te resetten. Hierbij gaan al uw eerdere invoeren verloren.\n\n'
          'Weet u zeker dat u wilt doorgaan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showResetConfirmationDialog();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('App Resetten'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Laatste Waarschuwing'),
        content: const Text(
          'DIT KAN NIET ONGEDAAN WORDEN!\n\n'
          'Alle uw data zal worden verwijderd:\n'
          '• Dagelijkse logs\n'
          '• Medicatie inname\n'
          '• Activiteiten\n'
          '• Instellingen\n\n'
          'Weet u ABSOLUUT zeker dat u wilt doorgaan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Nee, annuleren'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _resetApp();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Ja, reset alles', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      ),
    );
  }

  Future<void> _resetApp() async {
    try {
      await _secureStorage.delete(key: 'biometric_enabled');
      await _secureStorage.delete(key: 'password_hash');
      await db.clearAllData();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App is gereset. Start opnieuw.'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isFirstTime = true;
          _pinController.clear();
          _errorMessage = '';
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('App reset error', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij resetten: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? Container(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite, size: 64, color: AppTheme.primaryTeal),
                    SizedBox(height: 16),
                    Text('Laden...', style: TextStyle(fontSize: 18, color: AppTheme.primaryTeal)),
                  ],
                ),
              ),
            )
          : SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/logo.jpg',
                          width: 120,
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Ritme',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTeal,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _isFirstTime
                            ? 'Stel een PIN in om te beginnen'
                            : 'Voer je PIN in',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      SizedBox(height: 32),
                      
                      // Biometrische login knop (alleen op mobile)
                      if (!kIsWeb && _biometricAvailable && _biometricEnabled && !_isFirstTime)
                        Column(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _authenticateWithBiometrics,
                              icon: Icon(Icons.lock_outline, size: 28),
                              label: Text(
                                'Login met Biometrie',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppTheme.primaryTeal,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: AppTheme.primaryTeal),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'of',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      
                      Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          children: [
                            TextField(
                              controller: _pinController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 6,
                              decoration: InputDecoration(
                                labelText: 'PIN',
                                hintText: _isFirstTime
                                    ? 'Minimaal 4 cijfers'
                                    : 'Voer je PIN in',
                                prefixIcon: const Icon(Icons.pin),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppTheme.primaryTeal,
                                    width: 2,
                                  ),
                                ),
                              ),
                              onSubmitted: (_) => _login(),
                            ),
                            const SizedBox(height: 16),
                            if (_errorMessage.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline,
                                        color: Colors.red[700], size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage,
                                        style:
                                            TextStyle(color: Colors.red[700]),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _login,
                                child: Text(
                                  _isFirstTime ? 'PIN Instellen' : 'Inloggen',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            
                            // PIN vergeten knop (alleen bij bestaande PIN)
                            if (!_isFirstTime)
                              Padding(
                                padding: EdgeInsets.only(top: 16),
                                child: TextButton(
                                  onPressed: _showForgotPinDialog,
                                  child: Text(
                                    'PIN Vergeten?',
                                    style: TextStyle(
                                      color: Theme.of(context).textTheme.bodyMedium?.color,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
