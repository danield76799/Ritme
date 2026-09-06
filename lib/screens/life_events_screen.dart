import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../service_locator.dart';
import '../generated/l10n/app_localizations.dart';

/// Life Events overzicht + toevoegen.
/// (Vervangt het oude EventScreen: zelfde toevoeg-formulier, nu als FAB.)
class LifeEventsScreen extends StatefulWidget {
  const LifeEventsScreen({super.key});

  @override
  State<LifeEventsScreen> createState() => _LifeEventsScreenState();
}

class _LifeEventsScreenState extends State<LifeEventsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _events = [];
  String _filter = 'alle'; // 'alle', 'positief', 'negatief'

  final TextEditingController _omschrijvingController = TextEditingController();
  double _invloedWaarde = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _omschrijvingController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final events = await db.getAllLifeEvents();
      // Sort by date descending
      events.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));

      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredEvents {
    if (_filter == 'alle') return _events;
    if (_filter == 'positief') {
      return _events.where((e) {
        final invloed = e['invloed'] is int ? e['invloed'] as int : int.tryParse(e['invloed']?.toString() ?? '0') ?? 0;
        return invloed > 0;
      }).toList();
    }
    if (_filter == 'negatief') {
      return _events.where((e) {
        final invloed = e['invloed'] is int ? e['invloed'] as int : int.tryParse(e['invloed']?.toString() ?? '0') ?? 0;
        return invloed < 0;
      }).toList();
    }
    return _events;
  }

  Color _getImpactColor(int invloed) {
    if (invloed > 0) return Colors.green;
    if (invloed < 0) return Colors.redAccent;
    return Colors.grey;
  }

  String _getImpactLabel(BuildContext context, int invloed) {
    final l10n = AppLocalizations.of(context);
    if (invloed >= 3) return l10n.uiterstPositief;
    if (invloed >= 1) return l10n.positief;
    if (invloed == 0) return l10n.neutraal;
    if (invloed >= -2) return l10n.negatief;
    return l10n.uiterstNegatief;
  }

  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _opslaan() async {
    if (_omschrijvingController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).vulEerstKorteOmschrijving),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await db.insertLifeEvent(_todayDate, _omschrijvingController.text.trim(), _invloedWaarde.toInt());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).gebeurtenisOpgeslagen),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );

      _omschrijvingController.clear();
      setState(() => _invloedWaarde = 0);
      _loadData(); // Herlaad de lijst
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).konGebeurtenisOpslaanProbeer),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAddEventDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    AppLocalizations.of(context).nieuweGebeurtenis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _omschrijvingController,
                maxLines: 3,
                style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).bijvGoedGesprekGehad,
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryTeal, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context).invloedOpStemming,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal,
                ),
              ),
              const SizedBox(height: 8),
              Slider(
                value: _invloedWaarde,
                min: -4,
                max: 4,
                divisions: 8,
                label: _getImpactLabel(context, _invloedWaarde.toInt()),
                onChanged: (value) {
                  setModalState(() => _invloedWaarde = value);
                },
              ),
              Center(
                child: Text(
                  _getImpactLabel(context, _invloedWaarde.toInt()),
                  style: TextStyle(
                    color: _getImpactColor(_invloedWaarde.toInt()),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          await _opslaan();
                          if (mounted && context.mounted) Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.surface, strokeWidth: 2),
                        )
                      : Text(AppLocalizations.of(context).opslaan, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context).lifeEvents,
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                _buildFilterChip('alle', AppLocalizations.of(context).alle),
                const SizedBox(width: 8),
                _buildFilterChip('positief', AppLocalizations.of(context).positief),
                const SizedBox(width: 8),
                _buildFilterChip('negatief', AppLocalizations.of(context).negatief),
              ],
            ),
          ),

          // Events list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
                : _filteredEvents.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredEvents.length,
                        itemBuilder: (context, index) {
                          return _buildEventCard(_filteredEvents[index]);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEventDialog,
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          AppLocalizations.of(context).nieuweGebeurtenis,
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _filter = value);
      },
      selectedColor: AppTheme.primaryTeal,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final invloed = event['invloed'] is int ? event['invloed'] as int : int.tryParse(event['invloed']?.toString() ?? '0') ?? 0;
    final date = event['date'] as String? ?? '-';
    final omschrijving = event['omschrijving'] as String? ?? 'Geen beschrijving';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _getImpactColor(invloed).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              invloed > 0 ? Icons.sentiment_satisfied : invloed < 0 ? Icons.sentiment_dissatisfied : Icons.sentiment_neutral,
              color: _getImpactColor(invloed),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  omschrijving,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textCharcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getImpactColor(invloed).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getImpactLabel(context, invloed),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getImpactColor(invloed),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).geenGebeurtenissenGevonden,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).voegEersteGebeurtenisToe,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}