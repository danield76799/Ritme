// Gekozen backupmap via Android Storage Access Framework (09-2026).
//
// Waarom: direct schrijven naar Downloads is sinds Android 11 geblokkeerd
// (scoped storage) — een toestemming vragen helpt niet. Met SAF kiest de
// gebruiker één keer een map (systeemkiezer); die toestemming overleeft
// herstarts. Bij verwijderen van de app vervalt de toestemming, maar de
// BESTANDEN blijven staan — precies wat Daniel wil (de backup overleeft
// de-installatie).
//
// Zonder gekozen map valt BackupService terug op de app-map (altijd
// schrijfbaar, maar weg bij verwijderen).

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:saf/saf.dart';

import '../database/database_helper.dart';

class BackupMapService {
  static final DatabaseHelper _db = DatabaseHelper.instance;
  static final Saf _saf = Saf();

  /// Instelling-sleutels (vrije settings-map).
  static const mapUriKey = 'backup_map_uri';
  static const mapNaamKey = 'backup_map_naam';

  /// Opent de systeemkiezer. Geeft (mapnaam, fouttekst) terug: bij annuleren
  /// allebei null, bij falen een fouttekst — de UI toont die, zodat een
  /// mislukte keuze nooit meer stil blijft ("ik koos een map maar er staat
  /// Niet gekozen", 09-2026).
  static Future<({String? naam, String? fout})> kiesBackupMap() async {
    try {
      final huidig = await mapUri();
      final map = await _saf.pickDirectory(
        initialUri: huidig,
        // Expliciet: de toestemming moet herstarts overleven, anders vraagt
        // de app bij elke opstart opnieuw om een map.
        persistablePermission: true,
      );
      if (map == null) return (naam: null, fout: null);
      final settings = await _db.getSettings();
      final merged = Map<String, dynamic>.from(settings ?? {});
      merged[mapUriKey] = map.uri;
      merged[mapNaamKey] = map.name;
      await _db.updateSettingsMap(merged);
      debugPrint('BackupMapService: map gekozen (${map.name})');
      return (naam: map.name, fout: null);
    } catch (e) {
      debugPrint('BackupMapService: kiezen mislukt - $e');
      return (naam: null, fout: e.toString());
    }
  }

  /// Opgeslagen map-uri, of null als er nooit een gekozen is.
  static Future<String?> mapUri() async {
    final settings = await _db.getSettings();
    final uri = settings?[mapUriKey]?.toString();
    return (uri == null || uri.isEmpty) ? null : uri;
  }

  /// Opgeslagen mapnaam voor in de UI.
  static Future<String?> mapNaam() async {
    final settings = await _db.getSettings();
    final naam = settings?[mapNaamKey]?.toString();
    return (naam == null || naam.isEmpty) ? null : naam;
  }

  /// Wis de opgeslagen map (toestemming kwijt of gebruiker wil opnieuw).
  ///
  /// Schrijft lege strings: settings_extra kent geen delete via de
  /// repository en mapUri/mapNaam lezen leeg al als "geen".
  static Future<void> wisBackupMap() async {
    final settings = await _db.getSettings();
    final merged = Map<String, dynamic>.from(settings ?? {});
    merged[mapUriKey] = '';
    merged[mapNaamKey] = '';
    await _db.updateSettingsMap(merged);
  }

  /// Schrijft bytes als bestand in de gekozen map (overschrijft per week).
  /// Geeft true bij succes. Bij een dode toestemming wordt de opgeslagen
  /// map gewist (volgende keer valt de backup terug op de app-map) en
  /// komt er false terug — nooit een exception.
  static Future<bool> schrijf(String bestandsnaam, Uint8List bytes) async {
    try {
      final uri = await mapUri();
      if (uri == null) return false;
      await _saf.writeFileBytes(uri, bestandsnaam, 'application/json', bytes,
          overwrite: true);
      return true;
    } catch (e) {
      debugPrint('BackupMapService: schrijven mislukt, map gewist - $e');
      try {
        await wisBackupMap();
      } catch (_) {}
      return false;
    }
  }

  /// Ruimt oude auto-weekbestanden in de gekozen map op tot [behoud] stuks.
  static Future<void> ruimOp({int behoud = 4}) async {
    try {
      final uri = await mapUri();
      if (uri == null) return;
      final bestanden = await _saf.list(uri);
      final autos = bestanden
          .where((b) =>
              !b.isDir &&
              b.name.startsWith('ritme_backup_auto_') &&
              b.name.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      if (autos.length <= behoud) return;
      for (final oud in autos.take(autos.length - behoud)) {
        try {
          await _saf.delete(oud.uri);
        } catch (_) {}
      }
      debugPrint(
          'BackupMapService: ${autos.length - behoud} oude weekbestanden opgeruimd');
    } catch (e) {
      debugPrint('BackupMapService: opruimen mislukt (niet-fataal) - $e');
    }
  }
}
