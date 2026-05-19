import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MoodScreen extends StatelessWidget {
  const MoodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('MoodScreen: BUILD called');
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Stemming', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primaryTeal,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mood, size: 64, color: AppTheme.primaryTeal),
            SizedBox(height: 16),
            Text('STEMMING', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Statische UI test - geen data'),
          ],
        ),
      ),
    );
  }
}