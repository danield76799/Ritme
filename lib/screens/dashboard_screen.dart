import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = DatabaseHelper.instance;
  Map<String, dynamic>? _settings;
  bool _isLoading = true;

  // Kleuren uit huisstijl
  final Color primaryTeal = const Color(0xFF4FB2C1);
  final Color textCharcoal = const Color(0xFF333333);
  final Color backgroundColor = const Color(0xFFFAFAFA);

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupNotifications();
  }

  Future<void> _loadData() async {
    final settings = await _db.getSettings();

    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }

  Future<void> _setupNotifications() async {
    await NotificationService().requestPermissions();
    
    // Schedule daily mood check reminder at 20:00
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, 20, 0);
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    
    await NotificationService().showDailyReminder(
      id: 1,
      title: 'Dagelijkse check',
      body: 'Hoe was je dag? Registreer je stemming en activiteiten.',
      scheduledDate: scheduledTime,
    );
    
    // Schedule morning routine reminder at 08:00
    var morningTime = DateTime(now.year, now.month, now.day, 8, 0);
    if (morningTime.isBefore(now)) {
      morningTime = morningTime.add(const Duration(days: 1));
    }
    
    await NotificationService().showDailyReminder(
      id: 2,
      title: 'Goedemorgen!',
      body: 'Start je dag met een positief ritme. Registreer je stemming.',
      scheduledDate: morningTime,
    );
  }

  Future<void> _logout() async {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final today = DateTime.now();
    final dateStr = '${today.day}/${today.month}/${today.year}';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryTeal,
        elevation: 0,
        title: const Text(
          'Ritme',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/statistics');
            },
            tooltip: 'Statistieken',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Uitloggen',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- WELKOMST BANNER ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryTeal,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hallo, ${_settings?['username'] ?? 'gebruiker'}!',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildTimeChip(Icons.wb_sunny_outlined, 'Opstaan', _settings?['target_wake_time'] ?? '07:00'),
                        const SizedBox(width: 12),
                        _buildTimeChip(Icons.nightlight_round, 'Slapen', _settings?['target_sleep_time'] ?? '23:00'),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // --- VANDAAG SECTIE ---
              Text(
                'Vandaag',
                style: TextStyle(color: textCharcoal, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Grid met de 4 knoppen
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                childAspectRatio: 1.2,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildActionCard(
                    context, 
                    icon: Icons.sentiment_satisfied_alt, 
                    iconColor: Colors.orange, 
                    title: 'Stemming', 
                    subtitle: 'Dagelijkse check',
                    route: '/mood',
                  ),
                  _buildActionCard(
                    context, 
                    icon: Icons.directions_walk, 
                    iconColor: Colors.green, 
                    title: 'Activiteit', 
                    subtitle: 'SRM meting',
                    route: '/activity',
                  ),
                  _buildActionCard(
                    context, 
                    icon: Icons.medication_outlined, 
                    iconColor: Colors.redAccent, 
                    title: 'Medicatie', 
                    subtitle: 'Inname loggen',
                    route: '/medication',
                  ),
                  _buildActionCard(
                    context, 
                    icon: Icons.calendar_today_outlined, 
                    iconColor: Colors.purpleAccent, 
                    title: 'Gebeurtenis', 
                    subtitle: 'Life chart',
                    route: '/event',
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // --- OVERZICHT SECTIE ---
              Text(
                'Overzicht',
                style: TextStyle(color: textCharcoal, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              _buildOverviewCard(
                icon: Icons.show_chart,
                title: 'Slaapkwaliteit',
                value: '7.2',
                unit: '/10',
                color: Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildOverviewCard(
                icon: Icons.schedule,
                title: 'Ritme stabiliteit',
                value: '82',
                unit: '%',
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              _buildOverviewCard(
                icon: Icons.local_activity,
                title: 'Activiteiten deze week',
                value: '24',
                unit: '',
                color: Colors.orange,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showNotImplemented('Nieuwe dagelijkse log');
        },
        backgroundColor: primaryTeal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTimeChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {
    required IconData icon, 
    required Color iconColor, 
    required String title, 
    required String subtitle, 
    required String route,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, route);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textCharcoal),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard({
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    text: value,
                    style: TextStyle(color: textCharcoal, fontSize: 20, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(text: ' $unit', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.normal)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
        ],
      ),
    );
  }

  void _showNotImplemented(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Binnenkort beschikbaar'),
        content: Text('$feature wordt in een volgende update toegevoegd.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}