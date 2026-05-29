import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../service_locator.dart';

class LifeEventsScreen extends StatefulWidget {
  const LifeEventsScreen({super.key});

  @override
  State<LifeEventsScreen> createState() => _LifeEventsScreenState();
}

class _LifeEventsScreenState extends State<LifeEventsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _events = [];
  String _filter = 'alle'; // 'alle', 'positief', 'negatief'

  @override
  void initState() {
    super.initState();
    _loadData();
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
    if (_filter == 'positief') return _events.where((e) => (e['invloed'] ?? 0) > 0).toList();
    if (_filter == 'negatief') return _events.where((e) => (e['invloed'] ?? 0) < 0).toList();
    return _events;
  }

  Color _getImpactColor(int invloed) {
    if (invloed > 0) return Colors.green;
    if (invloed < 0) return Colors.redAccent;
    return Colors.grey;
  }

  String _getImpactLabel(int invloed) {
    if (invloed >= 3) return 'Uiterst positief';
    if (invloed >= 1) return 'Positief';
    if (invloed == 0) return 'Neutraal';
    if (invloed >= -2) return 'Negatief';
    return 'Uiterst negatief';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        title: const Text(
          'Life Events',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
            color: Colors.white,
            child: Row(
              children: [
                _buildFilterChip('alle', 'Alle'),
                const SizedBox(width: 8),
                _buildFilterChip('positief', 'Positief'),
                const SizedBox(width: 8),
                _buildFilterChip('negatief', 'Negatief'),
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
        color: isSelected ? Colors.white : Colors.grey.shade600,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final invloed = event['invloed'] as int? ?? 0;
    final date = event['date'] as String? ?? '-';
    final omschrijving = event['omschrijving'] as String? ?? 'Geen beschrijving';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textCharcoal,
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
                    _getImpactLabel(invloed),
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
            'Geen life events gevonden',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Voeg belangrijke gebeurtenissen toe via het dashboard',
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
