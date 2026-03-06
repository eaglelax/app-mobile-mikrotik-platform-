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
    final site = widget.site;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mikhmon'),
            Text(site.nom,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
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
                    childAspectRatio: 1.4,
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
                  const Text('Actions Rapides',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _QuickAction(
                    icon: Icons.person_add,
                    label: 'Ajouter un utilisateur',
                    subtitle: 'Créer un compte hotspot manuellement',
                    color: AppTheme.success,
                    onTap: () => _push(HotspotUserAddScreen(site: site)),
                  ),
                  _QuickAction(
                    icon: Icons.bolt,
                    label: 'Vente Flash',
                    subtitle: 'Générer un voucher en 1 clic',
                    color: AppTheme.accent,
                    onTap: () => _push(FlashSaleScreen(site: site)),
                  ),
                  _QuickAction(
                    icon: Icons.print,
                    label: 'Quick Print',
                    subtitle: 'Imprimer des tickets rapidement',
                    color: AppTheme.primary,
                    onTap: () => _push(QuickPrintScreen(site: site)),
                  ),

                  const SizedBox(height: 20),

                  // Menu
                  const Text('Hotspot',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  _MenuItem(
                    icon: Icons.people,
                    label: 'Utilisateurs Hotspot',
                    onTap: () => _push(HotspotUsersScreen(site: site)),
                  ),
                  _MenuItem(
                    icon: Icons.wifi_tethering,
                    label: 'Connexions Actives',
                    onTap: () => _push(HotspotActiveScreen(site: site)),
                  ),
                  _MenuItem(
                    icon: Icons.dns,
                    label: 'Serveurs Hotspot',
                    onTap: () => _push(HotspotServersScreen(site: site)),
                  ),
                  _MenuItem(
                    icon: Icons.cable,
                    label: 'DHCP Leases',
                    onTap: () => _push(DhcpLeasesScreen(site: site)),
                  ),
                  _MenuItem(
                    icon: Icons.bar_chart,
                    label: 'Trafic',
                    onTap: () => _push(TrafficScreen(site: site)),
                  ),
                  _MenuItem(
                    icon: Icons.cookie_outlined,
                    label: 'Cookies Hotspot',
                    onTap: () => _push(HotspotCookiesScreen(site: site)),
                  ),
                  _MenuItem(
                    icon: Icons.lan_outlined,
                    label: 'IP Bindings',
                    onTap: () => _push(IpBindingsScreen(site: site)),
                  ),
                  _MenuItem(
                    icon: Icons.article_outlined,
                    label: 'Logs',
                    onTap: () => _push(LogsScreen(site: site)),
                  ),

                  _MenuItem(
                    icon: Icons.assessment_outlined,
                    label: 'Rapport Mikhmon',
                    onTap: () => _push(MikhmonReportScreen(site: site)),
                  ),

                  const SizedBox(height: 16),
                  const Text('Système',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  _MenuItem(
                    icon: Icons.settings,
                    label: 'Contrôles Système',
                    onTap: () => _push(SystemControlsScreen(site: site)),
                  ),
                  _MenuItem(
                    icon: Icons.restart_alt,
                    label: 'Redémarrer le Routeur',
                    color: AppTheme.danger,
                    onTap: () => _confirmReboot(),
                  ),
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

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Icon(icon, color: color ?? AppTheme.primary, size: 22),
        title: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: color)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
        dense: true,
      ),
    );
  }
}
