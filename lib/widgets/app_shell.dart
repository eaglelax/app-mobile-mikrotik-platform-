import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/sites/sites_list_screen.dart';
import '../screens/mikhmon/mikhmon_hub_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/more/more_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  final _pages = const <Widget>[
    DashboardScreen(),
    SitesListScreen(),
    MikhmonHubScreen(),
    ReportsScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _navigatorKeys[_currentIndex].currentState;
        if (nav != null && nav.canPop()) {
          nav.maybePop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(5, (i) => Navigator(
            key: _navigatorKeys[i],
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => _pages[i],
            ),
          )),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) {
            if (i == _currentIndex) {
              _navigatorKeys[i].currentState?.popUntil((route) => route.isFirst);
            } else {
              setState(() => _currentIndex = i);
            }
          },
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
            const NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: 'Plus',
            ),
          ],
        ),
      ),
    );
  }
}
