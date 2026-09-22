import 'package:flutter/material.dart';

import '../generated/l10n/app_localizations.dart';
import '../service_locator.dart';
import '../theme/app_theme.dart';

/// Het crisisplan.
///
/// Dit scherm wordt in een noodsituatie geopend, dus de inhoud moet in één
/// oogopslag leesbaar zijn. Kaarten tonen daarom de volledige tekst en niet
/// langer een afgekapte preview: eerder was de inhoud tot 80 tekens / 2 regels
/// ingekort, waardoor het plan pas zichtbaar werd ná het openen van de
/// bewerksheet. Dat is precies verkeerd om bij een crisisplan.
class CrisisPlanScreen extends StatefulWidget {
  const CrisisPlanScreen({super.key});

  @override
  State<CrisisPlanScreen> createState() => _CrisisPlanScreenState();
}

/// Standaardsectie met de bijbehorende vertaalsleutels.
///
/// De titels en hints stonden eerder hardcoded in het Engels in dit bestand,
/// terwijl de ARB-keys allang bestonden. Hierdoor bleef het scherm Engelstalig
/// op een Nederlandse telefoon.
class _SectionDef {
  final String section;
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations) hint;

  const _SectionDef(this.section, this.title, this.hint);
}

final List<_SectionDef> _defaultSections = [
  _SectionDef('manie_vroeg', (l) => l.manieVroegTitle, (l) => l.manieVroegHint),
  _SectionDef('manie_ernstig', (l) => l.manieErnstigTitle, (l) => l.manieErnstigHint),
  _SectionDef('depressie_vroeg', (l) => l.depressieVroegTitle, (l) => l.depressieVroegHint),
  _SectionDef('depressie_ernstig', (l) => l.depressieErnstigTitle, (l) => l.depressieErnstigHint),
  _SectionDef('gemengd', (l) => l.gemengdTitle, (l) => l.gemengdHint),
  _SectionDef('contacten', (l) => l.contactenTitle, (l) => l.contactenHint),
  _SectionDef('medicatie_nood', (l) => l.medicatieNoodTitle, (l) => l.medicatieNoodHint),
  _SectionDef('wat_helpt', (l) => l.watHelptTitle, (l) => l.watHelptHint),
];

/// Wat een kaart moet tonen: titel, (volledige) tekst en of het eigen invoer is.
class _SectionDisplay {
  final String title;
  final String body;
  final bool isCustom;
  final bool isPlaceholderHint;

  const _SectionDisplay({
    required this.title,
    required this.body,
    required this.isCustom,
    required this.isPlaceholderHint,
  });
}

