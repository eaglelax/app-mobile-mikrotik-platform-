import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/sites/sites_list_screen.dart';
import '../screens/mikhmon/mikhmon_hub_screen.dart';
import '../screens/reports/reports_screen.dart';
import 'app_drawer.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final _pages = const [
    DashboardScreen(),
    SitesListScreen(),
    MikhmonHubScreen(),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();

    return Scaffold(
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const NavigationDestination(
            icon: Icon(Icons.router_outlined),
            selectedIcon: Icon(Icons.router),
            label: 'Sites',
          ),
          const NavigationDestination(
            icon: Icon(Icons.wifi_outlined),
            selectedIcon: Icon(Icons.wifi),
            label: 'Mikhmon',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: notifProvider.unreadCount > 0,
              label: Text('${notifProvider.unreadCount}'),
              child: const Icon(Icons.bar_chart_outlined),
            ),
            selectedIcon: const Icon(Icons.bar_chart),
            label: 'Rapports',
          ),
        ],
      ),
    );
  }
}
