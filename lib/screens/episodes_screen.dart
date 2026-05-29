import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../service_locator.dart';

class EpisodesScreen extends StatefulWidget {
  const EpisodesScreen({super.key});

  @override
  State<EpisodesScreen> createState() => _EpisodesScreenState();
}

class _EpisodesScreenState extends State<EpisodesScreen> {
  List<Map<String, dynamic>> _episodes = [];
  bool _isLoading = true;
  Map<String, dynamic>? _activeEpisode;

  final _types = [
    {'value': 'hypomanie', 'label': 'Hypomanie', 'icon': Icons.trending_up, 'color': Colors.orange},
    {'value': 'manie', 'label': 'Manie', 'icon': Icons.warning, 'color': Colors.red},
    {'value': 'depressie', 'label': 'Depressie', 'icon': Icons.trending_down, 'color': Colors.blue},
    {'value': 'gemengd', 'label': 'Gemengd', 'icon': Icons.compare_arrows, 'color': Colors.purple},
    {'value': 'euthym', 'label': 'Stabiel (euthym)', 'icon': Icons.check_circle, 'color': Colors.green},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final episodes = await db.getEpisodes();
      final active = await db.getActiveEpisode();
      if (mounted) {
        setState(() {
          _episodes = episodes;
          _activeEpisode = active;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddEpisode() {
    String? selectedType;
    final startController = TextEditingController(text: _todayDate);
    bool isActive = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('Nieuwe episode', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Type selector
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _types.map((t) {
                  final isSelected = selectedType == t['value'];
                  return ChoiceChip(
                    label: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(t['icon'] as IconData, size: 16, color: isSelected ? Colors.white : t['color'] as Color),
                      const SizedBox(width: 6),
                      Text(t['label'] as String),
                    ]),
                    selected: isSelected,
                    selectedColor: t['color'] as Color,
                    onSelected: (val) => setModalState(() => selectedType = val ? t['value'] as String : null),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Start date
              TextField(
                controller: startController,
                decoration: const InputDecoration(
                  labelText: 'Startdatum',
                  border: OutlineInputBorder(),
                  hintText: 'YYYY-MM-DD',
                ),
              ),
              const SizedBox(height: 12),

              // Active toggle
              SwitchListTile(
                title: const Text('Nog bezig'),
                value: isActive,
                onChanged: (val) => setModalState(() => isActive = val),
                activeThumbColor: AppTheme.primaryTeal,
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: selectedType == null ? null : () async {
                    await db.insertEpisode({
                      'start_date': startController.text,
                      'end_date': isActive ? null : DateTime.now().toIso8601String().split('T')[0],
                      'episode_type': selectedType,
                      'severity': 3,
                    });
                    Navigator.pop(ctx);
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Toevoegen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _endEpisode(int id) async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await db.endEpisode(id, dateStr);
    _loadData();
  }

  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '...';
    try {
      final d = DateTime.parse(dateStr);
      return '${d.day}-${d.month}-${d.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Map<String, dynamic>? _getTypeInfo(String type) {
    for (final t in _types) {
      if (t['value'] == type) return t;
    }
    return null;
  }

  String _durationText(String start, String? end) {
    try {
      final s = DateTime.parse(start);
      final e = end != null ? DateTime.parse(end) : DateTime.now();
      final days = e.difference(s).inDays;
      if (days == 0) return '1 dag';
      if (days < 7) return '$days dagen';
      final weeks = days ~/ 7;
      final remainder = days % 7;
      if (remainder == 0) return '$weeks weken';
      return '$weeks weken, $remainder dagen';
    } catch (e) {
      return '?';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(backgroundColor: AppTheme.primaryTeal, title: const Text('Episodes', style: TextStyle(color: Colors.white))),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        title: const Text('Episodes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEpisode,
        backgroundColor: AppTheme.primaryTeal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _episodes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timeline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('Nog geen episodes', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Tik + om je eerste episode bij te houden', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _episodes.length,
              itemBuilder: (context, i) {
                final ep = _episodes[i];
                final type = ep['episode_type'] as String;
                final typeInfo = _getTypeInfo(type);
                final isActive = ep['end_date'] == null;
                final color = typeInfo?['color'] as Color? ?? Colors.grey;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isActive ? 0.2 : 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(typeInfo?['icon'] as IconData?, color: color, size: 24),
                    ),
                    title: Row(
                      children: [
                        Text(typeInfo?['label'] as String? ?? type, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textCharcoal)),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                            child: Text('actief', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      '${_formatDate(ep['start_date'] as String)} — ${isActive ? "loopt nog" : _formatDate(ep['end_date'] as String)}\n${_durationText(ep['start_date'] as String, ep['end_date'] as String?)}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    isThreeLine: true,
                    trailing: isActive
                        ? IconButton(
                            icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
                            tooltip: 'Episode beëindigen',
                            onPressed: () => _endEpisode(ep['id'] as int),
                          )
                        : null,
                    onLongPress: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Verwijderen?'),
                          content: const Text('Deze episode definitief verwijderen?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Verwijderen', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await db.deleteEpisode(ep['id'] as int);
                        _loadData();
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
