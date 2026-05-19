import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  @override
  void initState() {
    super.initState();
    print('MoodScreen: initState called');
  }

  @override
  Widget build(BuildContext context) {
    print('MoodScreen: build called');
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Stemming',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mood, size: 64, color: AppTheme.primaryTeal),
            SizedBox(height: 16),
            Text(
              'Stemming scherm',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Als je dit ziet, werkt de UI!',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}