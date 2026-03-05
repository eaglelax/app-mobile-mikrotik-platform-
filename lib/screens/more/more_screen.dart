import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../automatisation/automatisation_screen.dart';
import '../discovery/discovery_screen.dart';
import '../notifications/notifications_screen.dart';
import '../points/points_list_screen.dart';
import '../profiles/profiles_list_screen.dart';
import '../sales/sales_screen.dart';
import '../tickets/tickets_list_screen.dart';
import '../tunnels/tunnels_screen.dart';
import '../users/users_list_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final notif = context.watch<NotificationProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.lightCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
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
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(user?.email ?? '',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                if (user?.isAdmin == true)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Admin',
                        style:
                            TextStyle(fontSize: 12, color: AppTheme.accent)),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Main features grid
          const _SectionTitle('Gestion'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _MenuTile(
                icon: Icons.store_outlined,
                label: 'Points de Vente',
                color: AppTheme.primary,
                onTap: () => _navigate(context, const PointsListScreen()),
              ),
              _MenuTile(
                icon: Icons.wifi_outlined,
                label: 'Profils',
                color: AppTheme.info,
                onTap: () => _navigate(context, const ProfilesListScreen()),
              ),
              _MenuTile(
                icon: Icons.confirmation_number_outlined,
                label: 'Tickets',
                color: AppTheme.warning,
                onTap: () => _navigate(context, const TicketsListScreen()),
              ),
              _MenuTile(
                icon: Icons.receipt_long_outlined,
                label: 'Ventes',
                color: AppTheme.success,
                onTap: () => _navigate(context, const SalesScreen()),
              ),
              _MenuTile(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                color: Colors.orange,
                badge: notif.unreadCount,
                onTap: () => _navigate(context, const NotificationsScreen()),
              ),
              _MenuTile(
                icon: Icons.search_outlined,
                label: 'Decouverte',
                color: Colors.purple,
                onTap: () => _navigate(context, const DiscoveryScreen()),
              ),
            ],
          ),

          // Admin section
          if (auth.isAdmin) ...[
            const SizedBox(height: 20),
            const _SectionTitle('Administration'),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _MenuTile(
                  icon: Icons.people_outlined,
                  label: 'Utilisateurs',
                  color: AppTheme.info,
                  onTap: () => _navigate(context, const UsersListScreen()),
                ),
                _MenuTile(
                  icon: Icons.vpn_key_outlined,
                  label: 'Tunnels VPN',
                  color: AppTheme.accent,
                  onTap: () => _navigate(context, const TunnelsScreen()),
                ),
                _MenuTile(
                  icon: Icons.auto_mode_outlined,
                  label: 'Automatisation',
                  color: AppTheme.success,
                  onTap: () =>
                      _navigate(context, const AutomatisationScreen()),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Logout
          OutlinedButton.icon(
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout, color: AppTheme.danger),
            label: const Text('Deconnexion',
                style: TextStyle(color: AppTheme.danger)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.danger),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.grey,
            letterSpacing: 0.5));
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int badge;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.lightCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
            ),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
