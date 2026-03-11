import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../providers/site_provider.dart';
import '../../services/kpi_service.dart';
import '../../utils/formatters.dart';

class KpiDashboardScreen extends StatefulWidget {
  const KpiDashboardScreen({super.key});

  @override
  State<KpiDashboardScreen> createState() => _KpiDashboardScreenState();
}

class _KpiDashboardScreenState extends State<KpiDashboardScreen> {
  final _kpi = KpiService();
  Site? _site;
  String _period = 'today';
  bool _loading = false;

  Map<String, dynamic>? _revenue;
  Map<String, dynamic>? _activation;
  Map<String, dynamic>? _stockCoverage;
  Map<String, dynamic>? _stockouts;
  Map<String, dynamic>? _salesMix;

  String? _error;

  Timer? _autoRefresh;

  final _periods = const {
    'today': "Aujourd'hui",
    '7d': '7 jours',
    '30d': '30 jours',
    '90d': '3 mois',
  };

  Map<String, String> _dateRange() {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    late DateTime from;
    switch (_period) {
      case '7d':
        from = now.subtract(const Duration(days: 7));
        break;
      case '30d':
        from = now.subtract(const Duration(days: 30));
        break;
      case '90d':
        from = now.subtract(const Duration(days: 90));
        break;
      default:
        from = now;
    }
    final fromStr =
        '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    return {'date_from': fromStr, 'date_to': todayStr};
  }

