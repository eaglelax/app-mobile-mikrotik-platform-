import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/gerant/gerant_dashboard_screen.dart';
import '../screens/sites/sites_list_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/more/more_screen.dart';
import '../screens/flash_sale/flash_sale_screen.dart';

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
    FlashSaleScreen(),
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
              icon: Icon(Icons.flash_on_outlined),
              selectedIcon: Icon(Icons.flash_on),
              label: 'Vente Flash',
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

  // --- Restricted navigation (gerant) — 3 tabs ---
  final _gerantNavKeys = List.generate(3, (_) => GlobalKey<NavigatorState>());
  final _gerantDashKey = GlobalKey<GerantDashboardScreenState>();
  late final _gerantPages = <Widget>[
    GerantDashboardScreen(key: _gerantDashKey),
    const FlashSaleScreen(),
    const _GerantSettingsScreen(),
  ];

  Widget _buildGerantShell(BuildContext context, AuthProvider auth) {
    final gerantIndex = _currentIndex.clamp(0, 2);

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
          children: List.generate(3, (i) => Navigator(
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
              // Refresh dashboard when switching back to Mes Ventes tab
              if (i == 0) {
                _gerantDashKey.currentState?.refresh();
              }
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Mes Ventes',
            ),
            NavigationDestination(
              icon: Icon(Icons.flash_on_outlined),
              selectedIcon: Icon(Icons.flash_on),
              label: 'Vente Flash',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outlined),
              selectedIcon: Icon(Icons.person),
              label: 'Compte',
            ),
          ],
        ),
      ),
    );
  }
}

// Settings screen for gerant
class _GerantSettingsScreen extends StatelessWidget {
  const _GerantSettingsScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // Custom header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Mon Compte',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Profile card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Avatar with gradient ring
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                            ),
                          ),
                          child: CircleAvatar(
                            backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
                            radius: 34,
                            child: Text(
                              (user?.name ?? 'G').substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          user?.name ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(fontSize: 13, color: subColor),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Gérant',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Logout button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => auth.logout(),
                      icon: const Icon(Icons.logout, color: AppTheme.danger, size: 20),
                      label: const Text(
                        'Déconnexion',
                        style: TextStyle(
                          color: AppTheme.danger,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.danger, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
