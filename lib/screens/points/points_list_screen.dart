import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/point.dart';
import '../../models/site.dart';
import '../../providers/auth_provider.dart';
import '../../providers/site_provider.dart';
import '../../services/point_service_api.dart';
import 'point_detail_screen.dart';
import 'point_form_screen.dart';

class PointsListScreen extends StatefulWidget {
  final Site? site;
  const PointsListScreen({super.key, this.site});

  @override
  State<PointsListScreen> createState() => _PointsListScreenState();
}

class _PointsListScreenState extends State<PointsListScreen> {
  final _service = PointServiceApi();
  Site? _site;
  List<Point> _points = [];
  bool _loading = false;
  String _search = '';
  final _searchController = TextEditingController();
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _site = widget.site;
    if (_site != null) _load();
    _autoRefresh = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && _site != null) _load();
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_site == null) return;
    setState(() => _loading = true);
    try {
      _points = await _service.fetchBySite(_site!.id);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deletePoint(Point point) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le point'),
        content: Text('Supprimer "${point.name}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final result = await _service.delete(point.id);
      if (result['success'] == true) {
        _load();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Erreur'), backgroundColor: AppTheme.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  List<Point> get _filtered {
    if (_search.isEmpty) return _points;
    final q = _search.toLowerCase();
    return _points.where((p) =>
        p.name.toLowerCase().contains(q) ||
        (p.contactName ?? '').toLowerCase().contains(q) ||
        p.type.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_site == null) return _buildSiteSelector(isDark);

    final points = _filtered;
    final activeCount = _points.where((p) => p.isActive).length;

    return PopScope(
      canPop: widget.site != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() { _site = null; _points = []; _search = ''; _searchController.clear(); });
      },
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
        floatingActionButton: Builder(
          builder: (ctx) {
            final auth = ctx.read<AuthProvider>();
            final quota = auth.user?.getQuota('points') ?? 0;
            final canCreate = auth.isAdmin || _points.length < quota;
            return FloatingActionButton(
              onPressed: () async {
                if (!canCreate) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Limite atteinte ($quota points max)'),
                      backgroundColor: AppTheme.warning,
                    ),
                  );
                  return;
                }
                final created = await Navigator.push<bool>(
                  ctx,
                  MaterialPageRoute(builder: (_) => PointFormScreen(siteId: _site!.id)),
                );
                if (created == true) _load();
              },
              backgroundColor: canCreate ? AppTheme.primary : Colors.grey,
              child: const Icon(Icons.add, color: Colors.white),
            );
          },
        ),
        body: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: _load,
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
                      if (widget.site == null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() { _site = null; _points = []; }),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.arrow_back_rounded, size: 20, color: isDark ? Colors.white : const Color(0xFF1A1D21)),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Points de Vente', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(_site!.nom, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                      _chip('$activeCount', 'actifs', AppTheme.success.withValues(alpha: 0.12), AppTheme.success),
                      const SizedBox(width: 8),
                      _chip('${_points.length}', 'total', isDark ? AppTheme.darkSurface : const Color(0xFFEEF2FF), AppTheme.primary),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ─── Search ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: isDark ? null : [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un point de vente...',
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
                                  onPressed: () { _searchController.clear(); setState(() => _search = ''); },
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

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '${points.length} point${points.length > 1 ? 's' : ''} de vente',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 8),

              if (_loading)
                const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator())),

              if (!_loading && points.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Column(
                    children: [
                      Icon(Icons.store_rounded, size: 52, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        _search.isNotEmpty ? 'Aucun resultat' : 'Aucun point de vente',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _search.isNotEmpty ? 'Essayez un autre terme.' : 'Appuyez sur + pour en creer un.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),

              if (!_loading)
                ...points.map((p) => _buildPointCard(p, isDark)),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSiteSelector(bool isDark) {
    final siteProvider = context.watch<SiteProvider>();
    final sites = siteProvider.configuredSites;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: isDark ? Colors.white : const Color(0xFF1A1D21),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Points de Vente', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('Choisissez un site', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (siteProvider.isLoading)
            const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator())),

          if (!siteProvider.isLoading && sites.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  Icon(Icons.router_outlined, size: 52, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('Aucun site configure', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                ],
              ),
            ),

          if (!siteProvider.isLoading)
            ...sites.map((site) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () { setState(() => _site = site); _load(); },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isDark ? null : [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
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
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(site.nom, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(site.routerIp, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildPointCard(Point p, bool isDark) {
    final tc = _typeConfig(p.type);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => PointDetailScreen(point: p, site: _site!)),
          );
          if (result == true) _load();
        },
        onLongPress: () => _deletePoint(p),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark ? null : [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tc.$2.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tc.$1, color: tc.$2, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: tc.$2.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(tc.$3, style: TextStyle(fontSize: 11, color: tc.$2, fontWeight: FontWeight.w500)),
                        ),
                        if (p.contactName != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.person_outline_rounded, size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(p.contactName!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ],
                    ),
                    if (p.serverName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.dns_rounded, size: 13, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(p.serverName!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (p.isActive ? AppTheme.success : Colors.grey).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(color: p.isActive ? AppTheme.success : Colors.grey, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      p.isActive ? 'Actif' : 'Inactif',
                      style: TextStyle(color: p.isActive ? AppTheme.success : Colors.grey, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color, String) _typeConfig(String type) {
    return switch (type) {
      'vendeur' => (Icons.store_rounded, const Color(0xFF3B82F6), 'Vendeur'),
      'zone' => (Icons.place_rounded, const Color(0xFFF59E0B), 'Zone'),
      'partenaire' => (Icons.handshake_rounded, const Color(0xFF8B5CF6), 'Partenaire'),
      'lieu' => (Icons.location_on_rounded, const Color(0xFF10B981), 'Lieu'),
      _ => (Icons.store_rounded, const Color(0xFF3B82F6), type),
    };
  }

  Widget _chip(String count, String label, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
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
}
