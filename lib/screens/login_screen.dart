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
import '../generated/l10n/app_localizations.dart';

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
            if (!_biometricEnabled) {
              // Fallback: controleer ook de database. De secure storage kan leeg
              // zijn na een herinstallatie terwijl de gebruiker biometrie eerder
              // wél had ingeschakeld.
              try {
                final settings = await db.getSettings();
                final stored = settings?['biometric_enabled']?.toString();
                _biometricEnabled = stored == '1' || stored == 'true';
                if (_biometricEnabled) {
                  // Herstel de secure storage zodat de app meteen kan inloggen.
                  await _secureStorage.write(key: 'biometric_enabled', value: 'true');
                }
              } catch (_) {
                // DB-lees is optioneel, fallback naar false.
              }
            }
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
        AppLogger.info('Triggering biometric login: enabled=$_biometricEnabled, available=$_biometricAvailable, pinSet=$pinSet');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _authenticateWithBiometrics();
        });
      } else {
        AppLogger.info('Skipping biometric login: enabled=$_biometricEnabled, available=$_biometricAvailable, pinSet=$pinSet, kIsWeb=$kIsWeb');
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
        localizedReason: AppLocalizations.of(context).authenticateerOmRitme,
        authMessages: [
          AndroidAuthMessages(
            signInTitle: AppLocalizations.of(context).biometrischeLogin,
            cancelButton: AppLocalizations.of(context).annuleer,
            biometricHint: AppLocalizations.of(context).verifieerJeIdentiteit,
            biometricNotRecognized: AppLocalizations.of(context).nietHerkend,
            biometricRequiredTitle: AppLocalizations.of(context).biometrischeAuthVereist,
            biometricSuccess: AppLocalizations.of(context).authenticatieGeslaagd,
            deviceCredentialsRequiredTitle: AppLocalizations.of(context).apparaatcodeVereist,
            deviceCredentialsSetupDescription: AppLocalizations.of(context).stelSchermvergrendelingIn,
            goToSettingsButton: AppLocalizations.of(context).naarInstellingen,
            goToSettingsDescription: AppLocalizations.of(context).stelBiometrieInViaApparaat,
          ),
          IOSAuthMessages(
            cancelButton: AppLocalizations.of(context).annuleer,
            goToSettingsButton: AppLocalizations.of(context).naarInstellingen,
            goToSettingsDescription: AppLocalizations.of(context).stelFaceIdTouchIdIn,
            lockOut: AppLocalizations.of(context).schakelBiometrieOpnieuwIn,
          ),
        ],
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (didAuthenticate && mounted) {
        // Zorg dat er altijd een PIN bestaat voordat we verdergaan. Anders
        // zou biometrie de PIN volledig kunnen omzeilen.
        final pinSet = await db.hasPinSet();
        if (!pinSet) {
          setState(() => _isFirstTime = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).stelPin),
              backgroundColor: Colors.orange,
            ),
          );
          return didAuthenticate;
        }
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
        _errorMessage = AppLocalizations.of(context).voerEenPinIn;
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
          _errorMessage = AppLocalizations.of(context).ongeldigePin;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Login error', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Inloggen mislukt. Probeer opnieuw.';
      });
    }
  }

  void _showEnableBiometricManuallyDialog() async {
    // Biometrie mag alleen bovenop een bestaande PIN worden geactiveerd.
    final pinSet = await db.hasPinSet();
    if (!pinSet) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).stelEerstPin),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() => _isFirstTime = true);
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.fingerprint, color: AppTheme.primaryTeal),
            SizedBox(width: 8),
            Text(AppLocalizations.of(context).biometrieActiveren),
          ],
        ),
        content: Text(
          AppLocalizations.of(context).biometrieInschakelenVraag,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).annuleren),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final bool didAuthenticate = await _authenticateWithBiometrics();
              if (didAuthenticate) {
                await _secureStorage.write(key: 'biometric_enabled', value: 'true');
                try {
                  await db.updateBiometricEnabled(true);
                } catch (_) {}
                if (mounted) {
                  setState(() => _biometricEnabled = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context).biometrieGeactiveerd),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
            child: Text(
              AppLocalizations.of(context).activeren,
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _showEnableBiometricDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).biometrischeAuthenticatie),
        content: Text(
          AppLocalizations.of(context).biometrieInschakelenVraag,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showNotificationDialog();
            },
            child: Text(AppLocalizations.of(context).neeBedankt),
          ),
          ElevatedButton(
            onPressed: () async {
              final bool didAuthenticate = await _authenticateWithBiometrics();
              if (didAuthenticate) {
                await _secureStorage.write(key: 'biometric_enabled', value: 'true');
                // Bewaar de vlag ook in de database zodat herinstallatie hem niet kwijt is.
                try {
                  await db.updateBiometricEnabled(true);
                } catch (_) {}
                if (mounted) {
                  Navigator.pop(context);
                  _showNotificationDialog();
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
            child: Text(AppLocalizations.of(context).jaInschakelen, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
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
        title: Text(AppLocalizations.of(context).notificaties),
        content: Text(
          AppLocalizations.of(context).notificatiesOntvangenVraag,
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
            child: Text(AppLocalizations.of(context).neeBedankt),
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
            child: Text(AppLocalizations.of(context).jaInschakelen, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
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
            SizedBox(width: 8),
            Text(AppLocalizations.of(context).pinVergeten),
          ],
        ),
        content: Text(
          AppLocalizations.of(context).pinVergetenInhoud,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).annuleren),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showResetConfirmationDialog();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context).appResetten),
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
        title: Text(AppLocalizations.of(context).laatsteWaarschuwing),
        content: Text(
          AppLocalizations.of(context).laatsteWaarschuwingInhoud,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).neeAnnuleren),
          ),
          ElevatedButton(
            onPressed: () async {
              await _resetApp();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context).jaResetAlles, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      ),
    );
  }

  Future<void> _resetApp() async {
    try {
      await _secureStorage.delete(key: 'biometric_enabled');
      await _secureStorage.delete(key: 'password_hash');
      // Wis ook de database-vlag zodat een toekomstige herinstallatie de app
      // niet in een half-ingestelde staat achterlaat.
      try {
        await db.updateBiometricEnabled(false);
      } catch (_) {}
      await db.clearAllData();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).appGeresetStartOpnieuw),
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
            content: Text(AppLocalizations.of(context).foutResetten(e)),
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
                    Text(AppLocalizations.of(context).laden, style: TextStyle(fontSize: 18, color: AppTheme.primaryTeal)),
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
                            ? AppLocalizations.of(context).stelPinOmTeBeginnen
                            : AppLocalizations.of(context).voerJePinIn,
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
                                AppLocalizations.of(context).loginMetBiometrie,
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
                              AppLocalizations.of(context).ofWord,
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),

                      // Activeer biometrie (als beschikbaar, maar nog niet ingeschakeld)
                      if (!kIsWeb && _biometricAvailable && !_biometricEnabled && !_isFirstTime)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextButton.icon(
                            onPressed: () => _showEnableBiometricManuallyDialog(),
                            icon: Icon(Icons.fingerprint, color: AppTheme.primaryTeal),
                            label: Text(
                              AppLocalizations.of(context).biometrieActiveren,
                              style: TextStyle(color: AppTheme.primaryTeal),
                            ),
                          ),
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
                                labelText: AppLocalizations.of(context).pin,
                                hintText: _isFirstTime
                                    ? AppLocalizations.of(context).minimaal4Cijfers
                                    : AppLocalizations.of(context).voerJePinIn,
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
                                  _isFirstTime
                                      ? AppLocalizations.of(context).pinInstellen
                                      : AppLocalizations.of(context).inloggen,
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
                                    AppLocalizations.of(context).pinVergeten,
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
