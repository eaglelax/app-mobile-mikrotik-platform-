import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/points/points_list_screen.dart';
import '../screens/profiles/profiles_list_screen.dart';
import '../screens/sales/sales_screen.dart';
import '../screens/tickets/tickets_list_screen.dart';
import '../screens/tunnels/tunnels_screen.dart';
import '../screens/users/users_list_screen.dart';
import '../screens/automatisation/automatisation_screen.dart';
import '../screens/discovery/discovery_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final notif = context.watch<NotificationProvider>();
    final user = auth.user;

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppTheme.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primary,
                  radius: 24,
                  child: Text(
                    (user?.name ?? 'U').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                Text(user?.name ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
                Text(user?.email ?? '',
                    style: const TextStyle(
                        fontSize: 13, color: Colors.white70)),
                if (user?.isAdmin == true)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Admin',
                        style:
                            TextStyle(fontSize: 11, color: AppTheme.accent)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _DrawerItem(
                  icon: Icons.store_outlined,
                  label: 'Points de Vente',
                  onTap: () => _navigate(context, const PointsListScreen()),
                ),
                _DrawerItem(
                  icon: Icons.wifi_outlined,
                  label: 'Profils',
                  onTap: () =>
                      _navigate(context, const ProfilesListScreen()),
                ),
                _DrawerItem(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Tickets',
                  onTap: () => _navigate(context, const TicketsListScreen()),
                ),
                _DrawerItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'Ventes',
                  onTap: () => _navigate(context, const SalesScreen()),
                ),
                _DrawerItem(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  badge: notif.unreadCount,
                  onTap: () =>
                      _navigate(context, const NotificationsScreen()),
                ),
                _DrawerItem(
                  icon: Icons.search_outlined,
                  label: 'Découverte',
                  onTap: () => _navigate(context, const DiscoveryScreen()),
                ),
                const Divider(),
                if (auth.isAdmin) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('ADMINISTRATION',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey,
                            letterSpacing: 1)),
                  ),
                  _DrawerItem(
                    icon: Icons.people_outlined,
                    label: 'Utilisateurs',
                    onTap: () =>
                        _navigate(context, const UsersListScreen()),
                  ),
                  _DrawerItem(
                    icon: Icons.vpn_key_outlined,
                    label: 'Tunnels VPN',
                    onTap: () =>
                        _navigate(context, const TunnelsScreen()),
                  ),
                  _DrawerItem(
                    icon: Icons.auto_mode_outlined,
                    label: 'Automatisation',
                    onTap: () =>
                        _navigate(context, const AutomatisationScreen()),
                  ),
                  const Divider(),
                ],
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.danger),
            title: const Text('Déconnexion',
                style: TextStyle(color: AppTheme.danger)),
            onTap: () {
              Navigator.pop(context);
              auth.logout();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.pop(context); // Close drawer
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Badge(
        isLabelVisible: badge > 0,
        label: Text('$badge'),
        child: Icon(icon),
      ),
      title: Text(label),
      onTap: onTap,
      dense: true,
    );
  }
}
