import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/site_service.dart';
import '../../services/mikhmon_service.dart';
import '../../services/api_client.dart';
import '../../utils/formatters.dart';
import '../mikhmon/hotspot_users_screen.dart';
import '../mikhmon/hotspot_active_screen.dart';
import '../mikhmon/flash_sale_screen.dart';
import '../mikhmon/quick_print_screen.dart';
import '../mikhmon/traffic_screen.dart';
import '../mikhmon/hotspot_servers_screen.dart';
import '../mikhmon/dhcp_leases_screen.dart';
import '../points/points_list_screen.dart';
import '../mikhmon/system_controls_screen.dart';
import '../mikhmon/logs_screen.dart';
import '../mikhmon/hotspot_cookies_screen.dart';
import '../mikhmon/ip_bindings_screen.dart';
import '../mikhmon/mikhmon_report_screen.dart';
import '../reports/site_report_screen.dart';
import '../tickets/ticket_batches_screen.dart';

class SiteDetailScreen extends StatefulWidget {
  final Site site;
  const SiteDetailScreen({super.key, required this.site});

  @override
  State<SiteDetailScreen> createState() => _SiteDetailScreenState();
}

class _SiteDetailScreenState extends State<SiteDetailScreen> {
  final _siteService = SiteService();
  final _mikhmonService = MikhmonService();
  final _api = ApiClient();
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final raw = await _siteService.fetchStats(widget.site.id);
      final data = raw['data'] is Map<String, dynamic>
          ? raw['data'] as Map<String, dynamic>
          : raw;

      int activeUsers = 0;
      try {
        final mikhmonData = await _mikhmonService.fetchDashboard(widget.site.id);
        activeUsers = mikhmonData['active']?['count'] ?? 0;
      } catch (_) {}

