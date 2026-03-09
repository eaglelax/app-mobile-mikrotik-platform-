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
          const SnackBar(
              content: Text('Site supprimé'),
              backgroundColor: AppTheme.success),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subtextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final containerColor = isDark ? AppTheme.darkCard : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE8EAF0);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // Custom header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: textColor,
                      size: 20,
                    ),
                    splashRadius: 22,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detail du site',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          site.nom,
                          style: TextStyle(
                            fontSize: 13,
                            color: subtextColor,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _HeaderIconButton(
                    icon: Icons.wifi_outlined,
                    tooltip: 'Mikhmon',
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => MikhmonDashboardScreen(site: site)),
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : RefreshIndicator(
                      color: AppTheme.primary,
                      onRefresh: _loadStats,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          // Site info container
                          Container(
                            decoration: BoxDecoration(
                              color: containerColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor, width: 0.5),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? Colors.black.withValues(alpha: 0.2)
                                      : Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.router_outlined,
                                        color: AppTheme.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Informations',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Divider(
                                  color: borderColor,
                                  height: 1,
                                ),
                                const SizedBox(height: 10),
                                _InfoRow('IP Routeur', site.routerIp,
                                    isDark: isDark),
                                _InfoRow('Port', '${site.routerPort}',
                                    isDark: isDark),
                                _InfoRow('Utilisateur', site.routerUser,
                                    isDark: isDark),
                                _InfoRow('Status', site.status,
                                    isDark: isDark),
                                if (site.typeActivite != null)
                                  _InfoRow('Activité', site.typeActivite!,
                                      isDark: isDark),
                                _InfoRow('Devise', site.currency,
                                    isDark: isDark),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Stats
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
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

                          const SizedBox(height: 24),

                          // Actions section
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 12),
                            child: Text(
                              'Actions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ),
                          _ActionButton(
                            icon: Icons.speed,
                            label: 'Tester la connexion',
                            subtitle: _testResult,
                            loading: _testing,
                            isDark: isDark,
                            onTap: _testConnection,
                          ),
                          _ActionButton(
                            icon: Icons.sync,
                            label: 'Synchroniser les ventes',
                            isDark: isDark,
                            onTap: _syncSales,
                          ),
                          _ActionButton(
                            icon: Icons.assessment,
                            label: 'Rapport du site',
                            isDark: isDark,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      SiteReportScreen(site: site)),
                            ),
                          ),
                          _ActionButton(
                            icon: Icons.wifi,
                            label: 'Ouvrir Mikhmon',
                            isDark: isDark,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      MikhmonDashboardScreen(site: site)),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Delete button
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.danger.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: _deleteSite,
                                borderRadius: BorderRadius.circular(16),
                                child: const Padding(
                                  padding:
                                      EdgeInsets.symmetric(vertical: 14),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.delete_outline,
                                          color: AppTheme.danger, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Supprimer ce site',
                                        style: TextStyle(
                                          color: AppTheme.danger,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark
            ? AppTheme.darkSurface
            : AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  const _InfoRow(this.label, this.value, {this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF1A1D21),
            ),
          ),
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
  final bool isDark;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.subtitle,
    this.loading = false,
    this.isDark = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final containerColor = isDark ? AppTheme.darkCard : Colors.white;
    final borderColor =
        isDark ? AppTheme.darkBorder : const Color(0xFFE8EAF0);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subtextColor =
        isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: loading ? null : onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  if (loading)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: AppTheme.primary, size: 20),
                    ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              color: subtextColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
