import 'package:flutter/material.dart';
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
    {'section': 'manie_vroeg', 'title': '⚠️ Bij eerste tekenen van manie/hypomanie', 'hint': 'Bijv: contact opnemen met behandelaar, medicatie ophogen, prikkels vermijden...'},
    {'section': 'manie_ernstig', 'title': '🚨 Bij ernstige manie (noodsituatie)', 'hint': 'Bijv: crisisdienst bellen, contactpersoon waarschuwen, naar SEH gaan...'},
    {'section': 'depressie_vroeg', 'title': '🔵 Bij eerste tekenen van depressie', 'hint': 'Bijv: dagstructuur vasthouden, kleine doelen stellen, sociale contacten...'},
    {'section': 'depressie_ernstig', 'title': '🚨 Bij ernstige depressie / suïcidale gedachten', 'hint': 'Bijv: 113 bellen, crisisdienst, vertrouwenspersoon, niet alleen blijven...'},
    {'section': 'gemengd', 'title': '🟡 Bij gemengde episode', 'hint': 'Bijv: extra voorzichtig met medicatie, geen impulsieve beslissingen...'},
    {'section': 'contacten', 'title': '📞 Belangrijke contacten', 'hint': 'Bijv: behandelaar, partner, crisisdienst, 113...'},
    {'section': 'medicatie_nood', 'title': '💊 Medicatie noodplan', 'hint': 'Bijv: welke medicatie ophogen bij manie/depressie...'},
    {'section': 'wat_helpt', 'title': '💚 Wat helpt mij', 'hint': 'Bijv: wandelen, muziek, douchen, met vriend(in) praten...'},
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
      print('DB DEBUG: getCrisisPlan returned ${sections.length} sections');
      if (sections.isEmpty) {
        print('DB DEBUG: Creating default sections');
        for (var i = 0; i < _defaultSections.length; i++) {
          await db.insertCrisisPlanSection({'section': _defaultSections[i]['section'], 'content': '', 'sort_order': i});
        }
        final reloaded = await db.getCrisisPlan();
        if (mounted) setState(() { _sections = reloaded; _isLoading = false; });
      } else {
        for (final def in _defaultSections) {
          if (!sections.any((s) => s['section'] == def['section'])) {
            print('DB DEBUG: Adding missing default: ${def['section']}');
            await db.insertCrisisPlanSection({'section': def['section'], 'content': '', 'sort_order': _defaultSections.indexOf(def)});
          }
        }
        final reloaded = await db.getCrisisPlan();
        if (mounted) setState(() { _sections = reloaded; _isLoading = false; });
      }
    } catch (e) {
      print('DB DEBUG: Error in _loadData: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _getDisplayInfo(Map<String, dynamic> section) {
    final key = section['section'] as String? ?? '';
    final content = section['content'] as String? ?? '';
    for (final def in _defaultSections) {
      if (def['section'] == key) return [def['title'] ?? key, content.isNotEmpty ? content : 'Nog niet ingevuld — tik om te bewerken', false];
    }
    if (content.isEmpty) return ['Eigen sectie', 'Tik om te bewerken', true];
    final lines = content.split('\n');
    final title = lines[0].trim();
    String subtitle = '';
    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim().isNotEmpty) { subtitle = lines[i].trim(); break; }
    }
    return [title, subtitle.isNotEmpty ? subtitle : 'Tik om te bewerken', true];
  }

  void _editSection(Map<String, dynamic> section) {
    final controller = TextEditingController(text: section['content'] as String? ?? '');
    final info = _getDisplayInfo(section);
    final displayTitle = info[0] as String;
    final isCustom = info[2] as bool;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(isCustom ? 'Bewerk eigen sectie' : displayTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              if (isCustom) const Padding(padding: EdgeInsets.only(top: 4), child: Text('Tip: de eerste regel wordt de titel in het overzicht.', style: TextStyle(fontSize: 12, color: Colors.grey))),
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
                    fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade700 : Colors.grey.shade300, width: 1)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                    hintText: isCustom ? 'Titel\n\nBeschrijving...' : 'Schrijf hier je plan...',
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
                    final idRaw = section['id'];
                    print('DEBUG: section ID = $idRaw (type: ${idRaw.runtimeType})');
                    int? id = idRaw is int ? idRaw : (idRaw is String ? int.tryParse(idRaw) : null);
                    if (id == null) {
                      if (mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Fout: kan sectie niet updaten - probeer opnieuw')));
                      return;
                    }
                    try {
                      print('DEBUG: Update met ID = $id');
                      await db.updateCrisisPlanSection(id, {'content': controller.text});
                      print('DEBUG: Update succesvol');
                      _loadData();
                      if (mounted) Navigator.pop(ctx);
                    } catch (e) {
                      print('DEBUG: Update faalde: $e');
                      if (mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Fout bij opslaan: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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
    return Colors.blueGrey;
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
    if (_isLoading) return Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor, appBar: AppBar(title: const Text('Crisisplan')), body: const Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(elevation: 0, title: const Text('Crisisplan'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)), actions: [IconButton(icon: const Icon(Icons.add), tooltip: 'Snel toevoegen', onPressed: () => _showAddSectionDialog())]),
      body: _sections.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.assignment, size: 64, color: Colors.grey.withOpacity(0.5)), const SizedBox(height: 16), const Text('Nog geen crisisplan', style: TextStyle(fontSize: 18, color: Colors.grey))]))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _sections.length,
              itemBuilder: (context, i) {
                final section = _sections[i];
                final info = _getDisplayInfo(section);
                final title = info[0] as String;
                final subtitle = info[1] as String;
                final sectionKey = section['section'] as String?;
                final hasContent = (section['content'] as String? ?? '').isNotEmpty;
                final color = _sectionColor(sectionKey);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: hasContent ? color.withOpacity(0.5) : Colors.grey.withOpacity(0.2), width: 1)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _editSection(section),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(_sectionIcon(sectionKey), color: color)),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), const SizedBox(height: 4), Text(_truncate(subtitle, 80), style: TextStyle(fontSize: 13, color: hasContent ? Colors.grey.shade700 : Colors.grey.shade400, fontStyle: hasContent ? FontStyle.normal : FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis)])),
                          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _truncate(String text, int maxLen) => text.length > maxLen ? '${text.substring(0, maxLen)}...' : text;

  void _showAddSectionDialog() {
    final existingSections = _sections.map((s) => s['section'] as String).toSet();
    final availableDefaults = _defaultSections.where((d) => !existingSections.contains(d['section'])).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Sectie toevoegen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Flexible(child: ListView(shrinkWrap: true, children: [
            ...availableDefaults.map((def) => ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _sectionColor(def['section'] as String).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(_sectionIcon(def['section'] as String), color: _sectionColor(def['section'] as String), size: 20)),
              title: Text(def['title'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
              onTap: () async {
                Navigator.pop(ctx);
                await db.insertCrisisPlanSection({'section': def['section'], 'content': '', 'sort_order': _sections.length});
                _loadData();
              },
            )),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.add, color: Colors.blueGrey, size: 20)),
              title: const Text('Eigen sectie maken', style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () { Navigator.pop(ctx); _showCustomSectionDialog(); },
            ),
          ])),
        ]),
      ),
    );
  }

  void _showCustomSectionDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Eigen sectie maken', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: titleController, decoration: InputDecoration(labelText: 'Titel', filled: true, fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 16),
            Expanded(child: TextField(controller: contentController, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top, decoration: InputDecoration(hintText: 'Beschrijving...', filled: true, fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                await db.insertCrisisPlanSection({'section': 'custom_${DateTime.now().millisecondsSinceEpoch}', 'content': '${titleController.text.trim()}\n\n${contentController.text.trim()}', 'sort_order': 999});
                _loadData();
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('Toevoegen', style: TextStyle(fontWeight: FontWeight.bold)),
            )),
          ]),
        ),
      ),
    );
  }
}
