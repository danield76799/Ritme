import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  // Medical Teal brand palette
  static const Color medicalTeal = Color(0xFF4FB2C1);
  static const Color primaryTeal = medicalTeal;  // legacy alias
  static const Color medicalTealDark = Color(0xFF3A8A96);
  static const Color medicalTealLight = Color(0xFF7AC8D3);

  /// Accent-teal voor gebruik OP een lichte achtergrond (light mode).
  ///
  /// [medicalTeal] (#4FB2C1) haalt op wit maar 2.48:1 — onder de WCAG-norm,
  /// terwijl hij op de donkere kaart (#223236) ruim 5.37:1 haalt. Eén tint kan
  /// dus niet beide modes dekken: deze variant haalt 4.95:1 op wit én 4.95:1
  /// met witte tekst erop, zodat hij zowel als icoon-, tekst- als knopkleur
  /// werkt. Gebruik daarom nooit [medicalTeal] direct op een licht oppervlak.
  static const Color medicalTealDeep = Color(0xFF2F7A85);
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

  /// Hoekenschaal van de app — hier houden, nergens anders verzinnen:
  ///   12  knoppen, rijen, invoervelden, chips en kleine kaarten
  ///   16  kaarten en dialoog-inhoud (borderRadius)
  ///   24  dialogs en hero-vlakken (largeRadius)
  ///   999 pillen (chips die rondom rond zijn)
  /// Kleinere waarden (2/4/6) alleen functioneel: accentstreepjes, dots en
  /// grafiekbalken waar de straal uit de vorm volgt, niet uit de stijl.
  static double smallRadius = 12.0;

  /// Consistente horizontale schermpadding. Gebruik dit voor zowel de AppBar
  /// (`titleSpacing`) als de body, zodat de titel exact boven de kaarten en het
  /// grid uitlijnt. Flutters AppBar-default is toevallig ook 16
  /// (`NavigationToolbar.kMiddleSpacing`), maar expliciet vastpinnen voorkomt
  /// dat een themawijziging de uitlijning stil breekt.
  /// Tekstschaal van de app (losse fontSize-literals):
  ///   12  captions, secundaire labels, dichte tabellen
  ///   13  hulptekst onder titels
  ///   14  body en de meeste labels
  ///   16  subtitels, knoptekst, kaartwaarden
  ///   18+ koppen en hero-cijfers (per scherm, spaarzaam)
  /// Kleinere maten (10/11) alleen in grafiekassen; 15/17/22 niet gebruiken
  /// (afgerond naar 16/16/20). PDF-tekst (pw.TextStyle) valt hierbuiten.
  static const double screenPadding = 16.0;

  /// Secundaire tekstkleur die WCAG AA (>=4.5:1) haalt op zowel de pagina-
  /// achtergrond als op de kaarten. Gebruik dit i.p.v. `withValues(alpha: 0.6)`
  /// op tekst: #B8C5C8 op 60% gedimd zakt naar 3.7:1 en is dan onleesbaar.
  static Color secondaryText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : textMedium;

  /// Primaire tekstkleur die in BEIDE modes leesbaar is.
  ///
  /// Gebruik dit in plaats van `Colors.black` of `Colors.black54` voor tekst
  /// op een thema-afhankelijke ondergrond: zwart haalt op de donkere kaart
  /// (#223236) maar 1.58:1 en is dan onzichtbaar. In light mode is [textCharcoal]
  /// juist de juiste keuze (>=13:1 op wit).
  static Color primaryText(BuildContext context) =>
      primaryTextOn(Theme.of(context).brightness);

  static Color primaryTextOn(Brightness brightness) =>
      brightness == Brightness.dark ? darkText : textCharcoal;

  /// Gedempte tekst/icoonkleur die in BEIDE modes >=4.5:1 haalt.
  ///
  /// `Colors.black54` op donker geeft 1.36:1 — vrijwel onzichtbaar. In light
  /// mode is [textMedium] donker genoeg en duidelijk secundair.
  static Color mutedText(BuildContext context) =>
      mutedTextOn(Theme.of(context).brightness);

  static Color mutedTextOn(Brightness brightness) =>
      brightness == Brightness.dark ? darkTextSecondary : textMedium;

  /// Kleur voor een UITSTAANDE/lege waarde ("nog niets ingevuld").
  ///
  /// `Colors.grey.shade400` haalt op licht 1.78:1 en op donker 3.9:1 — beide
  /// onder de norm voor tekst. Deze tint is bewust zwakker dan [mutedText],
  /// maar blijft leesbaar.
  static Color placeholderText(BuildContext context) =>
      placeholderTextOn(Theme.of(context).brightness);

  static Color placeholderTextOn(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFF8A9BA0) : const Color(0xFF6B7B80);

  /// Accent-teal die in BEIDE modes leesbaar is.
  ///
  /// #4FB2C1 werkt alleen op donker (5.37:1) en #2F7A85 alleen op licht
  /// (4.95:1). Deze helper kiest de juiste variant, zodat een icoon of link
  /// nooit ongemerkt onder de contrastnorm zakt. Gebruik dit in plaats van
  /// [medicalTeal]/[primaryTeal] wanneer de ondergrond per thema wisselt
  /// (kaarten, scaffold, knoppen).
  static Color accent(BuildContext context) =>
      accentOn(Theme.of(context).brightness);

  static Color accentOn(Brightness brightness) =>
      brightness == Brightness.dark ? medicalTealLight : medicalTealDeep;

  /// Succes-tint met >=3:1 contrast tegen de onderliggende kaart.
  /// Het donkere #2E7D32 haalt maar 2.6:1 op de donkere kaart (#223236).
  static Color successOn(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFF4CAF50) : success;

  /// Rood dat in BEIDE modes leesbaar is (tekst én icoon).
  ///
  /// [error] (#D32F2F) haalt 4.98:1 op wit maar zakt op de donkere kaart
  /// (#223236) naar 3.15:1 — te weinig voor tekst. Deze helper kiest per
  /// brightness, zodat foutmeldingen ook in dark mode leesbaar zijn en
  /// destructieve iconen niet wegvallen tegen hun achtergrond.
  static Color danger(BuildContext context) =>
      dangerOn(Theme.of(context).brightness);

  static Color dangerOn(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFFFFB4AB) : error;

  /// Rode ICOONKLEUR voor op de AppBar.
  ///
  /// De AppBar is nu in BEIDE modes TRANSPARANT en volgt dus de
  /// pagina-achtergrond (scaffold). Daarmee is er geen omgekeerde balk meer en
  /// is [dangerOn] de juiste keuze — die rekent al per brightness.
  ///
  /// Deze functie blijft bestaan als dunne alias zodat aanroepen blijven
  /// werken, maar de oude reden ("de balk is in dark mode LICHT en in light
  /// mode DONKER") geldt NIET meer. De oude waarden (#8C1D18 op donker,
  /// #FFCDD2 op licht) waren voor die omgekeerde balk bedoeld en haalden op
  /// de huidige pagina-achtergrond nog maar 1.94:1 resp. 1.33:1.
  static Color dangerOnAppBar(Brightness brightness) => dangerOn(brightness);

  /// Informatief blauw dat in BEIDE modes leesbaar is (links/kopieer-acties).
  static Color infoOn(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFF7EC8F0) : info;

  /// Amber voor de streak-chip. `orange.shade700` haalt 3.6:1 op de chip en
  /// zakt daarmee onder de AA-norm; deze tinten halen 5.9:1 resp. 7.5:1.
  static Color streakText(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFFFFB74D) : const Color(0xFF8A5A00);

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        // Light mode gebruikt de donkere teal (#2F7A85): met #4FB2C1 haalde
        // witte AppBar-tekst maar 2.48:1 en teal accenttekst op wit ook 2.48:1.
        // #2F7A85 haalt 4.95:1 met witte tekst erop EN 4.95:1 als accenttekst
        // op wit, dus titel, icoon, link en knop zijn in één keer in orde.
        primary: medicalTealDeep,
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
        // De balk is TRANSPARANT en volgt dus de pagina-achtergrond. Dat is de
        // behandeling die het dashboard al had: de titel staat los boven de
        // kaarten in plaats van in een gekleurd vlak.
        //
        // WAAROM ÉÉN BRON: voorheen zetten 16 schermen zelf
        // `backgroundColor: colorScheme.primary` — exact wat het thema hier
        // ook deed. Die herhaling was ruis, en juist daardoor liepen de
        // schermen uit elkaar: 3 transparant, 16 vol teal, 1 via de scaffold.
        // In dark mode gaf dat een fel-lichte balk (#7AC8D3, 9.30:1 verschil
        // met de pagina) naast bijna-zwarte schermen.
        backgroundColor: Colors.transparent,
        // surfaceTintColor EN scrolledUnderElevation moeten uit, anders legt
        // Material 3 in light mode een paarse tint over de transparante balk
        // zodra er content onder doorscrollt. morning_checkin zette dit per
        // scherm; hier geldt het voor alle 20.
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        // foregroundColor kleurt titel én iconen op de balk. onSurface is in
        // light mode #222222 en in dark mode #F0F5F7 — beide leesbaar op de
        // pagina-achtergrond (#F7F9FA resp. #0F1A1D).
        foregroundColor: textCharcoal,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textCharcoal,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: textCharcoal),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          // De pagina is LICHT, dus de statusbar-iconen moeten donker zijn.
          // Met Brightness.light (de oude waarde voor de donkere balk) waren
          // de klok en batterij onzichtbaar.
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: medicalTealDeep,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: medicalTealDeep,
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
          foregroundColor: medicalTealDeep,
          side: const BorderSide(color: medicalTealDeep, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: medicalTealDeep,
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
        // Zelfde behandeling als light: transparant, titel en iconen in
        // onSurface. De oude dark-balk was #1A2B30 met teal iconen; die
        // wijkt nu niet meer af van de pagina (#0F1A1D).
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: darkText,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: darkText,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: darkText),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          // De pagina is DONKER, dus de statusbar-iconen moeten licht zijn.
          statusBarIconBrightness: Brightness.light,
        ),
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
        displayLarge: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: darkText, letterSpacing: -0.5),
        displayMedium: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: darkText, letterSpacing: -0.4),
        displaySmall: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: darkText),
        headlineLarge: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: darkText),
        headlineMedium: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: darkText),
        headlineSmall: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: darkText),
        titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: darkText),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: darkText),
        titleSmall: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: darkText),
        bodyLarge: const TextStyle(fontSize: 18, color: darkText, height: 1.6),
        bodyMedium: const TextStyle(fontSize: 16, color: darkTextSecondary, height: 1.6),
        bodySmall: const TextStyle(fontSize: 15, color: darkTextSecondary, height: 1.6),
        labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: darkText),
        labelMedium: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: darkTextSecondary),
        labelSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: darkTextSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: medicalTealLight,
        contentTextStyle: TextStyle(color: darkBackground, fontWeight: FontWeight.w500),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkCard,
        selectedColor: medicalTealLight.withValues(alpha: 0.25),
        labelStyle: TextStyle(color: darkText),
        side: BorderSide(color: medicalTealDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: medicalTealLight,
          side: const BorderSide(color: medicalTealLight, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return darkBackground;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return medicalTealLight;
          return medicalTealLight.withValues(alpha: 0.15);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: darkText),
        contentTextStyle: const TextStyle(fontSize: 15, color: darkText, height: 1.5),
      ),
      dividerTheme: DividerThemeData(
        color: Color(0xFF2E4046),
        thickness: 1,
        space: 1,
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
  /// Gradient van de begroetingskaart in LIGHT mode.
  ///
  /// De kaart gebruikt `onSurface` als tekstkleur, in light mode dus #222222.
  /// Met de oude [medicalTeal] -> [medicalTealDark] zakte de datumregel
  /// (15sp, 85% opacity) naar 3.31:1. Deze lichtere teal-paar houdt de
  /// merkidentiteit en haalt >=4.9:1 op beide uiteinden.
  static LinearGradient get brandGradient => LinearGradient(
    colors: [medicalTealLight, medicalTeal],
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
