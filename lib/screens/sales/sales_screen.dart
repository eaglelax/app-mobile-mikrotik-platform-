import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../providers/auth_provider.dart';
import '../../providers/site_provider.dart';
import '../../services/api_client.dart';
import '../../utils/formatters.dart';

class SalesScreen extends StatefulWidget {
  final Site? site;
  const SalesScreen({super.key, this.site});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _api = ApiClient();
  Site? _site;
  List<Map<String, dynamic>> _allSales = [];
  List<Map<String, dynamic>> _sales = [];
  bool _loading = false;
  String _period = 'today';
  Timer? _autoRefresh;

  bool _autoLoaded = false;

  @override
  void initState() {
    super.initState();
    _site = widget.site;
    if (_site != null) {
      _load();
      _startAutoRefresh();
    }
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefresh?.cancel();
    _autoRefresh = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && _site != null) _load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_autoLoaded && _site == null) {
      _autoLoaded = true;
      final auth = context.read<AuthProvider>();
      if (auth.user?.isGerant == true && auth.user!.siteId != null) {
        final sites = context.read<SiteProvider>().sites;
        final match = sites.where((s) => s.id == auth.user!.siteId).toList();
        if (match.isNotEmpty) {
          _site = match.first;
          _load();
        }
      }
    }
  }

  Future<void> _load() async {
    if (_site == null) return;
    final auth = context.read<AuthProvider>();
    final isGerant = auth.user?.isGerant == true;
    final gerantPointId = auth.user?.pointId;
    setState(() => _loading = true);
    try {
      final data = await _api.get('/api/sync-sales.php', {
        'site_id': _site!.id.toString(),
      });
      var sales = (data['sales'] as List? ?? []).cast<Map<String, dynamic>>();
      // Filter by point_id for gerants
      if (isGerant && gerantPointId != null) {
        sales = sales.where((s) =>
            s['point_id'] != null &&
            int.tryParse(s['point_id'].toString()) == gerantPointId).toList();
      }
      _allSales = sales;
      _applyPeriodFilter();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _applyPeriodFilter() {
    if (_period == 'all') {
      _sales = _allSales;
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _sales = _allSales.where((s) {
      final dateStr = s['sale_date']?.toString() ?? '';
      final date = DateTime.tryParse(dateStr);
      if (date == null) return false;

      return switch (_period) {
        'today' => date.year == today.year && date.month == today.month && date.day == today.day,
        'week' => date.isAfter(today.subtract(const Duration(days: 7))),
        'month' => date.year == today.year && date.month == today.month,
        _ => true,
      };
    }).toList();
  }

  num _toNum(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;

  int get _totalRevenue {
    int total = 0;
    for (final s in _sales) {
      if (s['void'] == true || s['void'] == 1 || s['void'] == 't') continue;
      total += (_toNum(s['price']) - _toNum(s['discount'])).toInt();
    }
    return total;
  }

  Widget _buildChip(String label, bool selected, Color color, VoidCallback onTap, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : (isDark ? AppTheme.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
          ),
          child: Text(label, style: TextStyle(
            fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? color : Colors.grey.shade500,
          )),
        ),
      ),
    );
  }

  Widget _buildSiteSelector(bool isDark) {
    final siteProvider = context.watch<SiteProvider>();
    final sites = siteProvider.configuredSites;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: textColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ventes', style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700, color: textColor,
                      )),
                      Text('Choisissez un site', style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade500,
                      )),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Site list
            if (siteProvider.isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (sites.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.router_outlined, size: 48, color: Colors.grey.shade700),
                      const SizedBox(height: 12),
                      const Text('Aucun site configuré'),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sites.length,
                  itemBuilder: (ctx, i) {
                    final site = sites[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.wifi, color: AppTheme.primary),
                        ),
                        title: Text(site.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(site.routerIp, style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 13,
                        )),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          setState(() => _site = site);
                          _load();
                          _startAutoRefresh();
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);

    if (_site == null) {
      return _buildSiteSelector(isDark);
    }

    return PopScope(
      canPop: widget.site != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _autoRefresh?.cancel();
          setState(() { _site = null; _allSales = []; _sales = []; });
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            color: AppTheme.success,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Custom header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: textColor),
                          onPressed: () {
                            if (widget.site != null) {
                              Navigator.of(context).pop();
                            } else {
                              _autoRefresh?.cancel();
                              setState(() { _site = null; _allSales = []; _sales = []; });
                            }
                          },
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ventes', style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700, color: textColor,
                              )),
                              Text(_site!.nom, style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade500,
                              )),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _load,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(Icons.refresh, color: textColor, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Revenue summary card
                if (!_loading && _sales.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.success,
                              AppTheme.success.withValues(alpha: 0.85),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.success.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Revenu total', style: TextStyle(
                                    fontSize: 13, color: Colors.white.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w500,
                                  )),
                                  const SizedBox(height: 4),
                                  Text(Fmt.currency(_totalRevenue), style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white,
                                  )),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('${_sales.length} ventes', style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white,
                              )),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                SliverToBoxAdapter(child: SizedBox(height: _loading || _sales.isEmpty ? 0 : 16)),

                // Period filter chips
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        for (final f in [
                          ('today', "Aujourd'hui", AppTheme.primary),
                          ('week', '7 jours', AppTheme.info),
                          ('month', 'Ce mois', AppTheme.accent),
                          ('all', 'Tout', AppTheme.success),
                        ])
                          _buildChip(f.$2, _period == f.$1, f.$3, () {
                            setState(() {
                              _period = f.$1;
                              _applyPeriodFilter();
                            });
                          }, isDark),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Content
                if (_loading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_sales.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('Aucune vente', style: TextStyle(
                            fontSize: 15, color: Colors.grey.shade500, fontWeight: FontWeight.w500,
                          )),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final s = _sales[i];
                          final isVoid = s['void'] == true || s['void'] == 1 || s['void'] == 't';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: (isVoid ? Colors.grey : AppTheme.success).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.receipt,
                                      color: isVoid ? Colors.grey : AppTheme.success,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s['username'] ?? s['profile_name'] ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: isVoid ? Colors.grey : textColor,
                                            decoration: isVoid ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${s['profile_name'] ?? '-'}  ${s['sale_date'] ?? ''}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    Fmt.currency(_toNum(s['price'])),
                                    style: TextStyle(
                                      color: isVoid ? Colors.grey : AppTheme.success,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: _sales.length,
                      ),
                    ),
                  ),

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