  void _startAutoRefresh() {
    _autoRefresh?.cancel();
    _autoRefresh = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_site != null && mounted) _load();
    });
  }

  void _stopAutoRefresh() {
    _autoRefresh?.cancel();
    _autoRefresh = null;
  }

  Future<void> _load() async {
    if (_site == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final siteIds = [_site!.id];
    final range = _dateRange();
    final errors = <String>[];
    final empty = <String, dynamic>{};

    final results = await Future.wait([
      _kpi.fetchRevenue(dateFrom: range['date_from']!, dateTo: range['date_to']!, siteIds: siteIds)
          .catchError((e) { errors.add('Revenu: $e'); return empty; }),
      _kpi.fetchActivationRate(siteIds: siteIds)
          .catchError((e) { errors.add('Activation: $e'); return empty; }),
      _kpi.fetchStockCoverage(siteIds: siteIds)
          .catchError((e) { errors.add('Stock: $e'); return empty; }),
      _kpi.fetchStockouts(siteIds: siteIds)
          .catchError((e) { errors.add('Ruptures: $e'); return empty; }),
      _kpi.fetchSalesMix(siteIds: siteIds)
          .catchError((e) { errors.add('Mix: $e'); return empty; }),
    ]);

    if (mounted) {
      setState(() {
        _revenue = results[0];
        _activation = results[1];
        _stockCoverage = results[2];
        _stockouts = results[3];
        _salesMix = results[4];
        _error = errors.isNotEmpty ? errors.join('\n') : null;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    super.dispose();
  }

  // ── Header bar (no AppBar) ──────────────────────────────────────────
  Widget _buildHeader({
    required bool isDark,
    required String title,
    String? subtitle,
    VoidCallback? onBack,
    List<Widget>? actions,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: Icon(Icons.arrow_back,
                  color: isDark ? Colors.white : const Color(0xFF1A1D21)),
              onPressed: onBack,
            )
          else
            const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1D21),
                    )),
                if (subtitle != null)
                  Text(subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              ],
            ),
          ),
          if (actions != null) ...actions,
        ],
      ),
    );
  }

  // ── Custom chip ─────────────────────────────────────────────────────
  Widget _buildChip(String label, bool selected, VoidCallback onTap, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.15)
                : (isDark ? AppTheme.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppTheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppTheme.primary : Colors.grey.shade500,
              )),
        ),
      ),
    );
  }

  // ── Site selector (inline) ──────────────────────────────────────────
  Widget _buildSiteSelector(bool isDark) {
    final sites = context.watch<SiteProvider>().configuredSites;

    return Column(
      children: [
        _buildHeader(
          isDark: isDark,
          title: 'KPI',
          subtitle: 'Choisissez un site',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: sites.isEmpty
              ? Center(
                  child: Text('Aucun site configuré',
                      style: TextStyle(color: Colors.grey.shade500)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sites.length,
                  itemBuilder: (context, index) {
                    final site = sites[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() => _site = site);
                        _load();
                        _startAutoRefresh();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isDark
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.router,
                                  color: AppTheme.primary, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(site.nom,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A1D21),
                                      )),
                                  if (site.routerIp.isNotEmpty)
                                    Text(site.routerIp,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: Colors.grey.shade400, size: 22),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA);

    if (_site == null) {
      return Scaffold(
        backgroundColor: bg,
        body: SafeArea(child: _buildSiteSelector(isDark)),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _stopAutoRefresh();
          setState(() => _site = null);
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(
                isDark: isDark,
                title: 'KPI',
                subtitle: _site!.nom,
                onBack: () {
                  _stopAutoRefresh();
                  setState(() => _site = null);
                },
                actions: [
                  IconButton(
                    icon: Icon(Icons.refresh,
                        color: isDark ? Colors.white : const Color(0xFF1A1D21)),
                    onPressed: _load,
                  ),
                ],
              ),

              // Body
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          children: [
                            // Error banner
                            if (_error != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.danger.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: AppTheme.danger, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(_error!,
                                          style: const TextStyle(
                                              color: AppTheme.danger,
                                              fontSize: 13)),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.refresh, size: 18),
                                      onPressed: _load,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),

                            // Period selector
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _periods.entries.map((e) {
                                  final selected = e.key == _period;
                                  return _buildChip(e.value, selected, () {
                                    setState(() => _period = e.key);
                                    _load();
                                  }, isDark);
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Revenue
                            _KpiCard(
                              title: 'Chiffre d\'affaires',
                              icon: Icons.payments_outlined,
                              color: AppTheme.success,
                              value: Fmt.currency(_revenue?['total'] ?? 0),
                              subtitle:
                                  '${_revenue?['count'] ?? 0} ventes | Moy: ${Fmt.currency(_revenue?['avg_basket'] ?? 0)}',
                            ),

                            // Activation rate
                            _KpiCard(
                              title: 'Taux d\'activation',
                              icon: Icons.trending_up,
                              color: AppTheme.primary,
                              value:
                                  '${(_activation?['activation_rate'] ?? 0).toStringAsFixed(1)}%',
                              subtitle:
                                  'Vendus: ${_activation?['total_sold'] ?? 0} | Actifs: ${_activation?['total_activated'] ?? 0}',
                            ),

                            // Stock coverage
                            Builder(builder: (_) {
                              final coverageItems =
                                  _stockCoverage?['items'] as List? ?? [];
                              final totalStock = coverageItems.fold<int>(
                                  0,
                                  (sum, item) =>
                                      sum +
                                      ((item['available_stock'] ?? 0) as num)
                                          .toInt());
                              final minCoverage = coverageItems.isNotEmpty
                                  ? coverageItems
                                      .where((i) => i['coverage_days'] != null)
                                      .fold<num?>(null, (min, i) {
                                      final d = (i['coverage_days'] as num);
                                      return min == null || d < min ? d : min;
                                    })
                                  : null;
                              return _KpiCard(
                                title: 'Couverture de stock',
                                icon: Icons.inventory_2_outlined,
                                color: AppTheme.warning,
                                value:
                                    '${minCoverage?.toStringAsFixed(0) ?? '-'} jours min',
                                subtitle:
                                    'Stock total: $totalStock | ${coverageItems.length} profils',
                              );
                            }),

                            // Stockouts
                            Builder(builder: (_) {
                              final stockoutItems =
                                  _stockouts?['items'] as List? ?? [];
                              final lowStockProfiles = <String>[];
                              for (final item in stockoutItems) {
                                final profiles = item['profiles'] ??
                                    item['low_stock_profiles'] as List? ??
                                    [];
                                for (final p in profiles) {
                                  final name =
                                      p['profile_name'] ?? p['name'] ?? '';
                                  if (name.isNotEmpty) {
                                    lowStockProfiles.add(name);
                                  }
                                }
                              }
                              return _KpiCard(
                                title: 'Ruptures de stock',
                                icon: Icons.warning_amber,
                                color: AppTheme.danger,
                                value: '${lowStockProfiles.length}',
                                subtitle: lowStockProfiles.isNotEmpty
                                    ? lowStockProfiles.take(3).join(', ')
                                    : 'Aucune rupture',
                              );
                            }),

                            // Sales mix
                            Builder(builder: (_) {
                              final mixItems =
                                  _salesMix?['items'] as List? ?? [];
                              if (mixItems.isEmpty) {
                                return Container(
                                  margin: const EdgeInsets.only(top: 16),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.darkCard : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: isDark ? null : [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.pie_chart_outline, size: 40, color: Colors.grey.shade300),
                                      const SizedBox(height: 8),
                                      Text('Aucune vente sur cette periode',
                                          style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                                    ],
                                  ),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 16),
                                  Text('Répartition des ventes',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A1D21),
                                      )),
                                  const SizedBox(height: 10),
                                  ...mixItems.map<Widget>((item) {
                                    final pct = ((item['percent'] ??
                                                item['percentage'] ??
                                                0) as num)
                                        .toDouble();
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppTheme.darkCard
                                            : Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        boxShadow: isDark
                                            ? null
                                            : [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.04),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                item['profile_name'] ??
                                                    item['profile'] ??
                                                    '',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(0xFF1A1D21),
                                                ),
                                              ),
                                              Text(
                                                '${pct.toStringAsFixed(1)}%',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                  color: AppTheme.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            child: LinearProgressIndicator(
                                              value: pct / 100,
                                              backgroundColor: isDark
                                                  ? AppTheme.darkSurface
                                                  : Colors.grey.shade200,
                                              color: AppTheme.primary,
                                              minHeight: 6,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String value;
  final String subtitle;

  const _KpiCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1A1D21),
                    )),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
