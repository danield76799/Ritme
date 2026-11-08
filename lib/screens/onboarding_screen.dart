import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../theme/app_theme.dart';
import '../generated/l10n/app_localizations.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  Future<void> _finish() async {
    try {
      if (Hive.isBoxOpen('settings')) {
        await Hive.box('settings').put('onboarding_done', true);
      }
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // De paginateksten staan in de l10n-arb-bestanden: een Engelstalige
    // gebruiker mag geen Nederlandse onboarding te zien.
    final pages = [
      _OnbPage(
        icon: Icons.favorite,
        title: l10n.onboardingWelkomTitel,
        desc: l10n.onboardingWelkomBeschrijving,
      ),
      _OnbPage(
        icon: Icons.wb_sunny_outlined,
        title: l10n.onboardingCheckinTitel,
        desc: l10n.onboardingCheckinBeschrijving,
      ),
      _OnbPage(
        icon: Icons.health_and_safety_outlined,
        title: l10n.onboardingCrisisplanTitel,
        desc: l10n.onboardingCrisisplanBeschrijving,
      ),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(l10n.overslaan),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: pages.length,
                itemBuilder: (_, i) {
                  final p = pages[i];
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96, height: 96,
                          decoration: BoxDecoration(
                            color: AppTheme.medicalTeal.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(p.icon, size: 48, color: AppTheme.medicalTealDeep),
                        ),
                        const SizedBox(height: 24),
                        Text(p.title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        Text(p.desc, style: TextStyle(color: AppTheme.secondaryText(context), height: 1.5), textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pages.length, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _index == i ? 20 : 8, height: 8,
                decoration: BoxDecoration(
                  color: _index == i ? AppTheme.medicalTealDeep : theme.dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_index == pages.length - 1) {
                      _finish();
                    } else {
                      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                    }
                  },
                  child: Text(_index == pages.length - 1 ? l10n.aanDeSlag : l10n.volgende),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnbPage {
  final IconData icon; final String title; final String desc;
  const _OnbPage({required this.icon, required this.title, required this.desc});
}
