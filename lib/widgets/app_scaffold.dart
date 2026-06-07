import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final String currentRoute;
  final int bottomNavIndex;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showBottomNav;
  final bool showDrawer;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.currentRoute,
    this.bottomNavIndex = 0,
    this.actions,
    this.floatingActionButton,
    this.showBottomNav = true,
    this.showDrawer = true,
  });

  void _onBottomNavTap(BuildContext context, int index) {
    if (index == bottomNavIndex) return;

    switch (index) {
      case 0:
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        break;
      case 1:
        Navigator.pushNamed(context, '/mood');
        break;
      case 2:
        Navigator.pushNamed(context, '/activity');
        break;
      case 3:
        Navigator.pushNamed(context, '/statistics');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryLavender,
        elevation: 0,
        leading: showDrawer
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Menu',
                ),
              )
            : null,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        actions: actions,
      ),
      drawer: showDrawer ? AppDrawer(currentRoute: currentRoute) : null,
      bottomNavigationBar: showBottomNav
          ? BottomNavBar(
              currentIndex: bottomNavIndex,
              onTap: (index) => _onBottomNavTap(context, index),
            )
          : null,
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
