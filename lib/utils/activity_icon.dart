import 'package:flutter/material.dart';

/// Icoon per SRM-activiteitstype.
///
/// De database bewaart de Nederlandse namen in title-case ("Opstaan",
/// "Eerste contact", "Werk / Hobby", "Avondeten", "Naar bed"); [type] wordt
/// hier genormaliseerd met `trim().toLowerCase()`, net als in [ActivityTypeL10n].
///
/// De losse kopieën van deze functie in de schermen misten de varianten
/// 'avondeten', 'eerste contact' en 'werk / hobby', waardoor juist de meest
/// voorkomende activiteiten allemaal op het generieke klok-icoon uitkwamen.
IconData activityTypeIcon(String type) {
  switch (type.trim().toLowerCase()) {
    case 'opstaan':
    case 'wakker':
      return Icons.wb_sunny_outlined;
    case 'slapen':
    case 'naar bed':
    case 'bed':
      return Icons.bedtime_outlined;
    case 'eten':
    case 'maaltijd':
    case 'avondeten':
      return Icons.restaurant_outlined;
    case 'werk':
    case 'werken':
    case 'werk / hobby':
      return Icons.work_outline;
    case 'sociaal contact':
    case 'contact':
    case 'eerste contact':
      return Icons.people_outline;
    default:
      return Icons.schedule;
  }
}

/// De stabiele, Nederlandse DB-naam voor een activiteitstype.
///
/// SRM-doeltijden staan in de settings onder vaste keys (`target_opstaan`,
/// `target_contact`, ...). Die lookup hoort op de DB-waarde te gebeuren, niet
/// op het vertaalde weergavelabel: met een Engelse telefoon werd
/// `targetTimes['Wake up']` opgevraagd terwijl de DB `'Opstaan'` opslaat, dus
/// viel het scherm terug op de (ontbrekende) p-score en stond alles op "Gemist".
const Map<String, String> _dbNames = {
  'opstaan': 'Opstaan',
  'wakker': 'Opstaan',
  'slapen': 'Naar bed',
  'naar bed': 'Naar bed',
  'bed': 'Naar bed',
  'eten': 'Avondeten',
  'maaltijd': 'Avondeten',
  'avondeten': 'Avondeten',
  'werk': 'Werk / Hobby',
  'werken': 'Werk / Hobby',
  'werk / hobby': 'Werk / Hobby',
  'sociaal contact': 'Eerste contact',
  'contact': 'Eerste contact',
  'eerste contact': 'Eerste contact',
};

String activityDbType(String type) =>
    _dbNames[type.trim().toLowerCase()] ?? type;
