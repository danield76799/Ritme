import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Houdt de gebruiker zijn voorkeur voor licht/donker thema bij.
/// Default: volg het systeem (system).
class ThemeService {
  static const String _key = 'theme_mode';

  static const ThemeService instance = ThemeService._();

  const ThemeService._();

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }
}
