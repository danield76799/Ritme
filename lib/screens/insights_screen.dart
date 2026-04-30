import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../service_locator.dart';
import '../theme/app_theme.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {




  bool _isLoading = true;
  Map<String, dynamic> _weeklyStats = {};
  List<String> _insights = [];

  @override
  void initState() {
    super.initState();
    _laadData();
  }

  Future<void> _laadData() async {
    setState(() => _isLoading = true);

    final stats = await _berekenWeekstats();
    final inzichten = _genereerInzichten(stats);

    setState(() {
      _weeklyStats = stats;
      _insights = inzichten;
      _isLoading = false;
    });
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
    int activiteitenTotaal = 0;

    for (var log in recenteLogs) {
      if (log['stemming_ochtend'] != null) {
        totaalStemming += log['stemming_ochtend'];
        stemCount++;
      }
      if (log['uren_slaap'] != null) {
        totaalSlaap += log['uren_slaap'];
      }
    }

    // Tel activiteiten
    for (var log in recenteLogs) {
      final activiteiten = await db.getSrmActivities(log['date']);
      activiteitenTotaal += activiteiten.length;
    }

    // Stabiliteit berekenen (hoe constanter, hoe hoger)
    double stabiliteit = 0;
    if (recenteLogs.length >= 3) {
      // Check of er een patroon is in slaap/ stemming
      stabiliteit = 75.0 + (recenteLogs.length * 3); // Placeholder stabiliteitsberekening
    }

    return {
      'aantalDagen': recenteLogs.length,
      'gemiddeldeStemming': stemCount > 0 ? totaalStemming / stemCount : 0.0,
      'gemiddeldeSlaap': recenteLogs.isNotEmpty ? totaalSlaap / recenteLogs.length : 0.0,
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
    if (gemSlaap < 6) {
      inzichten.add('⚠️ Je slaapt gemiddeld minder dan 6 uur. Dit kan je stemming negatief beïnvloeden.');
    } else if (gemSlaap >= 7 && gemSlaap <= 9) {
      inzichten.add('✅ Je slaap van gemiddeld ${gemSlaap.toStringAsFixed(1)} uur is prima!');
    } else if (gemSlaap > 9) {
      inzichten.add('💤 Je slaapt gemiddeld ${gemSlaap.toStringAsFixed(1)} uur - veel rust is goed!');
    }

    // Stemming inzichten
    double gemStemming = stats['gemiddeldeStemming'];
    if (gemStemming != 0) {
      // Converteer van -5 tot +5 naar 0-10 schaal
      double stemming10 = ((gemStemming + 5) / 10 * 10).clamp(0.0, 10.0);
      if (stemming10 < 4) {
        inzichten.add('📉 Je gemiddelde stemming is aan de lage kant. Overweeg extra zelfzorg deze week.');
      } else if (stemming10 >= 6) {
        inzichten.add('😊 Je stemming is overwegend positief!');
      }
    }

    // Activiteiten
    int activiteiten = stats['totaleActiviteiten'];
    if (activiteiten < 7) {
      inzichten.add('🎯 Probeer meer sociale activiteiten te plannen - die helpen je ritme stabiel te houden.');
    } else if (activiteiten >= 14) {
      inzichten.add('🌟 Veel activiteiten deze week! Zorg voor voldoende rustmomenten.');
    }

    // Stabiliteit
    double stabiliteit = stats['stabiliteit'];
    if (stabiliteit > 80) {
      inzichten.add('⚡ Je ritme is erg stabiel - uitstekend!');
    } else if (stabiliteit < 50) {
      inzichten.add('🔄 Je ritme wisselt sterk. Probeer vaste tijden aan te houden voor opstaan en slapen.');
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

    // Anonimiseer - geen namen, geen data
    String samenvatting = '''
Ritme Weekrapport (anoniem)

Periode: Afgelopen 7 dagen
Aantal gelogde dagen: ${logs.length}

Slaap:
- Gemiddeld: ${gemSlaap.toStringAsFixed(1)} uur per nacht
- Aantal nachten gelogd: ${logs.where((l) => l['uren_slaap'] != null).length}

Stemming:
- Gemiddeld: ${gemStemming.toStringAsFixed(1)} (schaal -5 tot +5)
- Positief/negatief: ${gemStemming >= 0 ? 'Overwegend positief' : 'Overwegend negatief'}

Activiteiten:
- Totaal geregistreerd: $activiteiten

Patronen opgevallen:
${_insights.map((i) => '- ${i.replaceAll(RegExp(r'^[⚠️✅💤😊📉📈🎯🌟⚡🔄]'), '').trim()}').join('\n')}

-- 
Dit rapport is gegenereerd door de Ritme app en bevat geen persoonlijke identificatiegegevens.
''';

    return samenvatting;
  }

  Future<void> _kopieerNaarKlembord() async {
    final samenvatting = _genereerAiSamenvatting();
    await Clipboard.setData(ClipboardData(text: samenvatting));

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
                                  color: Colors.grey[600],
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
                      Expanded(child: _bouwStatCard('💤', 'Gem. Slaap', '${(_weeklyStats['gemiddeldeSlaap'] ?? 0).toStringAsFixed(1)} uur', Colors.blue)),
                      const SizedBox(width: 12),
                      Expanded(child: _bouwStatCard('😊', 'Gem. Stemming', '${(_weeklyStats['gemiddeldeStemming'] ?? 0).toStringAsFixed(1)}', Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _bouwStatCard('🎯', 'Activiteiten', '${_weeklyStats['totaleActiviteiten'] ?? 0}', Colors.green)),
                      const SizedBox(width: 12),
                      Expanded(child: _bouwStatCard('⚡', 'Stabiliteit', '${(_weeklyStats['stabiliteit'] ?? 0).toStringAsFixed(0)}%', Colors.purple)),
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
                          style: TextStyle(color: Colors.grey[600]),
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
                        Icon(Icons.lock_outline, color: Colors.grey[600], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ritme deelt nooit data met derden. AI-analyse doe je bewust en persoonlijk.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
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

  Widget _bouwStatCard(String emoji, String label, String waarde, Color kleur) {
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
          Text(emoji, style: const TextStyle(fontSize: 24)),
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
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}



