import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../providers/auth_provider.dart';
import '../../providers/site_provider.dart';
import '../../services/site_service.dart';
import '../../services/mikhmon_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import 'site_detail_screen.dart';
import 'site_form_screen.dart';
import '../../widgets/top_notification.dart';

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
  Timer? _debounce;
  final _siteService = SiteService();
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _autoRefresh = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) context.read<SiteProvider>().fetchSites();
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showSiteActions(Site site, SiteProvider provider) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              Text(site.nom, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.delete_sweep, color: Colors.orange),
                title: const Text('Supprimer tous les tickets'),
                subtitle: const Text('Supprime tous les tickets de tous les points de vente'),
                onTap: () => Navigator.pop(ctx, 'delete_tickets'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
                title: const Text('Supprimer le site', style: TextStyle(color: AppTheme.danger)),
                subtitle: const Text('Supprime le site et toutes ses donnees'),
                onTap: () => Navigator.pop(ctx, 'delete_site'),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Annuler'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'delete_tickets') {
      await _deleteAllTickets(site);
    } else if (action == 'delete_site') {
      await _deleteSite(site, provider);
    }
  }

  Future<void> _deleteAllTickets(Site site) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer tous les tickets ?'),
        content: Text('Tous les tickets de tous les points de vente du site "${site.nom}" seront supprimes du routeur.\n\nCette action est irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Show immediate feedback and run in background
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text('Suppression des tickets de "${site.nom}" en cours...'),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 30),
      ),
    );

    // Run in background
    MikhmonService().removeAllUsers(site.id).then((result) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      final success = result['success'] == true;
      if (success) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black87;
        final msg = result['message']?.toString() ?? 'Tickets supprimés avec succès';
        TopNotification.show(
          context,
          title: 'Suppression terminée',
          message: '${site.nom} — $msg',
        );
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle, color: AppTheme.success, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Suppression terminée',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Row(children: [
                          const Icon(Icons.router, size: 18, color: AppTheme.primary),
                          const SizedBox(width: 10),
                          Expanded(child: Text(site.nom, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor))),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          const Icon(Icons.delete_sweep, size: 18, color: AppTheme.primary),
                          const SizedBox(width: 10),
                          Expanded(child: Text(msg, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor))),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?.toString() ?? 'Erreur inconnue'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }).catchError((e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
      );
    });
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
      floatingActionButton: Builder(
        builder: (ctx) {
          final auth = ctx.read<AuthProvider>();
          final quota = auth.user?.getQuota('sites') ?? 0;
          final canCreate = auth.isAdmin || siteProvider.sites.length < quota;
          return FloatingActionButton(
            onPressed: () async {
              if (!canCreate) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('Limite atteinte ($quota sites max)'),
                    backgroundColor: AppTheme.warning,
                  ),
                );
                return;
              }
              final created = await Navigator.push<bool>(
                ctx,
                MaterialPageRoute(builder: (_) => const SiteFormScreen()),
              );
              if (created == true) siteProvider.fetchSites();
            },
            backgroundColor: canCreate ? AppTheme.primary : Colors.grey,
            child: const Icon(Icons.add, color: Colors.white),
          );
        },
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
                    onChanged: (v) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        setState(() => _search = v);
                      });
                    },
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
                  onDelete: () => _showSiteActions(site, siteProvider),
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

class _SiteCard extends StatelessWidget {
  final Site site;
  final bool isDark;
  final VoidCallback? onDelete;
  const _SiteCard({required this.site, required this.isDark, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (site.status) {
      'configure' => AppTheme.success,
      'maintenance' => AppTheme.warning,
      'inactif' => AppTheme.danger,
      _ => Colors.grey,
    };

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
            // Top row: icon + name + status
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
