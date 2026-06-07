import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryTeal, AppTheme.primaryTeal.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ritme',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'SRT Tracker',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildSectionTitle('Dagelijkse Tracking'),
                  _buildMenuItem(
                    context,
                    icon: Icons.sentiment_satisfied_alt,
                    title: 'Stemming',
                    route: '/mood',
                    color: Colors.orange,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.directions_walk,
                    title: 'Activiteit + Slaap',
                    route: '/activity',
                    color: Colors.green,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.medication_outlined,
                    title: 'Medicatie',
                    route: '/medication',
                    color: Colors.redAccent,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.monitor_weight,
                    title: 'Gewicht',
                    route: '/weight',
                    color: Colors.blueAccent,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.calendar_today_outlined,
                    title: 'Afspraken',
                    route: '/appointments',
                    color: Colors.purpleAccent,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.schedule,
                    title: 'Sociaal Ritme',
                    route: '/sociaal-ritme',
                    color: Colors.teal,
                  ),

                  const Divider(height: 32),
                  _buildSectionTitle('Inzichten'),
                  _buildMenuItem(
                    context,
                    icon: Icons.insights,
                    title: 'Inzichten & Patronen',
                    route: '/insights',
                    color: Colors.teal,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.bar_chart,
                    title: 'Statistieken',
                    route: '/statistics',
                    color: Colors.blue,
                  ),

                  const Divider(height: 32),
                  _buildSectionTitle('Instellingen'),
                  _buildMenuItem(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'Instellingen',
                    route: '/settings',
                    color: Colors.grey.shade700!,
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Ritme v1.2.0',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    required Color color,
  }) {
    final isSelected = currentRoute == route;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: color,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.textCharcoal : Colors.grey.shade700,
        ),
      ),
      trailing: isSelected
          ? Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal,
                borderRadius: BorderRadius.circular(2),
              ),
            )
          : null,
      onTap: () {
        Navigator.pop(context); // Close drawer
        if (currentRoute != route) {
          Navigator.pushNamed(context, route);
        }
      },
    );
  }
}
