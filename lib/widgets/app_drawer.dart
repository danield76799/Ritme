import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_theme.dart';
import '../generated/l10n/app_localizations.dart';

class AppDrawer extends StatefulWidget {
  final String currentRoute;

  const AppDrawer({
    super.key,
    required this.currentRoute,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = 'Ritme v${info.version}+${info.buildNumber}');
    } catch (e) {
      if (mounted) setState(() => _version = 'Ritme');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(24),
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
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ritme',
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'SRT Tracker',
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
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
                  _buildSectionTitle(AppLocalizations.of(context).dagelijkseTracking),
                  _buildMenuItem(
                    context,
                    icon: Icons.sentiment_satisfied_alt,
                    title: AppLocalizations.of(context).stemming,
                    route: '/mood',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.directions_walk,
                    title: AppLocalizations.of(context).activiteitSlaap,
                    route: '/activity',
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.medication_outlined,
                    title: AppLocalizations.of(context).medicatie,
                    route: '/medication',
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.monitor_weight,
                    title: AppLocalizations.of(context).gewicht,
                    route: '/weight',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.calendar_today_outlined,
                    title: AppLocalizations.of(context).afspraken,
                    route: '/appointments',
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.schedule,
                    title: AppLocalizations.of(context).sociaalRitme,
                    route: '/sociaal-ritme',
                    color: Theme.of(context).colorScheme.tertiary,
                  ),

                  const Divider(height: 32),
                  _buildSectionTitle(AppLocalizations.of(context).inzichten),
                  _buildMenuItem(
                    context,
                    icon: Icons.insights,
                    title: AppLocalizations.of(context).inzichtenPatronen,
                    route: '/insights',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.bar_chart,
                    title: AppLocalizations.of(context).statistieken,
                    route: '/statistics',
                    color: Theme.of(context).colorScheme.secondary,
                  ),

                  const Divider(height: 32),
                  _buildSectionTitle(AppLocalizations.of(context).instellingen),
                  _buildMenuItem(
                    context,
                    icon: Icons.settings_outlined,
                    title: AppLocalizations.of(context).instellingenItem,
                    route: '/settings',
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                _version,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
    final isSelected = widget.currentRoute == route;

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
          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
        if (widget.currentRoute != route) {
          Navigator.pushNamed(context, route);
        }
      },
    );
  }
}
