import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = [
    _OnbPage(icon: Icons.favorite, title: 'Welkom bij Ritme', desc: 'Ritme helpt je dagelijks je sociale ritme bij te houden: stemming, slaap, activiteiten, medicatie en afspraken. Jouw data blijft op je telefoon.'),
    _OnbPage(icon: Icons.wb_sunny_outlined, title: 'Ochtend & avond check-in', desc: 'Start je dag met de ochtend-check-in (slaap & stemming) en sluit af met de avond-check-in (5 SRM-momenten). Dashboard toont of je dag compleet is.'),
    _OnbPage(icon: Icons.health_and_safety_outlined, title: 'Crisisplan binnen handbereik', desc: 'Je crisisplan staat altijd in het menu (hart-icoon). Voeg contacten en voortekenen toe, zodat je er snel bij kunt als het nodig is.'),
  ];

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
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Overslaan'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) {
                  final p = _pages[i];
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
              children: List.generate(_pages.length, (i) => Container(
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
                    if (_index == _pages.length - 1) _finish();
                    else _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                  },
                  child: Text(_index == _pages.length - 1 ? 'Aan de slag' : 'Volgende'),
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
