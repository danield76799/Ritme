import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../service_locator.dart';
import '../utils/logger.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  String _formatSlaap(double uren) {
    int totaleMinuten = (uren * 60).round();
    int uur = totaleMinuten ~/ 60;
    int minuten = totaleMinuten % 60;
    if (minuten == 0) return '${uur}u';
    return '${uur}u ${minuten}m';
  }

  bool _isLoading = true;
  Map<String, dynamic> _weeklyStats = {};
  List<String> _insights = [];
  DateTime? _lastCacheTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _laadData();
  }

  Future<void> _laadData() async {
    // Check cache - alleen verversen als cache verlopen is
    if (_lastCacheTime != null && 
        DateTime.now().difference(_lastCacheTime!) < _cacheDuration &&
        _insights.isNotEmpty) {
      return; // Gebruik cached data
    }
    
    setState(() => _isLoading = true);

    try {
      final stats = await _berekenWeekstats();
      final inzichten = _genereerInzichten(stats);

      if (mounted) {
        setState(() {
          _weeklyStats = stats;
          _insights = inzichten;
          _isLoading = false;
          _lastCacheTime = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _insights = ['Fout bij laden van inzichten: $e'];
        });
      }
    }
  }

  Future<Map<String, dynamic>> _berekenWeekstats() async {
    final now = DateTime.now();
    final zevenDagenGeled = now.subtract(const Duration(days: 7));

    final logs = await db.getDailyLogs();
    final recenteLogs = logs.where((log) {
      if (log['date'] == null) return false;
      try {
        final logDate = DateTime.parse(log['date']);
        return logDate.isAfter(zevenDagenGeled) || logDate.isAtSameMomentAs(zevenDagenGeled);
      } catch (e) {
        return false;
      }
    }).toList();

    if (recenteLogs.isEmpty) {
      return {
        'aantalDagen': 0,
        'gemiddeldeStemming': 0.0,
        'gemiddeldeSlaap': 0.0,
        'totaleActiviteiten': 0,
        'stabiliteit': 0.0,
        'trends': [],
      };
    }

    // Bereken gemiddeldes
    double totaalStemming = 0;
    double totaalSlaap = 0;
    int stemCount = 0;
    int sleepCount = 0;  // <-- NIEUW: Tel alleen dagen met slaap
    int activiteitenTotaal = 0;
    
    // CORRECTIE: Gebruik een Set om unieke dagen te tellen
    Set<String> uniekeDagen = {};
    
    for (var log in recenteLogs) {
      // Tel unieke dagen
      if (log['date'] != null) {
        uniekeDagen.add(log['date'].toString());
      }
      
      // Handle both String and num types for stemming_hoog
      dynamic rawStemming = log['stemming_hoog'];
      if (rawStemming != null) {
        double stemming;
        if (rawStemming is num) {
          stemming = rawStemming.toDouble();
        } else if (rawStemming is String) {
          stemming = double.tryParse(rawStemming) ?? 0.0;
        } else {
          stemming = 0.0;
        }
        totaalStemming += stemming;
        stemCount++;
      }

      // Handle both String and num types for sleep_hours - prioritize over uren_slaap
      dynamic rawSlaap = log['sleep_hours'];
      if (rawSlaap != null) {
        double slaap;
        if (rawSlaap is num) {
          slaap = rawSlaap.toDouble();
        } else if (rawSlaap is String) {
          slaap = double.tryParse(rawSlaap) ?? 0.0;
        } else {
          slaap = 0.0;
        }
        if (slaap > 0) {
          totaalSlaap += slaap;
          sleepCount++;  // <-- NIEUW: Tel deze dag als slaapdag
        }
      } else {
        // Fallback to uren_slaap only if no sleep_hours
        dynamic rawUrenSlaap = log['uren_slaap'];
        if (rawUrenSlaap != null) {
          double slaap;
          if (rawUrenSlaap is num) {
            slaap = rawUrenSlaap.toDouble();
          } else if (rawUrenSlaap is String) {
            slaap = double.tryParse(rawUrenSlaap) ?? 0.0;
          } else {
            slaap = 0.0;
          }
          if (slaap > 0) {
            totaalSlaap += slaap;
            sleepCount++;  // <-- NIEUW: Tel deze dag als slaapdag
          }
        }
      }
    }

    // Tel activiteiten
    for (var log in recenteLogs) {
      final activiteiten = await db.getSrmActivities(log['date']);
      activiteitenTotaal += activiteiten.length;
    }

    // Stabiliteit berekenen (hoe constanter, hoe hoger)
    double stabiliteit = 0;
    if (uniekeDagen.length >= 2) {
      // Bereken variantie in stemming en slaap
      double stemmingVariantie = 0;
      double slaapVariantie = 0;
      
      if (stemCount > 1) {
        double gemStemming = totaalStemming / stemCount;
        double sumSquaredDiff = 0;
        for (var log in recenteLogs) {
          dynamic rawStemming = log['stemming_hoog'];
          if (rawStemming != null) {
            double stemming;
            if (rawStemming is num) {
              stemming = rawStemming.toDouble();
            } else if (rawStemming is String) {
              stemming = double.tryParse(rawStemming) ?? 0.0;
            } else {
              stemming = 0.0;
            }
            sumSquaredDiff += (stemming - gemStemming) * (stemming - gemStemming);
          }
        }
        stemmingVariantie = sumSquaredDiff / stemCount;
      }
      
      // Converteer variantie naar stabiliteit score (0-100)
      // Lage variantie = hoge stabiliteit
      double maxVariantie = 100; // Maximale verwachte variantie
      stabiliteit = (1 - (stemmingVariantie / maxVariantie).clamp(0.0, 1.0)) * 100;
    } else {
      // Met minder dan 2 dagen is stabiliteit onbekend
      stabiliteit = 0;
    }

    return {
      'aantalDagen': uniekeDagen.length,  // CORRECTIE: Unieke dagen in plaats van totale logs
      'sleepDays': sleepCount,  // Aantal dagen met slaap data
      'gemiddeldeStemming': stemCount > 0 ? totaalStemming / stemCount : 0.0,
      'gemiddeldeSlaap': sleepCount > 0 ? totaalSlaap / sleepCount : 0.0,
      'totaleActiviteiten': activiteitenTotaal,
      'stabiliteit': stabiliteit.clamp(0.0, 100.0),
      'logs': recenteLogs,
    };
  }

  List<String> _genereerInzichten(Map<String, dynamic> stats) {
    List<String> inzichten = [];

    if (stats['aantalDagen'] == 0) {
      inzichten.add('Nog geen data om te analyseren. Begin met het bijhouden van je stemming en slaap!');
      return inzichten;
    }

    // Slaap inzichten
    double gemSlaap = stats['gemiddeldeSlaap'];
    int aantalDagen = stats['aantalDagen'] ?? 0;
    int sleepDays = stats['sleepDays'] ?? 0;
    if (gemSlaap > 0) {
      if (sleepDays <= 2) {
        inzichten.add('Je hebt ${sleepDays == 1 ? '1 nacht' : '$sleepDays nachten'} slaap gelogd. Log meer dagen voor betere inzichten.');
      } else if (gemSlaap < 6) {
        inzichten.add('Je slaapt gemiddeld minder dan 6 uur. Dit kan je stemming negatief beinvloeden.');
      } else if (gemSlaap >= 7 && gemSlaap <= 9) {
        inzichten.add('Je slaap van gemiddeld ${_formatSlaap(gemSlaap)} is prima!');
      } else if (gemSlaap > 9) {
        inzichten.add('Je slaapt gemiddeld ${_formatSlaap(gemSlaap)} - veel rust is goed!');
      }
    }

    // Stemming inzichten
    double gemStemming = stats['gemiddeldeStemming'];
    if (gemStemming != 0) {
      // Converteer naar -5 tot +5 schaal als het op 0-100 schaal staat
      double stemmingSchaal;
      if (gemStemming > 10) {
        // Waarschijnlijk 0-100 schaal, converteer naar -5 tot +5
        stemmingSchaal = ((gemStemming / 100) * 10 - 5).clamp(-5.0, 5.0);
      } else {
        // Al op -5 tot +5 schaal
        stemmingSchaal = gemStemming.clamp(-5.0, 5.0);
      }
      
      // CORRECTIE: Check of er genoeg data is voor betekenisvolle conclusies
      int aantalStemmingen = 0;
      var logs = stats['logs'] as List<Map<String, dynamic>>? ?? [];
      for (var log in logs) {
        if (log['stemming_hoog'] != null) aantalStemmingen++;
      }
      
      if (aantalStemmingen < 3) {
        inzichten.add('Je hebt ${aantalStemmingen == 1 ? '1 stemming' : '$aantalStemmingen stemmingen'} gelogd. Log meer voor betrouwbare inzichten.');
      } else if (stemmingSchaal.abs() < 0.5) {
        // CORRECTIE: Neutrale stemming kan stabiel zijn of fluctuerend
        // Check de variantie
        double variantie = 0;
        if (aantalStemmingen > 1) {
          double sumSquaredDiff = 0;
          for (var log in logs) {
            dynamic rawStemming = log['stemming_hoog'];
            if (rawStemming != null) {
              double stemming;
              if (rawStemming is num) {
                stemming = rawStemming.toDouble();
              } else if (rawStemming is String) {
                stemming = double.tryParse(rawStemming) ?? 0.0;
              } else {
                stemming = 0.0;
              }
              sumSquaredDiff += (stemming - gemStemming) * (stemming - gemStemming);
            }
          }
          variantie = sumSquaredDiff / aantalStemmingen;
        }
        
        if (variantie > 2.0) {
          inzichten.add('Je stemming fluctueert rond het gemiddelde. Er is variatie in je dagelijkse stemming.');
        } else {
          inzichten.add('Je stemming is stabiel/neutraal.');
        }
      } else if (stemmingSchaal < -2) {
        inzichten.add('Je gemiddelde stemming is aan de lage kant. Overweeg extra zelfzorg deze week.');
      } else if (stemmingSchaal > 2) {
        inzichten.add('Je stemming is overwegend positief!');
      }
    }

    // Activiteiten
    int activiteiten = stats['totaleActiviteiten'];
    if (activiteiten < 7 && aantalDagen > 2) {
      inzichten.add('Probeer meer sociale activiteiten te plannen - die helpen je ritme stabiel te houden.');
    } else if (activiteiten >= 14) {
      inzichten.add('Veel activiteiten deze week! Zorg voor voldoende rustmomenten.');
    }

    // Stabiliteit - alleen tonen als er genoeg data is
    double stabiliteit = stats['stabiliteit'];
    if (aantalDagen >= 5) {
      if (stabiliteit > 80) {
        inzichten.add('Je ritme is erg stabiel - uitstekend!');
      } else if (stabiliteit < 50) {
        inzichten.add('Je ritme wisselt sterk. Probeer vaste tijden aan te houden voor opstaan en slapen.');
      }
    }

    return inzichten;
  }

  String _genereerAiSamenvatting() {
    if (_weeklyStats.isEmpty || _weeklyStats['aantalDagen'] == 0) {
      return 'Geen data beschikbaar over de afgelopen 7 dagen.';
    }

    final logs = _weeklyStats['logs'] as List<Map<String, dynamic>>? ?? [];
    double gemSlaap = _weeklyStats['gemiddeldeSlaap'];
    double gemStemming = _weeklyStats['gemiddeldeStemming'];
    int activiteiten = _weeklyStats['totaleActiviteiten'];
    int aantalDagen = _weeklyStats['aantalDagen'] ?? 0;

    // Converteer stemming naar -5 tot +5 schaal
    double stemmingSchaal;
    if (gemStemming > 10) {
      stemmingSchaal = ((gemStemming / 100) * 10 - 5).clamp(-5.0, 5.0);
    } else {
      stemmingSchaal = gemStemming.clamp(-5.0, 5.0);
    }

    // Anonimiseer - geen namen, geen data
    String samenvatting = '''
Hoi Gemini, wil jij mijn data analyseren?

Ritme Weekrapport (anoniem)

Periode: Afgelopen 7 dagen
Aantal gelogde dagen: $aantalDagen (unieke dagen binnen periode)

Slaap:
- Gemiddeld: ${_formatSlaap(gemSlaap)} per nacht
- Aantal nachten gelogd: ${logs.where((l) => l['uren_slaap'] != null || l['sleep_hours'] != null).map((l) => l['date']).toSet().length}

Stemming:
- Gemiddeld: ${stemmingSchaal.toStringAsFixed(1)} (schaal -5 tot +5)
- Aantal stemmingen gelogd: ${logs.where((l) => l['stemming_hoog'] != null).length}
- Stemming: ${stemmingSchaal.abs() < 0.5 ? 'Stabiel/Neutraal' : (stemmingSchaal >= 0 ? 'Overwegend positief' : 'Overwegend negatief')}

Activiteiten:
- Totaal geregistreerd: $activiteiten

Opmerking: Dit rapport is gebaseerd op $aantalDagen unieke dagen binnen de afgelopen 7 dagen.

Patronen opgevallen:
${_insights.map((i) => '- ${i.replaceAll(RegExp(r'^\p{Emoji}+', unicode: true), '').trim()}').join('\n')}

-- 
Dit rapport is gegenereerd door de Ritme app en bevat geen persoonlijke identificatiegegevens.

---AI Prompt---
Gemini, wil jij deze data analyseren en me tips geven om mijn stemming en slaapritme te verbeteren?
''';

    return samenvatting;
  }

  Future<void> _kopieerNaarKlembord() async {
    try {
      final samenvatting = _genereerAiSamenvatting();
      AppLogger.debug('Kopieer rapport: samenvatting lengte = ${samenvatting.length}');
      AppLogger.debug('Kopieer rapport: samenvatting lengte = ${samenvatting.length}');
      await Clipboard.setData(ClipboardData(text: samenvatting));
      AppLogger.debug('Kopieer rapport: clipboard setData succesvol');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Samenvatting gekopieerd naar klembord!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('ERROR kopieer rapport', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kon rapport niet kopiëren: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _openGemini() async {
    final url = Uri.parse('https://gemini.google.com/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        title: const Text(
          'Inzichten & Patronen',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _laadData,
            tooltip: 'Vernieuwen',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.insights, color: AppTheme.primaryTeal, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Afgelopen 7 dagen',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppTheme.textCharcoal,
                                ),
                              ),
                              Text(
                                '${_weeklyStats['aantalDagen'] ?? 0} dagen geanalyseerd',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stats cards
                  Text(
                    'Jouw Stats',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textCharcoal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _bouwStatCard('Slaap', 'Gem. Slaap', _formatSlaapUren((_weeklyStats['gemiddeldeSlaap'] ?? 0).toDouble()), Colors.blue)),
                      const SizedBox(width: 12),
                      Expanded(child: _bouwStatCard('Stemming', 'Gem. Stemming', _formatStemming((_weeklyStats['gemiddeldeStemming'] ?? 0).toDouble()), Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _bouwStatCard('Ritme', 'Sociaal Ritme', '${_weeklyStats['totaleActiviteiten'] ?? 0}', Colors.green)),
                      const SizedBox(width: 12),
                      Expanded(child: _bouwStatCard('Stabiliteit', 'Stabiliteit', '${(_weeklyStats['stabiliteit'] ?? 0).toStringAsFixed(0)}%', Colors.purple)),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Inzichten
                  Text(
                    'Persoonlijke Inzichten',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textCharcoal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_insights.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Nog niet genoeg data voor inzichten.\nBlijf bijhouden!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  else
                    ...(_insights.map((inzicht) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  inzicht,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textCharcoal,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))),
                  const SizedBox(height: 32),

                  // AI Sectie
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryTeal, AppTheme.primaryTeal.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.psychology, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'AI Diepgang',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Kopieer je anonieme weekrapport en plak het in Google Gemini voor gepersonaliseerde tips.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _kopieerNaarKlembord,
                                icon: const Icon(Icons.copy, size: 18),
                                label: const Text('Kopieer Rapport'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppTheme.primaryTeal,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _openGemini,
                                icon: const Icon(Icons.open_in_browser, size: 18),
                                label: const Text('Open Gemini'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Privacy disclaimer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, color: Colors.grey.shade600, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ritme deelt nooit data met derden. AI-analyse doe je bewust en persoonlijk.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  String _formatStemming(double stemming) {
    if (stemming == 0) return '0.0';
    // Converteer naar -5 tot +5 schaal
    double stemmingSchaal;
    if (stemming > 10) {
      stemmingSchaal = ((stemming / 100) * 10 - 5).clamp(-5.0, 5.0);
    } else {
      stemmingSchaal = stemming.clamp(-5.0, 5.0);
    }
    return stemmingSchaal.toStringAsFixed(1);
  }

  String _formatSlaapUren(double uren) {
    if (uren <= 0) return '0u 0m';
    final uur = uren.floor();
    final minuten = ((uren - uur) * 60).round();
    return '${uur}u ${minuten}m';
  }

  Widget _bouwStatCard(String label, String subtitle, String waarde, Color kleur) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kleur,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            waarde,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: kleur,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}



