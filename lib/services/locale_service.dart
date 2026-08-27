import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Houdt de gebruiker zijn voorkeur voor app-taal bij.
/// Default: volg het systeem (null -> device locale).
class LocaleService {
  static const String _key = 'app_locale';

  static const LocaleService instance = LocaleService._();

  const LocaleService._();

  /// Haal de opgeslagen locale op. `null` betekent: volg systeem.
  Future<Locale?> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == null || value.isEmpty) return null;
    final parts = value.split('_');
    if (parts.length == 1) return Locale(parts[0]);
    return Locale(parts[0], parts[1]);
  }

  /// Sla de gekozen locale op. Geef `null` door om systeem-locale te volgen.
  Future<void> setLocale(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.setString(_key, '');
    } else if (locale.countryCode != null) {
      await prefs.setString(_key, '${locale.languageCode}_${locale.countryCode}');
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
  }
}
