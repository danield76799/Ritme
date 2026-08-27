import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../service_locator.dart';
import '../generated/l10n/app_localizations.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({super.key});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _filteredEvents = [];
  bool _isLoading = true;
  String _filter = 'Alle';

  final TextEditingController _omschrijvingController = TextEditingController();
  double _invloedWaarde = 0;
  bool _isSaving = false;

  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      // Haal alle events op van alle dagen
      final allDbEvents = await db.getAllLifeEvents();
      
      // Sorteer op datum (nieuwste eerst)
      allDbEvents.sort((a, b) {
        final dateA = a['date']?.toString() ?? '';
        final dateB = b['date']?.toString() ?? '';
        return dateB.compareTo(dateA);
      });
      
      setState(() {
        _events = allDbEvents;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    if (_filter == 'Alle') {
      _filteredEvents = List.from(_events);
    } else if (_filter == 'Positief') {
      _filteredEvents = _events.where((e) {
        final invloed = e['invloed'] is int ? e['invloed'] as int : int.tryParse(e['invloed']?.toString() ?? '0') ?? 0;
        return invloed > 0;
      }).toList();
    } else if (_filter == 'Negatief') {
      _filteredEvents = _events.where((e) {
        final invloed = e['invloed'] is int ? e['invloed'] as int : int.tryParse(e['invloed']?.toString() ?? '0') ?? 0;
        return invloed < 0;
      }).toList();
    }
  }

  void _setFilter(String filter) {
    setState(() {
      _filter = filter;
      _applyFilter();
    });
  }

  Color _getKleur(int invloed) {
    if (invloed > 0) return Colors.green;
    if (invloed < 0) return Colors.orange;
    return AppTheme.primaryTeal;
  }

  String _getLabel(BuildContext context, int invloed) {
    final l10n = AppLocalizations.of(context);
    if (invloed == 4) return l10n.uiterstPositief;
    if (invloed > 0) return l10n.positief;
    if (invloed == -4) return l10n.uiterstNegatief;
    if (invloed < 0) return l10n.negatief;
    return l10n.neutraal;
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}-${date.month}-${date.year}';
    } catch (e) {
      return dateStr;
    }
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
      _loadEvents(); // Herlaad de lijst
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).konGebeurtenisOpslaanProbeer),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).lifeEvents,
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadEvents,
            tooltip: AppLocalizations.of(context).verversen,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : Column(
              children: [
                // Filters
                Container(
                  padding: EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surface,
                  child: Row(
                    children: [
                      _buildFilterChip('Alle', _filter == 'Alle'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Positief', _filter == 'Positief'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Negatief', _filter == 'Negatief'),
                    ],
                  ),
                ),
                const Divider(height: 1),
                
                // Lijst van events
                Expanded(
                  child: _filteredEvents.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _filteredEvents.length,
                          itemBuilder: (context, index) {
                            final event = _filteredEvents[index];
                            final invloed = event['invloed'] is int 
                                ? event['invloed'] as int 
                                : int.tryParse(event['invloed']?.toString() ?? '0') ?? 0;
                            final omschrijving = event['omschrijving']?.toString() ?? '';
                            final date = event['date']?.toString() ?? '';
                            
                            return Container(
                              margin: EdgeInsets.only(bottom: 12),
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getKleur(invloed).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _getLabel(context, invloed),
                                          style: TextStyle(
                                            color: _getKleur(invloed),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _formatDate(date),
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    omschrijving,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEventDialog(),
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          AppLocalizations.of(context).nieuweGebeurtenis,
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _setFilter(label),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryTeal : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected)
                Icon(Icons.check, color: Theme.of(context).colorScheme.surface, size: 16),
              if (isSelected)
                SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
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
              fontSize: 16,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      color: Color(0xFF333333),
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),
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
                'Invloed op stemming:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 8),
              Slider(
                value: _invloedWaarde,
                min: -4,
                max: 4,
                divisions: 8,
                label: _getLabel(context, _invloedWaarde.toInt()),
                onChanged: (value) {
                  setModalState(() => _invloedWaarde = value);
                },
              ),
              Center(
                child: Text(
                  _getLabel(context, _invloedWaarde.toInt()),
                  style: TextStyle(
                    color: _getKleur(_invloedWaarde.toInt()),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving 
                      ? null 
                      : () async {
                          await _opslaan();
                          if (mounted) Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.surface, strokeWidth: 2),
                        )
                      : Text(AppLocalizations.of(context).opslaan, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}