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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final sections = await db.getCrisisPlan();

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

  String _getTitle(String? section) {
    if (section == null) return 'Onbekende sectie';
    for (final def in _defaultSections) {
      if (def['section'] == section) return def['title'] ?? section;
    }
    return section;
  }

  String _getHint(String? section) {
    if (section == null) return '';
    for (final def in _defaultSections) {
      if (def['section'] == section) return def['hint'] ?? '';
    }
    return '';
  }

  void _editSection(Map<String, dynamic> section) {
    final sectionKey = section['section'] as String?;
    final controller = TextEditingController(text: section['content'] as String? ?? '');
    final title = _getTitle(sectionKey);
    final hint = _getHint(sectionKey);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hint,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark 
                        ? const Color(0xFF2C2C2C) 
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.grey.shade700 
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    hintText: 'Schrijf hier je plan...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final id = section['id'];
                    if (id != null) {
                      await db.updateCrisisPlanSection(id as int, {'content': controller.text});
                      _loadData();
                    }
                    if (mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Opslaan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _sectionColor(String? section) {
    if (section == null) return Colors.grey;
    if (section.startsWith('manie')) return Colors.orange;
    if (section.startsWith('depressie')) return Colors.blue;
    if (section == 'gemengd') return Colors.amber.shade700;
    if (section == 'contacten') return Colors.green;
    if (section == 'medicatie_nood') return Colors.red;
    if (section == 'wat_helpt') return Colors.teal;
    return Colors.grey;
  }

  IconData _sectionIcon(String? section) {
    if (section == null) return Icons.assignment;
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Crisisplan'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: const Text('Crisisplan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Snel toevoegen',
            onPressed: () => _showAddSectionDialog(),
          ),
        ],
      ),
      body: _sections.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment, size: 64, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'Nog geen crisisplan',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _sections.length,
              itemBuilder: (context, i) {
                final section = _sections[i];
                final sectionKey = section['section'] as String?;
                final title = _getTitle(sectionKey);
                final content = section['content'] as String? ?? '';
                final hasContent = content.isNotEmpty;
                final color = _sectionColor(sectionKey);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: hasContent ? color.withOpacity(0.5) : Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
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
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(_sectionIcon(sectionKey), color: color),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hasContent ? _truncate(content, 100) : 'Nog niet ingevuld — tik om te bewerken',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: hasContent ? Colors.grey.shade700 : Colors.grey.shade400,
                                    fontStyle: hasContent ? FontStyle.normal : FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
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

  void _showAddSectionDialog() {
    final existingSections = _sections.map((s) => s['section'] as String).toSet();
    final availableDefaults = _defaultSections.where((d) => !existingSections.contains(d['section'])).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Sectie toevoegen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (availableDefaults.isEmpty)
              const Text('Alle standaard secties zijn al toegevoegd.')
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: availableDefaults.map((def) => ListTile(
                    leading: Icon(_sectionIcon(def['section'] as String?), color: _sectionColor(def['section'] as String?)),
                    title: Text(def['title'] as String),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await db.insertCrisisPlanSection({
                        'section': def['section'],
                        'content': '',
                        'sort_order': _sections.length,
                      });
                      _loadData();
                    },
                  )).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
