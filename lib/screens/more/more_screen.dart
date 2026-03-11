import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../automatisation/automatisation_screen.dart';
import '../discovery/discovery_screen.dart';
import '../kpi/kpi_dashboard_screen.dart';
import '../mikhmon/vouchers_screen.dart';
import '../scripts/scripts_screen.dart';
import '../tickets/ticket_batches_screen.dart';
import '../reports/reports_screen.dart';
import '../flash_sale/flash_sale_screen.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          // ─── Profile header ───
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isDark ? null : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
                ),
                child: Row(
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
                        radius: 26,
                        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
                        child: Text(
                          (user?.name ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? '',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1A1D21),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (user != null && !user.isGerant)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: (user.isAdmin ? AppTheme.primary : const Color(0xFF10B981)).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          user.isAdmin ? 'Admin' : 'Proprietaire',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: user.isAdmin ? AppTheme.primary : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ─── Gestion ───
          _sectionLabel('Gestion', isDark),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _menuRow(context, isDark, [
                  _MenuItem(Icons.store_rounded, 'Points de Vente', const Color(0xFF3B82F6), () => _nav(context, const PointsListScreen())),
                  _MenuItem(Icons.wifi_rounded, 'Profils', const Color(0xFF06B6D4), () => _nav(context, const ProfilesListScreen())),
                  _MenuItem(Icons.confirmation_number_rounded, 'Tickets', const Color(0xFFF59E0B), () => _nav(context, const TicketsListScreen())),
                  _MenuItem(Icons.receipt_long_rounded, 'Ventes', const Color(0xFF10B981), () => _nav(context, const SalesScreen())),
                ]),
                const SizedBox(height: 12),
                _menuRow(context, isDark, [
                  _MenuItem(Icons.flash_on_rounded, 'Vente Flash', const Color(0xFFEF4444), () => _nav(context, const FlashSaleScreen())),
                  _MenuItem(Icons.notifications_rounded, 'Notifications', const Color(0xFFF97316), () => _nav(context, const NotificationsScreen()), badge: notif.unreadCount),
                  _MenuItem(Icons.travel_explore_rounded, 'Decouverte', const Color(0xFF8B5CF6), () => _nav(context, const DiscoveryScreen())),
                  if (auth.isAdmin)
                    _MenuItem(Icons.bar_chart_rounded, 'KPI', const Color(0xFFD97706), () => _nav(context, const KpiDashboardScreen()))
                  else
                    _MenuItem(null, '', Colors.transparent, () {}),
                ]),
                const SizedBox(height: 12),
                _menuRow(context, isDark, [
                  _MenuItem(Icons.loyalty_rounded, 'Vouchers', const Color(0xFF14B8A6), () => _nav(context, const VouchersScreen())),
                  _MenuItem(Icons.inventory_rounded, 'Lots Tickets', const Color(0xFF6366F1), () => _nav(context, const TicketBatchesScreen())),
                  _MenuItem(Icons.assessment_rounded, 'Rapports', const Color(0xFF78716C), () => _nav(context, const ReportsScreen())),
                  _MenuItem(null, '', Colors.transparent, () {}), // empty slot
                ]),
              ],
            ),
          ),

          // ─── Outils avancés (visibles selon features/quotas) ───
          if (_hasAdvancedTools(auth)) ...[
            const SizedBox(height: 20),
            _sectionLabel(auth.isAdmin ? 'Administration' : 'Outils', isDark),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _menuRow(context, isDark, _buildAdvancedItems(context, auth)),
            ),
          ],

          const SizedBox(height: 28),

          // ─── Logout ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () => auth.logout(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.danger.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: AppTheme.danger, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Deconnexion',
                      style: TextStyle(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _menuRow(BuildContext context, bool isDark, List<_MenuItem> items) {
    return Row(
      children: items.map((item) {
        if (item.icon == null) {
          return const Expanded(child: SizedBox());
        }
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: item.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDark ? null : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(item.icon, color: item.color, size: 22),
                        ),
                        if (item.badge > 0)
                          Positioned(
                            top: -4,
                            right: -6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppTheme.danger,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              child: Text(
                                item.badge > 99 ? '99+' : '${item.badge}',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade300 : const Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  bool _hasAdvancedTools(AuthProvider auth) {
    if (auth.isAdmin) return true;
    final user = auth.user;
    if (user == null) return false;
    return _safeQuota(user, 'vpn') > 0 || _safeQuota(user, 'autogen_configs') > 0;
  }

  int _safeQuota(dynamic user, String resource) {
    try {
      final val = user.getQuota(resource);
      if (val is int) return val;
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  List<_MenuItem> _buildAdvancedItems(BuildContext context, AuthProvider auth) {
    final empty = _MenuItem(null, '', Colors.transparent, () {});
    final hasVpn = auth.isAdmin || _safeQuota(auth.user, 'vpn') > 0;
    final hasAuto = auth.isAdmin || _safeQuota(auth.user, 'autogen_configs') > 0;

    return [
      auth.isAdmin
          ? _MenuItem(Icons.people_rounded, 'Utilisateurs', const Color(0xFF06B6D4), () => _nav(context, const UsersListScreen()))
          : empty,
      hasVpn
          ? _MenuItem(Icons.vpn_key_rounded, 'Tunnels VPN', const Color(0xFFF59E0B), () => _nav(context, const TunnelsScreen()))
          : empty,
      hasAuto
          ? _MenuItem(Icons.auto_mode_rounded, 'Automatisation', const Color(0xFF10B981), () => _nav(context, const AutomatisationScreen()))
          : empty,
      auth.isAdmin
          ? _MenuItem(Icons.terminal_rounded, 'Scripts', const Color(0xFFEF4444), () => _nav(context, const ScriptsScreen()))
          : empty,
    ];
  }

  void _nav(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _MenuItem {
  final IconData? icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int badge;

  const _MenuItem(this.icon, this.label, this.color, this.onTap, {this.badge = 0});
}
