import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../service_locator.dart';

class CrisisPlanScreen extends StatefulWidget {
  const CrisisPlanScreen({super.key});

  @override
  State<CrisisPlanScreen> createState() => _CrisisPlanScreenState();
}

class _CrisisPlanScreenState extends State<CrisisPlanScreen> {
  List<Map<String, dynamic>> _sections = [];
  bool _isLoading = true;

  final _defaultSections = [
    {
      'section': 'manie_vroeg',
      'title': '⚠️ Bij eerste tekenen van manie/hypomanie',
      'hint': 'Bijv: contact opnemen met behandelaar, medicatie ophogen, prikkels vermijden, geen alcohol...',
    },
    {
      'section': 'manie_ernstig',
      'title': '🚨 Bij ernstige manie (noodsituatie)',
      'hint': 'Bijv: crisisdienst bellen (nummer), contactpersoon waarschuwen, naar SEH gaan...',
    },
    {
      'section': 'depressie_vroeg',
      'title': '🔵 Bij eerste tekenen van depressie',
      'hint': 'Bijv: dagstructuur vasthouden, kleine doelen stellen, sociale contacten forceren, bewegen...',
    },
    {
      'section': 'depressie_ernstig',
      'title': '🚨 Bij ernstige depressie / suïcidale gedachten',
      'hint': 'Bijv: 113 bellen (zelfmoordpreventie), crisisdienst, vertrouwenspersoon, niet alleen blijven...',
    },
    {
      'section': 'gemengd',
      'title': '🟡 Bij gemengde episode',
      'hint': 'Bijv: extra voorzichtig met medicatie, geen impulsieve beslissingen, behandelcontact intensiveren...',
    },
    {
      'section': 'contacten',
      'title': '📞 Belangrijke contacten',
      'hint': 'Bijv: behandelaar: 06-... / partner: 06-... / crisisdienst: 06-... / 113 Zelfmoordpreventie...',
    },
    {
      'section': 'medicatie_nood',
      'title': '💊 Medicatie noodplan',
      'hint': 'Bijv: welke medicatie ophogen bij manie, welke bij depressie, noodmedicatie in huis...',
    },
    {
      'section': 'wat_helpt',
      'title': '💚 Wat helpt mij',
      'hint': 'Bijv: wandelen in natuur, muziek luisteren, douchen, met vriend(in) praten, sporten...',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sections = await db.getCrisisPlan();

      // If empty, seed with defaults (empty content)
      if (sections.isEmpty) {
        for (var i = 0; i < _defaultSections.length; i++) {
          final def = _defaultSections[i];
          await db.insertCrisisPlanSection({
            'section': def['section'],
            'content': '',
            'sort_order': i,
          });
        }
        final reloaded = await db.getCrisisPlan();
        if (mounted) setState(() { _sections = reloaded; _isLoading = false; });
      } else {
        // Ensure all default sections exist
        for (final def in _defaultSections) {
          final exists = sections.any((s) => s['section'] == def['section']);
          if (!exists) {
            await db.insertCrisisPlanSection({
              'section': def['section'],
              'content': '',
              'sort_order': _defaultSections.indexOf(def),
            });
          }
        }
        final reloaded = await db.getCrisisPlan();
        if (mounted) setState(() { _sections = reloaded; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getTitle(String section) {
    for (final def in _defaultSections) {
      if (def['section'] == section) return def['title'] ?? section;
    }
    return section;
  }

  String _getHint(String section) {
    for (final def in _defaultSections) {
      if (def['section'] == section) return def['hint'] ?? '';
    }
    return '';
  }

  void _editSection(Map<String, dynamic> section) {
    final controller = TextEditingController(text: section['content'] as String? ?? '');
    final title = _getTitle(section['section'] as String);
    final hint = _getHint(section['section'] as String);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
            const SizedBox(height: 8),
            Text(hint, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'Schrijf hier je plan...',
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  await db.updateCrisisPlanSection(section['id'] as int, {'content': controller.text});
                  _loadData();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Opslaan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _sectionColor(String section) {
    if (section.startsWith('manie')) return Colors.orange;
    if (section.startsWith('depressie')) return Colors.blue;
    if (section == 'gemengd') return Colors.amber.shade700;
    if (section == 'contacten') return Colors.green;
    if (section == 'medicatie_nood') return Colors.red;
    if (section == 'wat_helpt') return Colors.teal;
    return Colors.grey;
  }

  IconData _sectionIcon(String section) {
    if (section.contains('vroeg')) return Icons.warning_amber;
    if (section.contains('ernstig')) return Icons.emergency;
    if (section == 'contacten') return Icons.contacts;
    if (section == 'medicatie_nood') return Icons.medication;
    if (section == 'wat_helpt') return Icons.favorite;
    return Icons.assignment;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(backgroundColor: AppTheme.primaryTeal, title: const Text('Crisisplan', style: TextStyle(color: Colors.white))),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        title: const Text('Crisisplan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sections.length,
        itemBuilder: (context, i) {
          final section = _sections[i];
          final title = _getTitle(section['section'] as String);
          final content = section['content'] as String? ?? '';
          final hasContent = content.isNotEmpty;
          final color = _sectionColor(section['section'] as String);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: hasContent ? 2 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: hasContent ? color.withValues(alpha: 0.3) : Colors.grey.shade200),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _editSection(section),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_sectionIcon(section['section'] as String), color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textCharcoal)),
                          const SizedBox(height: 4),
                          Text(
                            hasContent ? _truncate(content, 80) : 'Nog niet ingevuld — tik om te bewerken',
                            style: TextStyle(fontSize: 13, color: hasContent ? Colors.grey[700] : Colors.grey[400], fontStyle: hasContent ? FontStyle.normal : FontStyle.italic),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit, color: Colors.grey[400], size: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _truncate(String text, int maxLen) {
    return text.length > maxLen ? '${text.substring(0, maxLen)}...' : text;
  }
}