      _stats = {
        'today_revenue': data['revenue'] ?? 0,
        'today_sales': data['sold'] ?? 0,
        'unsold_vouchers': data['available'] ?? 0,
        'active_users': activeUsers,
      };
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteSite() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ce site ?'),
        content: Text(
            'Le site "${widget.site.nom}" et toutes ses données seront supprimés. Cette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.post('/api/full-setup.php', {
        'action': 'delete',
        'site_id': widget.site.id,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Site supprimé'), backgroundColor: AppTheme.success),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _confirmReboot() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Redémarrer le routeur ?'),
        content: Text(
            'Le routeur ${widget.site.nom} sera redémarré. Les utilisateurs actifs seront déconnectés.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Redémarrer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _mikhmonService.rebootRouter(widget.site.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Redémarrage lancé')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final shadow = isDark
        ? <BoxShadow>[]
        : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))];

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(site.nom, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
                        Text(site.routerIp, style: TextStyle(fontSize: 13, color: subtitleColor)),
                      ],
                    ),
                  ),
                  IconButton(icon: Icon(Icons.refresh_rounded, color: textColor), onPressed: _loadStats),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadStats,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // ── Revenue Hero Card ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text("Revenu aujourd'hui", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.8))),
                                const SizedBox(height: 8),
                                Text(
                                  Fmt.currency(_stats?['today_revenue'] ?? 0),
                                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                                ),
                                const SizedBox(height: 16),
                                // Mini stats row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _miniStat('${_stats?['active_users'] ?? 0}', 'Actifs', Icons.person),
                                    Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.2)),
                                    _miniStat('${_stats?['unsold_vouchers'] ?? 0}', 'Stock', Icons.inventory_2_outlined),
                                    Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.2)),
                                    _miniStat('${_stats?['today_sales'] ?? 0}', 'Ventes', Icons.receipt_long),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Quick Actions (4 in a row) ──
                          Text('Actions rapides', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _quickActionTile(
                                  Icons.bolt,
                                  'Flash',
                                  AppTheme.accent,
                                  () => _push(FlashSaleScreen(site: site)),
                                  isDark, cardColor, textColor, shadow,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _quickActionTile(
                                  Icons.print,
                                  'Print',
                                  AppTheme.primary,
                                  () => _push(QuickPrintScreen(site: site)),
                                  isDark, cardColor, textColor, shadow,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _quickActionTile(
                                  Icons.storefront,
                                  'Points',
                                  AppTheme.success,
                                  () => _push(PointsListScreen(site: site)),
                                  isDark, cardColor, textColor, shadow,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _quickActionTile(
                                  Icons.inventory_2_outlined,
                                  'Tickets',
                                  AppTheme.info,
                                  () => _push(TicketBatchesScreen(site: site)),
                                  isDark, cardColor, textColor, shadow,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ── Hotspot ──
                          Text('Hotspot', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                            child: Column(
                              children: [
                                _menuItem(Icons.people_outline, 'Utilisateurs', () => _push(HotspotUsersScreen(site: site)), textColor, subtitleColor, dividerColor),
                                _menuItem(Icons.wifi_tethering, 'Connexions Actives', () => _push(HotspotActiveScreen(site: site)), textColor, subtitleColor, dividerColor),
                                _menuItem(Icons.dns_outlined, 'Serveurs', () => _push(HotspotServersScreen(site: site)), textColor, subtitleColor, dividerColor),
                                _menuItem(Icons.cable_outlined, 'DHCP Leases', () => _push(DhcpLeasesScreen(site: site)), textColor, subtitleColor, dividerColor),
                                _menuItem(Icons.bar_chart_rounded, 'Trafic', () => _push(TrafficScreen(site: site)), textColor, subtitleColor, dividerColor),
                                _menuItem(Icons.cookie_outlined, 'Cookies', () => _push(HotspotCookiesScreen(site: site)), textColor, subtitleColor, dividerColor),
                                _menuItem(Icons.lan_outlined, 'IP Bindings', () => _push(IpBindingsScreen(site: site)), textColor, subtitleColor, dividerColor),
                                _menuItem(Icons.article_outlined, 'Logs', () => _push(LogsScreen(site: site)), textColor, subtitleColor, dividerColor, isLast: true),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Rapports ──
                          Text('Rapports', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                            child: Column(
                              children: [
                                _menuItem(Icons.assessment_outlined, 'Rapport Mikhmon', () => _push(MikhmonReportScreen(site: site)), textColor, subtitleColor, dividerColor),
                                _menuItem(Icons.analytics_outlined, 'Rapport du Site', () => _push(SiteReportScreen(site: site)), textColor, subtitleColor, dividerColor, isLast: true),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Système ──
                          Text('Système', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                            child: Column(
                              children: [
                                _menuItem(Icons.settings_outlined, 'Contrôles Système', () => _push(SystemControlsScreen(site: site)), textColor, subtitleColor, dividerColor),
                                _menuItem(Icons.restart_alt, 'Redémarrer le Routeur', () => _confirmReboot(), textColor, subtitleColor, dividerColor, isLast: true, isDanger: true),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Delete
                          GestureDetector(
                            onTap: _deleteSite,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.delete_outline, color: AppTheme.danger, size: 18),
                                  SizedBox(width: 8),
                                  Text('Supprimer ce site', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mini stat inside the hero card ──
  Widget _miniStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
      ],
    );
  }

  // ── Quick action tile (grid item) ──
  Widget _quickActionTile(IconData icon, String label, Color color, VoidCallback onTap, bool isDark, Color cardColor, Color textColor, List<BoxShadow> shadow) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: shadow,
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  // ── Menu item row ──
  Widget _menuItem(IconData icon, String label, VoidCallback onTap, Color textColor, Color subtitleColor, Color dividerColor, {bool isLast = false, bool isDanger = false}) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(16))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 20, color: isDanger ? AppTheme.danger : subtitleColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDanger ? AppTheme.danger : textColor,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
        if (!isLast) Padding(
          padding: const EdgeInsets.only(left: 50),
          child: Divider(height: 1, color: dividerColor),
        ),
      ],
    );
  }
}
