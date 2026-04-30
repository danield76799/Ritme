import 'package:flutter/material.dart';

/// Centralized app theme and colors for Ritme
/// Use these across all screens for consistency
class AppTheme {
  AppTheme._();

  // Primary brand colors
  static const Color primaryTeal = Color(0xFF4FB2C1);
  static const Color primaryTealDark = Color(0xFF3A8A96);
  static const Color textCharcoal = Color(0xFF333333);
  static const Color backgroundColor = Color(0xFFF7F9FA);
  static const Color backgroundColorAlt = Color(0xFFFAFAFA);

  // Common colors
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  // Status colors
  static const Color success = Colors.green;
  static const Color warning = Colors.orange;
  static const Color error = Colors.red;

  // Text styles
  static const TextStyle headingStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: textCharcoal,
  );

  static const TextStyle subheadingStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textCharcoal,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14,
    color: textCharcoal,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 12,
    color: Colors.grey,
  );

  // Theme data
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        primary: primaryTeal,
        surface: backgroundColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryTeal,
        foregroundColor: white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: white),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryTeal,
        foregroundColor: white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryTeal,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryTeal, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Helper method for card decoration
  static BoxDecoration cardDecoration({
    double borderRadius = 16,
    Color color = white,
    double elevation = 0,
    EdgeInsets? padding,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: elevation > 0
          ? [
              BoxShadow(
                color: black.withValues(alpha: 0.04 * elevation),
                blurRadius: 10 * elevation,
                offset: Offset(0, 4 * elevation),
              ),
            ]
          : null,
    );
  }

  // Section header widget
  static Widget sectionHeader(String title, {Color? color}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: color ?? primaryTeal,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: headingStyle,
        ),
      ],
    );
  }
}
