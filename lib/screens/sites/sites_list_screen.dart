import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../providers/site_provider.dart';
import '../../services/site_service.dart';
import '../../utils/constants.dart';
import 'site_detail_screen.dart';
import 'site_form_screen.dart';

class SitesListScreen extends StatefulWidget {
  const SitesListScreen({super.key});

  @override
  State<SitesListScreen> createState() => _SitesListScreenState();
}

class _SitesListScreenState extends State<SitesListScreen> {
  String? _statusFilter;
  String _search = '';

  final _siteService = SiteService();

  Future<void> _deleteSite(Site site, SiteProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce site ?'),
        content: Text('Le site "${site.nom}" et toutes ses données seront supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
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
      await _siteService.deleteSite(site.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Site supprimé'), backgroundColor: AppTheme.success),
        );
        provider.fetchSites();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  List<Site> _filtered(List<Site> sites) {
    var list = sites;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((s) =>
          s.nom.toLowerCase().contains(q) ||
          s.routerIp.toLowerCase().contains(q)).toList();
    }
    if (_statusFilter != null) {
      list = list.where((s) => s.status == _statusFilter).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final siteProvider = context.watch<SiteProvider>();
    final sites = _filtered(siteProvider.sites);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sites'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => siteProvider.fetchSites(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const SiteFormScreen()),
          );
          if (created == true) siteProvider.fetchSites();
        },
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () => siteProvider.fetchSites(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher un site...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  for (final f in [
                    (null, 'Tous'),
                    ('configure', 'Configurés'),
                    ('nouveau', 'Nouveaux'),
                    ('maintenance', 'Maintenance'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(f.$2),
                        selected: _statusFilter == f.$1,
                        onSelected: (_) =>
                            setState(() => _statusFilter = f.$1),
                        selectedColor:
                            AppTheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: siteProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : sites.isEmpty
                      ? const Center(child: Text('Aucun site'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: sites.length,
                          itemBuilder: (ctx, i) =>
                              _SiteCard(
                                site: sites[i],
                                onDelete: () => _deleteSite(sites[i], siteProvider),
                              ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteCard extends StatelessWidget {
  final Site site;
  final VoidCallback? onDelete;
  const _SiteCard({required this.site, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (site.status) {
      'configure' => AppTheme.success,
      'maintenance' => AppTheme.warning,
      'inactif' => AppTheme.danger,
      _ => Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => SiteDetailScreen(site: site))),
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.router, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(site.nom,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(site.routerIp,
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      AppConstants.siteStatuses[site.status] ?? site.status,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (site.isConfigured) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MiniStat(
                        icon: Icons.person,
                        label: '${site.activeUsers ?? 0} actifs',
                        color: AppTheme.primary),
                    const SizedBox(width: 16),
                    _MiniStat(
                        icon: Icons.inventory_2,
                        label: '${site.unsoldVouchers ?? 0} stock',
                        color: AppTheme.warning),
                    const Spacer(),
                    Icon(Icons.circle,
                        size: 8,
                        color: site.isOnline
                            ? AppTheme.success
                            : AppTheme.danger),
                    const SizedBox(width: 4),
                    Text(site.isOnline ? 'En ligne' : 'Hors ligne',
                        style: TextStyle(
                            fontSize: 12,
                            color: site.isOnline
                                ? AppTheme.success
                                : AppTheme.danger)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniStat(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
      ],
    );
  }
}
