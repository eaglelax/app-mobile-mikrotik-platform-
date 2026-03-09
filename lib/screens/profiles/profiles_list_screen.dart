import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../providers/site_provider.dart';
import '../../services/mikhmon_service.dart';
import '../../services/api_client.dart';
import 'profile_form_screen.dart';

class ProfilesListScreen extends StatefulWidget {
  final Site? site;
  const ProfilesListScreen({super.key, this.site});

  @override
  State<ProfilesListScreen> createState() => _ProfilesListScreenState();
}

class _ProfilesListScreenState extends State<ProfilesListScreen> {
  final _service = MikhmonService();
  final _api = ApiClient();
  Site? _site;
  List<Map<String, dynamic>> _profiles = [];
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
      final data = await _service.fetchProfiles(_site!.id);
      _profiles = (data['profiles'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete(Map<String, dynamic> profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le profil ?'),
        content: Text('Le profil "${profile['name']}" sera désactivé.'),
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
      await _api.post('/api/profiles.php', {
        'action': 'delete',
        'profile_id': profile['id'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profil supprimé'),
              backgroundColor: AppTheme.success),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _profiles;
    final q = _search.toLowerCase();
    return _profiles.where((p) =>
        (p['name'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_site == null) return _buildSiteSelector(isDark);

    final profiles = _filtered;

    return PopScope(
      canPop: widget.site != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() { _site = null; _profiles = []; _search = ''; _searchController.clear(); });
      },
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final created = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                  builder: (_) => ProfileFormScreen(siteId: _site!.id)),
            );
            if (created == true) _load();
          },
          backgroundColor: AppTheme.primary,
          child: const Icon(Icons.add, color: Colors.white),
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
                            onTap: () => setState(() { _site = null; _profiles = []; }),
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
                            const Text('Profils', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(_site!.nom, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                      _chip('${_profiles.length}', 'total', isDark ? AppTheme.darkSurface : const Color(0xFFEEF2FF), AppTheme.primary),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ─── Search ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      hintText: 'Rechercher un profil...',
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

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '${profiles.length} profil${profiles.length > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 8),

              if (_loading)
                const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator())),

              if (!_loading && profiles.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Column(
                    children: [
                      Icon(Icons.wifi_rounded, size: 52, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        _search.isNotEmpty ? 'Aucun resultat' : 'Aucun profil',
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
                ...profiles.map((p) => _buildProfileCard(p, isDark)),

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
                      const Text('Profils', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
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

  Widget _buildProfileCard(Map<String, dynamic> p, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (_) => ProfileFormScreen(
                    siteId: _site!.id, profile: p)),
          ).then((ok) {
            if (ok == true) _load();
          });
        },
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
                child: const Icon(Icons.wifi_rounded, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _infoBadge('${p['ticket_price'] ?? '-'}', Icons.sell_rounded, AppTheme.accent),
                        const SizedBox(width: 8),
                        _infoBadge('${p['validity'] ?? '-'}', Icons.timer_rounded, AppTheme.info),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.inventory_2_rounded, size: 13, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text('Stock: ${p['stock'] ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        const SizedBox(width: 12),
                        Icon(Icons.trending_up_rounded, size: 13, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text('Moy: ${p['daily_avg'] ?? '-'}/j', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'edit', child: Text('Modifier')),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('Supprimer',
                          style: TextStyle(color: AppTheme.danger))),
                ],
                onSelected: (action) {
                  if (action == 'edit') {
                    Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ProfileFormScreen(
                              siteId: _site!.id, profile: p)),
                    ).then((ok) {
                      if (ok == true) _load();
                    });
                  } else if (action == 'delete') {
                    _delete(p);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
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