class _CrisisPlanScreenState extends State<CrisisPlanScreen> {
  List<Map<String, dynamic>> _sections = [];
  bool _isLoading = true;

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
      final existing = sections.map((s) => s['section']).toSet();
      for (int i = 0; i < _defaultSections.length; i++) {
        if (!existing.contains(_defaultSections[i].section)) {
          await db.insertCrisisPlanSection({
            'section': _defaultSections[i].section,
            'content': '',
            'sort_order': i,
          });
        }
      }
      final reloaded = await db.getCrisisPlan();
      if (mounted) {
        setState(() {
          _sections = reloaded;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  _SectionDisplay _displayInfo(Map<String, dynamic> section) {
    final l10n = AppLocalizations.of(context);
    final key = section['section'] as String? ?? '';
    final content = (section['content'] as String? ?? '').trim();

    for (final def in _defaultSections) {
      if (def.section == key) {
        return _SectionDisplay(
          title: def.title(l10n),
          // Gevuld: de volledige tekst. Leeg: de hint als geheugensteun.
          body: content.isNotEmpty ? content : def.hint(l10n),
          isCustom: false,
          isPlaceholderHint: content.isEmpty,
        );
      }
    }

    // Eigen sectie: de eerste regel is de titel, de rest is de inhoud.
    if (content.isEmpty) {
      return _SectionDisplay(
        title: l10n.eigenSectie,
        body: l10n.tikOmTeBewerken,
        isCustom: true,
        isPlaceholderHint: true,
      );
    }
    final lines = content.split('\n');
    final title = lines.first.trim();
    final rest = lines.skip(1).join('\n').trim();
    return _SectionDisplay(
      title: title.isNotEmpty ? title : l10n.eigenSectie,
      body: rest.isNotEmpty ? rest : l10n.tikOmTeBewerken,
      isCustom: true,
      isPlaceholderHint: rest.isEmpty,
    );
  }

  void _editSection(Map<String, dynamic> section) {
    final sectionKey = section['section'] as String;
    final controller =
        TextEditingController(text: section['content'] as String? ?? '');
    final info = _displayInfo(section);
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
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
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                info.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (info.isCustom)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    AppLocalizations.of(context).tipEersteRegel,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: brightness == Brightness.dark
                        ? AppTheme.darkCard
                        : theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                      borderSide:
                          BorderSide(color: theme.colorScheme.primary, width: 2),
                    ),
                    hintText: info.isCustom
                        ? '${AppLocalizations.of(context).titel}\n${AppLocalizations.of(context).beschrijving}'
                        : AppLocalizations.of(context).schrijfHierJePlan,
                    hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
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
                    await db.updateCrisisPlanSectionBySection(
                        sectionKey, {'content': controller.text});
                    _loadData();
                    if (mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).opslaan,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _sectionColor(String? section, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    if (section == null) return dark ? Colors.grey.shade400 : Colors.grey;
    if (section.startsWith('manie')) {
      return dark ? const Color(0xFFFFB74D) : Colors.orange.shade800;
    }
    if (section.startsWith('depressie')) {
      return dark ? const Color(0xFF64B5F6) : Colors.blue.shade800;
    }
    if (section == 'gemengd') {
      return dark ? const Color(0xFFFFD54F) : Colors.amber.shade800;
    }
    if (section == 'contacten') {
      return dark ? const Color(0xFF81C784) : Colors.green.shade800;
    }
    if (section == 'medicatie_nood') {
      return dark ? const Color(0xFFE57373) : Colors.red.shade800;
    }
    if (section == 'wat_helpt') {
      return dark ? const Color(0xFF4DB6AC) : Colors.teal.shade800;
    }
    return dark ? const Color(0xFF90A4AE) : Colors.blueGrey.shade700;
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: Text(l10n.crisisplan)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Text(l10n.crisisplan),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.snelToevoegen,
            onPressed: () => _showAddSectionDialog(),
          ),
        ],
      ),
      body: _sections.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment,
                      size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    l10n.nogGeenCrisisplan,
                    style: TextStyle(
                        fontSize: 18, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.screenPadding, 16, AppTheme.screenPadding, 40),
              itemCount: _sections.length,
              itemBuilder: (context, i) {
                final section = _sections[i];
                final info = _displayInfo(section);
                final sectionKey = section['section'] as String?;
                final hasContent =
                    (section['content'] as String? ?? '').trim().isNotEmpty;
                final color = _sectionColor(sectionKey, theme.brightness);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: hasContent
                          ? color.withValues(alpha: 0.5)
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _editSection(section),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                            ),
                            child: Icon(_sectionIcon(sectionKey),
                                color: color, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  info.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    height: 1.25,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Geen maxLines/ellipsis meer: het hele plan
                                // moet leesbaar zijn zonder erop te tikken.
                                Text(
                                  info.body,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.4,
                                    color: info.isPlaceholderHint
                                        ? theme.colorScheme.onSurfaceVariant
                                        : theme.colorScheme.onSurface,
                                    fontStyle: info.isPlaceholderHint
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.edit_outlined,
                              color: theme.colorScheme.outline, size: 18),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddSectionDialog() {
    final existingSections =
        _sections.map((s) => s['section'] as String).toSet();
    final availableDefaults = _defaultSections
        .where((d) => !existingSections.contains(d.section))
        .toList();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
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
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.sectieToevoegen,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ...availableDefaults.map((def) {
                    final c = _sectionColor(def.section, theme.brightness);
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                        ),
                        child: Icon(_sectionIcon(def.section), color: c, size: 20),
                      ),
                      title: Text(
                        def.title(l10n),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await db.insertCrisisPlanSection({
                          'section': def.section,
                          'content': '',
                          'sort_order': _sections.length,
                        });
                        _loadData();
                      },
                    );
                  }),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                      ),
                      child: const Icon(Icons.add, color: Colors.blueGrey, size: 20),
                    ),
                    title: Text(l10n.eigenSectieMaken,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCustomSectionDialog();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomSectionDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
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
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.eigenSectieMaken,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: l10n.titel,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: contentController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: l10n.beschrijving,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;
                    await db.insertCrisisPlanSection({
                      'section': 'custom_${DateTime.now().millisecondsSinceEpoch}',
                      'content':
                          '${titleController.text.trim()}\n\n${contentController.text.trim()}',
                      'sort_order': 999,
                    });
                    _loadData();
                    if (mounted) Navigator.pop(ctx);
                  },
                  child: Text(l10n.toevoegen,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
