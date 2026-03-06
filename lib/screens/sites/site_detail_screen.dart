import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/site_service.dart';
import '../../services/api_client.dart';
import '../../utils/formatters.dart';
import '../../widgets/stat_card.dart';
import '../mikhmon/mikhmon_dashboard_screen.dart';
import '../reports/site_report_screen.dart';

class SiteDetailScreen extends StatefulWidget {
  final Site site;
  const SiteDetailScreen({super.key, required this.site});

  @override
  State<SiteDetailScreen> createState() => _SiteDetailScreenState();
}

class _SiteDetailScreenState extends State<SiteDetailScreen> {
  final _service = SiteService();
  final _api = ApiClient();
  Map<String, dynamic>? _stats;
  bool _loading = true;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final raw = await _service.fetchStats(widget.site.id);
      final data = raw['data'] is Map<String, dynamic>
          ? raw['data'] as Map<String, dynamic>
          : raw;
      _stats = {
        'today_revenue': data['revenue'] ?? 0,
        'today_sales': data['sold'] ?? 0,
        'unsold_vouchers': data['available'] ?? 0,
        'active_users': 0,
      };
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final result = await _service.testConnection(widget.site.id);
      _testResult = result['success'] == true
          ? 'Connexion OK (${result['response_time'] ?? '?'}ms)'
          : 'Erreur: ${result['error'] ?? 'Inconnue'}';
    } catch (e) {
      _testResult = 'Erreur: $e';
    }
    if (mounted) setState(() => _testing = false);
  }

  Future<void> _syncSales() async {
    try {
      await _service.syncSales(widget.site.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Synchronisation lancée')),
        );
      }
      _loadStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _deleteSite() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
          const SnackBar(
              content: Text('Site supprimé'),
              backgroundColor: AppTheme.success),
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

  @override
  Widget build(BuildContext context) {
    final site = widget.site;

    return Scaffold(
      appBar: AppBar(
        title: Text(site.nom),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_outlined),
            tooltip: 'Mikhmon',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => MikhmonDashboardScreen(site: site)),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Site info card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _InfoRow('IP Routeur', site.routerIp),
                          _InfoRow('Port', '${site.routerPort}'),
                          _InfoRow('Utilisateur', site.routerUser),
                          _InfoRow('Status', site.status),
                          if (site.typeActivite != null)
                            _InfoRow('Activité', site.typeActivite!),
                          _InfoRow('Devise', site.currency),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

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
                        title: 'Revenu Aujourd\'hui',
                        value: Fmt.currency(
                            _stats?['today_revenue'] ?? 0),
                        icon: Icons.payments_outlined,
                        color: AppTheme.success,
                      ),
                      StatCard(
                        title: 'Utilisateurs Actifs',
                        value: '${_stats?['active_users'] ?? 0}',
                        icon: Icons.person,
                        color: AppTheme.primary,
                      ),
                      StatCard(
                        title: 'Vouchers Stock',
                        value: '${_stats?['unsold_vouchers'] ?? 0}',
                        icon: Icons.inventory_2_outlined,
                        color: AppTheme.warning,
                      ),
                      StatCard(
                        title: 'Ventes Aujourd\'hui',
                        value: '${_stats?['today_sales'] ?? 0}',
                        icon: Icons.receipt_long,
                        color: AppTheme.info,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Actions
                  const Text('Actions',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  _ActionButton(
                    icon: Icons.speed,
                    label: 'Tester la connexion',
                    subtitle: _testResult,
                    loading: _testing,
                    onTap: _testConnection,
                  ),
                  _ActionButton(
                    icon: Icons.sync,
                    label: 'Synchroniser les ventes',
                    onTap: _syncSales,
                  ),
                  _ActionButton(
                    icon: Icons.assessment,
                    label: 'Rapport du site',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SiteReportScreen(site: site)),
                    ),
                  ),
                  _ActionButton(
                    icon: Icons.wifi,
                    label: 'Ouvrir Mikhmon',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              MikhmonDashboardScreen(site: site)),
                    ),
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _deleteSite,
                      icon: const Icon(Icons.delete_outline,
                          color: AppTheme.danger),
                      label: const Text('Supprimer ce site',
                          style: TextStyle(color: AppTheme.danger)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.danger),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          const Spacer(),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool loading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.subtitle,
    this.loading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon, color: AppTheme.primary),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null
            ? Text(subtitle!, style: const TextStyle(fontSize: 12))
            : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: loading ? null : onTap,
      ),
    );
  }
}
