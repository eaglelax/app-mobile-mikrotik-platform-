import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../providers/site_provider.dart';
import '../../services/site_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import 'site_detail_screen.dart';
import 'site_form_screen.dart';

class SitesListScreen extends StatefulWidget {
  const SitesListScreen({super.key});

  @override
  State<SitesListScreen> createState() => _SitesListScreenState();
}

class _SitesListScreenState extends State<SitesListScreen> {
  String? _statusFilter;
  String? _onlineFilter; // 'online', 'offline', or null
  String _search = '';
  final _searchController = TextEditingController();
  final _siteService = SiteService();
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _autoRefresh = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) context.read<SiteProvider>().fetchSites();
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteSite(Site site, SiteProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce site ?'),
        content: Text('Le site "${site.nom}" et toutes ses donnees seront supprimes.'),
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
          const SnackBar(content: Text('Site supprime'), backgroundColor: AppTheme.success),
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

  Future<void> _changeStatus(Site site, String newStatus, SiteProvider provider) async {
    try {
      await _siteService.updateSite(site.id, {'status': newStatus});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status changé en "${AppConstants.siteStatuses[newStatus] ?? newStatus}"'),
            backgroundColor: AppTheme.success,
          ),
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
    if (_onlineFilter == 'online') {
      list = list.where((s) => s.isOnline).toList();
    } else if (_onlineFilter == 'offline') {
      list = list.where((s) => !s.isOnline).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final siteProvider = context.watch<SiteProvider>();
    final sites = _filtered(siteProvider.sites);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalSites = siteProvider.sites.length;
    final onlineCount = siteProvider.sites.where((s) => s.isOnline).length;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
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
        color: AppTheme.primary,
        onRefresh: () => siteProvider.fetchSites(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            // ─── Header ───
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    const Text(
                      'Sites',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    _headerChip('$totalSites', 'total', isDark ? AppTheme.darkSurface : const Color(0xFFEEF2FF), AppTheme.primary),
                    const SizedBox(width: 8),
                    _headerChip('$onlineCount', 'en ligne', AppTheme.success.withValues(alpha: 0.12), AppTheme.success),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ─── Search bar ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: isDark ? null : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Rechercher par nom ou IP...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 18, right: 8),
                        child: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 22),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      suffixIcon: _search.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: IconButton(
                                icon: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _search = '');
                                },
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ─── All filters on one line ───
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildChip(null, null, 'Tous', Icons.grid_view_rounded, isDark),
                  _buildChip('online', null, 'En ligne', Icons.wifi_rounded, isDark, accentColor: AppTheme.success),
                  _buildChip('offline', null, 'Hors ligne', Icons.wifi_off_rounded, isDark, accentColor: AppTheme.danger),
                  _buildChip(null, 'configure', 'Configures', Icons.check_circle_outline_rounded, isDark),
                  _buildChip(null, 'nouveau', 'Nouveaux', Icons.fiber_new_rounded, isDark),
                  _buildChip(null, 'maintenance', 'Maintenance', Icons.build_rounded, isDark),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── Count ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '${sites.length} site${sites.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ─── Loading ───
            if (siteProvider.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              ),

            // ─── Empty ───
            if (!siteProvider.isLoading && sites.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    Icon(Icons.router_outlined, size: 52, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      _search.isNotEmpty || _statusFilter != null
                          ? 'Aucun resultat'
                          : 'Aucun site',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _search.isNotEmpty
                          ? 'Essayez un autre terme de recherche.'
                          : 'Appuyez sur + pour ajouter un site.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),

            // ─── Site cards ───
            if (!siteProvider.isLoading)
              ...sites.map((site) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SiteCard(
                  site: site,
                  isDark: isDark,
                  onDelete: () => _deleteSite(site, siteProvider),
                  onChangeStatus: (status) => _changeStatus(site, status, siteProvider),
                ),
              )),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _headerChip(String count, String label, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count, style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: textColor, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildChip(String? onlineVal, String? statusVal, String label, IconData icon, bool isDark, {Color? accentColor}) {
    // "Tous" chip: selected when both filters are null
    final isTousChip = onlineVal == null && statusVal == null;
    final bool selected;
    if (isTousChip) {
      selected = _onlineFilter == null && _statusFilter == null;
    } else if (onlineVal != null) {
      selected = _onlineFilter == onlineVal;
    } else {
      selected = _statusFilter == statusVal;
    }

    final color = accentColor ?? AppTheme.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() {
          if (isTousChip) {
            _onlineFilter = null;
            _statusFilter = null;
          } else if (onlineVal != null) {
            _onlineFilter = _onlineFilter == onlineVal ? null : onlineVal;
          } else {
            _statusFilter = _statusFilter == statusVal ? null : statusVal;
          }
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : isDark ? AppTheme.darkBorder : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: selected ? color : Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? color : isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _statusColorFor(String status) => switch (status) {
  'configure' => AppTheme.success,
  'maintenance' => AppTheme.warning,
  'inactif' => AppTheme.danger,
  _ => Colors.grey,
};

class _SiteCard extends StatelessWidget {
  final Site site;
  final bool isDark;
  final VoidCallback? onDelete;
  final void Function(String status)? onChangeStatus;
  const _SiteCard({required this.site, required this.isDark, this.onDelete, this.onChangeStatus});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColorFor(site.status);
    final statusLabel = AppConstants.siteStatuses[site.status] ?? site.status;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => SiteDetailScreen(site: site))),
      onLongPress: onDelete,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? null : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon + name + status + popup menu
            Row(
              children: [
                // Router icon with online indicator
                Stack(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.router_rounded, color: AppTheme.primary, size: 22),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: site.isOnline ? AppTheme.success : AppTheme.danger,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppTheme.darkCard : Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        site.nom,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        site.routerIp,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.more_vert, size: 20, color: Colors.grey.shade600),
                  onSelected: (value) {
                    if (value == 'delete') {
                      onDelete?.call();
                    } else {
                      onChangeStatus?.call(value);
                    }
                  },
                  itemBuilder: (_) => [
                    for (final entry in AppConstants.siteStatuses.entries)
                      if (entry.key != site.status)
                        PopupMenuItem(
                          value: entry.key,
                          child: Row(
                            children: [
                              Icon(Icons.circle, size: 10, color: _statusColorFor(entry.key)),
                              const SizedBox(width: 8),
                              Text(entry.value),
                            ],
                          ),
                        ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                          SizedBox(width: 8),
                          Text('Supprimer', style: TextStyle(color: AppTheme.danger)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Stats row for configured sites
            if (site.isConfigured) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _stat(Icons.person_rounded, '${site.activeUsers ?? 0}', 'Actifs', AppTheme.primary),
                    _divider(),
                    _stat(Icons.inventory_2_rounded, '${site.unsoldVouchers ?? 0}', 'Stock', AppTheme.warning),
                    _divider(),
                    _stat(
                      Icons.payments_rounded,
                      site.todayRevenue != null ? Fmt.number(site.todayRevenue!) : '0',
                      "Aujourd'hui",
                      AppTheme.success,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: isDark ? AppTheme.darkBorder : const Color(0xFFE5E7EB),
    );
  }
}
