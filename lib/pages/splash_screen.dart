import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../database/hive_database_helper.dart';
import '../generated/l10n/app_localizations.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/logo_hero.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Icon(
                    Icons.favorite,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Ritme',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimary,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'SRT Tracker',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 48),
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple navigator that auto-advances after 0.5 seconds
class SplashScreenWrapper extends StatefulWidget {
  const SplashScreenWrapper({super.key});

  @override
  State<SplashScreenWrapper> createState() => _SplashScreenWrapperState();
}

class _SplashScreenWrapperState extends State<SplashScreenWrapper> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      // Eerst waarschuwen als er bij het openen een beschadigd database-
      // bestand is gerepareerd; daarna pas verder naar de app.
      if (HiveDatabaseHelper.recoveredBoxes.isNotEmpty) {
        final l10n = AppLocalizations.of(context);
        final boxes = HiveDatabaseHelper.recoveredBoxes.join(', ');
        final herstel = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(l10n.dbBeschadigdTitel),
            content: Text(l10n.dbBeschadigdTekst(boxes)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.dbLater),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.dbNuHerstellen),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (herstel == true) {
          Navigator.of(context).pushReplacementNamed('/settings');
          return;
        }
      }
      final done = Hive.isBoxOpen('settings') ? Hive.box('settings').get('onboarding_done') == true : true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => done ? const LoginScreen() : const OnboardingScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SplashScreen();
  }
}