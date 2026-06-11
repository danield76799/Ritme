import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  // Medical Teal brand palette
  static const Color medicalTeal = Color(0xFF4FB2C1);
  static const Color primaryTeal = medicalTeal;  // legacy alias
  static const Color medicalTealDark = Color(0xFF3A8A96);
  static const Color medicalTealLight = Color(0xFF7AC8D3);
  static const Color textCharcoal = Color(0xFF222222);
  static const Color textMedium = Color(0xFF444444);
  static const Color backgroundColor = Color(0xFFF7F9FA);
  static const Color backgroundColorAlt = Color(0xFFFFFFFF);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color dividerColor = Color(0xFFE8ECEF);

  static const Color darkBackground = Color(0xFF0F1A1D);
  static const Color darkSurface = Color(0xFF1A2B30);
  static const Color darkCard = Color(0xFF223236);
  static const Color darkText = Color(0xFFF0F5F7);
  static const Color darkTextSecondary = Color(0xFFB8C5C8);

  // Status colors - high contrast versions
  static Color success = Color(0xFF2E7D32);
  static Color warning = Color(0xFFED6C02);
  static Color error = Color(0xFFD32F2F);
  static Color info = Color(0xFF0277BD);

  static double borderRadius = 16.0;
  static double largeRadius = 24.0;

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: medicalTeal,
        onPrimary: Colors.white,
        secondary: medicalTealDark,
        onSecondary: Colors.white,
        surface: surfaceColor,
        onSurface: textCharcoal,
        error: error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: medicalTeal,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: medicalTeal,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: medicalTeal,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: medicalTeal,
          side: const BorderSide(color: medicalTeal, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: medicalTeal,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: surfaceColor,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dividerColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dividerColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: medicalTeal, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: textMedium),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: backgroundColor,
        selectedColor: medicalTeal.withValues(alpha: 0.15),
        labelStyle: TextStyle(color: textCharcoal),
        side: BorderSide(color: dividerColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return medicalTeal;
          return Colors.grey.shade300;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: textCharcoal,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: textCharcoal, letterSpacing: -0.5),
        displayMedium: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: textCharcoal, letterSpacing: -0.4),
        displaySmall: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: textCharcoal),
        headlineLarge: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: textCharcoal, letterSpacing: -0.3),
        headlineMedium: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textCharcoal, letterSpacing: -0.2),
        headlineSmall: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: textCharcoal),
        titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textCharcoal),
        titleMedium: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textCharcoal),
        titleSmall: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textCharcoal),
        bodyLarge: const TextStyle(fontSize: 18, color: textCharcoal, height: 1.6),
        bodyMedium: const TextStyle(fontSize: 16, color: textCharcoal, height: 1.6),
        bodySmall: const TextStyle(fontSize: 15, color: textMedium, height: 1.6),
        labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textCharcoal),
        labelMedium: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textMedium),
        labelSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textMedium),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: medicalTealLight,
        onPrimary: darkBackground,
        secondary: medicalTeal,
        onSecondary: darkBackground,
        surface: darkSurface,
        onSurface: darkText,
        error: error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: darkSurface,
        foregroundColor: darkText,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: darkText,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: medicalTealLight),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: medicalTealLight,
        foregroundColor: darkBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: medicalTealLight,
          foregroundColor: darkBackground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: medicalTealLight,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: medicalTealLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: darkText),
        headlineMedium: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: darkText),
        titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: darkText),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: darkText),
        bodyLarge: const TextStyle(fontSize: 18, color: darkText, height: 1.6),
        bodyMedium: const TextStyle(fontSize: 16, color: darkTextSecondary, height: 1.6),
        bodySmall: const TextStyle(fontSize: 15, color: darkTextSecondary, height: 1.6),
        labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: darkText),
        labelMedium: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: darkTextSecondary),
        labelSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: darkTextSecondary),
      ),
    );
  }

  // Chart palette (teal-based)
  static const List<Color> chartColors = [
    medicalTeal,
    medicalTealDark,
    medicalTealLight,
    Color(0xFF6BA4C7),
    Color(0xFFE8A552),
  ];

  // Brand gradient (teal)
  static LinearGradient get brandGradient => LinearGradient(
    colors: [medicalTeal, medicalTealDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Warm gradient alias (alias for brandGradient for legacy code)
  static LinearGradient get warmGradient => brandGradient;

  // Card decoration helper
  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? darkCard : surfaceColor,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: (isDark ? Colors.black : Colors.black).withValues(alpha: isDark ? 0.3 : 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}
