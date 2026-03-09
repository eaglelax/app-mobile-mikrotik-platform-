import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/gerant/gerant_dashboard_screen.dart';
import '../screens/sites/sites_list_screen.dart';
import '../screens/mikhmon/mikhmon_hub_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/more/more_screen.dart';
import '../screens/flash_sale/flash_sale_screen.dart';
import '../screens/sales/sales_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isGerant = auth.user?.isGerant ?? false;

    if (isGerant) {
      return _buildGerantShell(context, auth);
    }
    return _buildFullShell(context);
  }

  // --- Full navigation (admin / regular user) ---
  final _fullNavKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());
  final _fullPages = const <Widget>[
    DashboardScreen(),
    SitesListScreen(),
    MikhmonHubScreen(),
    ReportsScreen(),
    MoreScreen(),
  ];

  Widget _buildFullShell(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _fullNavKeys[_currentIndex].currentState;
        if (nav != null && nav.canPop()) {
          nav.maybePop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(5, (i) => Navigator(
            key: _fullNavKeys[i],
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => _fullPages[i],
            ),
          )),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) {
            if (i == _currentIndex) {
              _fullNavKeys[i].currentState?.popUntil((route) => route.isFirst);
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

  // --- Restricted navigation (gerant) ---
  final _gerantNavKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());
  final _gerantPages = const <Widget>[
    GerantDashboardScreen(),
    FlashSaleScreen(),
    SalesScreen(),
    _GerantSettingsScreen(),
  ];

  Widget _buildGerantShell(BuildContext context, AuthProvider auth) {
    final gerantIndex = _currentIndex.clamp(0, 3);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _gerantNavKeys[gerantIndex].currentState;
        if (nav != null && nav.canPop()) {
          nav.maybePop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: gerantIndex,
          children: List.generate(4, (i) => Navigator(
            key: _gerantNavKeys[i],
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => _gerantPages[i],
            ),
          )),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: gerantIndex,
          onDestinationSelected: (i) {
            if (i == gerantIndex) {
              _gerantNavKeys[i].currentState?.popUntil((route) => route.isFirst);
            } else {
              setState(() => _currentIndex = i);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.flash_on_outlined),
              selectedIcon: Icon(Icons.flash_on),
              label: 'Vente Flash',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Ventes',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Compte',
            ),
          ],
        ),
      ),
    );
  }
}

// Simple settings screen for gerant (logout only)
class _GerantSettingsScreen extends StatelessWidget {
  const _GerantSettingsScreen();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Mon Compte')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  radius: 32,
                  child: Text(
                    (user?.name ?? 'G').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Text(user?.name ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 18)),
                Text(user?.email ?? '',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Gerant',
                      style: TextStyle(
                          fontSize: 12, color: Colors.deepPurple)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Deconnexion',
                style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
