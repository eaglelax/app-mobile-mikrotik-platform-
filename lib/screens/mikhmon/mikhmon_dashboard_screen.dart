import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/mikhmon_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/stat_card.dart';
import 'hotspot_users_screen.dart';
import 'hotspot_active_screen.dart';
import 'flash_sale_screen.dart';
import 'quick_print_screen.dart';
import 'traffic_screen.dart';
import 'hotspot_servers_screen.dart';
import 'dhcp_leases_screen.dart';
import 'hotspot_user_add_screen.dart';
import 'system_controls_screen.dart';
import 'logs_screen.dart';
import 'hotspot_cookies_screen.dart';
import 'ip_bindings_screen.dart';
import 'mikhmon_report_screen.dart';

class MikhmonDashboardScreen extends StatefulWidget {
  final Site site;
  const MikhmonDashboardScreen({super.key, required this.site});

  @override
  State<MikhmonDashboardScreen> createState() => _MikhmonDashboardScreenState();
}

class _MikhmonDashboardScreenState extends State<MikhmonDashboardScreen> {
  final _service = MikhmonService();
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.fetchDashboard(widget.site.id);
      _stats = {
        'active_users': data['active']?['count'] ?? 0,
        'total_vouchers': data['users']?['count'] ?? 0,
        'unsold_vouchers': data['users']?['unsold_vouchers'] ?? 0,
        'revenue': data['sales_today']?['revenue'] ?? 0,
        'connected': data['connected'] ?? false,
        'identity': data['identity'] ?? '',
        'system': data['system'],
        'sessions': data['active']?['sessions'] ?? [],
        'logs': data['logs'] ?? [],
      };
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final shadow = isDark
        ? <BoxShadow>[]
        : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))];
    final site = widget.site;

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
                        Text('Mikhmon', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
                        Text(site.nom, style: TextStyle(fontSize: 13, color: subtitleColor)),
                      ],
                    ),
                  ),
                  IconButton(icon: Icon(Icons.refresh_rounded, color: textColor), onPressed: _load),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Stats
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.15,
                            children: [
                              StatCard(
                                title: 'Utilisateurs Actifs',
                                value: '${_stats?['active_users'] ?? 0}',
                                icon: Icons.person,
                                color: AppTheme.primary,
                                onTap: () => _push(HotspotActiveScreen(site: site)),
                              ),
                              StatCard(
                                title: 'Total Vouchers',
                                value: '${_stats?['total_vouchers'] ?? 0}',
                                icon: Icons.confirmation_number,
                                color: AppTheme.accent,
                                onTap: () => _push(HotspotUsersScreen(site: site)),
                              ),
                              StatCard(
                                title: 'Stock Disponible',
                                value: '${_stats?['unsold_vouchers'] ?? 0}',
                                icon: Icons.inventory_2_outlined,
                                color: AppTheme.warning,
                              ),
                              StatCard(
                                title: 'Revenu',
                                value: Fmt.currency(_stats?['revenue'] ?? 0),
                                icon: Icons.payments_outlined,
                                color: AppTheme.success,
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Quick Actions
                          Text('Actions Rapides', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                          const SizedBox(height: 12),
                          _buildQuickAction(Icons.person_add, 'Ajouter un utilisateur', 'Créer un compte hotspot manuellement', AppTheme.success, () => _push(HotspotUserAddScreen(site: site)), isDark, cardColor, textColor, subtitleColor, shadow),
                          _buildQuickAction(Icons.bolt, 'Vente Flash', 'Générer un voucher en 1 clic', AppTheme.accent, () => _push(FlashSaleScreen(site: site)), isDark, cardColor, textColor, subtitleColor, shadow),
                          _buildQuickAction(Icons.print, 'Quick Print', 'Imprimer des tickets rapidement', AppTheme.primary, () => _push(QuickPrintScreen(site: site)), isDark, cardColor, textColor, subtitleColor, shadow),

                          const SizedBox(height: 20),

                          // Hotspot menu group
                          Text('Hotspot', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                            child: Column(
                              children: [
                                _buildMenuRow(Icons.people, 'Utilisateurs Hotspot', AppTheme.primary, () => _push(HotspotUsersScreen(site: site)), textColor),
                                Divider(height: 1, indent: 56, color: Colors.grey.shade200),
                                _buildMenuRow(Icons.wifi_tethering, 'Connexions Actives', AppTheme.primary, () => _push(HotspotActiveScreen(site: site)), textColor),
                                Divider(height: 1, indent: 56, color: Colors.grey.shade200),
                                _buildMenuRow(Icons.dns, 'Serveurs Hotspot', AppTheme.primary, () => _push(HotspotServersScreen(site: site)), textColor),
                                Divider(height: 1, indent: 56, color: Colors.grey.shade200),
                                _buildMenuRow(Icons.cable, 'DHCP Leases', AppTheme.primary, () => _push(DhcpLeasesScreen(site: site)), textColor),
                                Divider(height: 1, indent: 56, color: Colors.grey.shade200),
                                _buildMenuRow(Icons.bar_chart, 'Trafic', AppTheme.primary, () => _push(TrafficScreen(site: site)), textColor),
                                Divider(height: 1, indent: 56, color: Colors.grey.shade200),
                                _buildMenuRow(Icons.cookie_outlined, 'Cookies Hotspot', AppTheme.primary, () => _push(HotspotCookiesScreen(site: site)), textColor),
                                Divider(height: 1, indent: 56, color: Colors.grey.shade200),
                                _buildMenuRow(Icons.lan_outlined, 'IP Bindings', AppTheme.primary, () => _push(IpBindingsScreen(site: site)), textColor),
                                Divider(height: 1, indent: 56, color: Colors.grey.shade200),
                                _buildMenuRow(Icons.article_outlined, 'Logs', AppTheme.primary, () => _push(LogsScreen(site: site)), textColor),
                                Divider(height: 1, indent: 56, color: Colors.grey.shade200),
                                _buildMenuRow(Icons.assessment_outlined, 'Rapport Mikhmon', AppTheme.primary, () => _push(MikhmonReportScreen(site: site)), textColor),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // System menu group
                          Text('Système', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                            child: Column(
                              children: [
                                _buildMenuRow(Icons.settings, 'Contrôles Système', AppTheme.primary, () => _push(SystemControlsScreen(site: site)), textColor),
                                Divider(height: 1, indent: 56, color: Colors.grey.shade200),
                                _buildMenuRow(Icons.restart_alt, 'Redémarrer le Routeur', AppTheme.danger, () => _confirmReboot(), textColor),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, String subtitle, Color color, VoidCallback onTap, bool isDark, Color cardColor, Color textColor, Color subtitleColor, List<BoxShadow> shadow) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textColor)),
                    Text(subtitle, style: TextStyle(color: subtitleColor, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: subtitleColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuRow(IconData icon, String label, Color color, VoidCallback onTap, Color textColor) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: color == AppTheme.danger ? color : textColor))),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
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
        await _service.rebootRouter(widget.site.id);
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
}
