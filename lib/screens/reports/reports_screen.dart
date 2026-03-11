import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/point.dart';
import '../../providers/site_provider.dart';
import '../../services/api_client.dart';
import '../../services/kpi_service.dart';
import '../../services/point_service_api.dart';
import '../../utils/formatters.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _kpi = KpiService();
  final _api = ApiClient();
  final _pointService = PointServiceApi();
  bool _refreshing = false;
  Timer? _autoRefresh;

  // Period filter — default today
  String _period = 'today';
  DateTime? _customFrom;
  DateTime? _customTo;

  // Month selector (for month mode)
  late int _selectedMonth;
  late int _selectedYear;

  // Data
  Map<String, dynamic>? _revenue;
  List _topSites = [];
  List _topVendors = [];

  // Points de vente per site
  final Map<int, List<Point>> _sitePoints = {};
  // Per-point revenue: siteId -> { pointId -> {total, count} }
  final Map<int, Map<int, Map<String, num>>> _pointRevenue = {};
  bool _detailsLoading = false;

  // Expanded sites
  final Set<int> _expandedSites = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _load();
    _autoRefresh = Timer.periodic(const Duration(seconds: 60), (_) => _load());
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  String _computeDateFrom() {
    final now = DateTime.now();
    switch (_period) {
      case 'today':
        return _fmtDate(now);
      case 'week':
        return _fmtDate(now.subtract(const Duration(days: 7)));
      case 'month':
        return '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-01';
      case 'custom':
        return _customFrom != null ? _fmtDate(_customFrom!) : _fmtDate(now);
      default:
        return _fmtDate(now);
    }
  }

  String _computeDateTo() {
    final now = DateTime.now();
    switch (_period) {
      case 'today':
        return _fmtDate(now);
      case 'week':
        return _fmtDate(now);
      case 'month':
        final lastDay = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
        return '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-$lastDay';
      case 'custom':
        return _customTo != null ? _fmtDate(_customTo!) : _fmtDate(now);
      default:
        return _fmtDate(now);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    // Never clear existing data — just refresh in background
    setState(() => _refreshing = true);
    final sites = context.read<SiteProvider>().sites;
    final dateFrom = _computeDateFrom();
    final dateTo = _computeDateTo();
    try {
      final results = await Future.wait([
        _kpi.fetchRevenue(period: _period == 'month' ? 'month' : 'day', dateFrom: dateFrom, dateTo: dateTo),
        _kpi.fetchTopSites(limit: 50, dateFrom: dateFrom, dateTo: dateTo),
        _kpi.fetchTopVendors(dateFrom: dateFrom, dateTo: dateTo),
      ]);
      if (!mounted) return;
      _revenue = results[0];
      _topSites = (results[1]['items'] ?? results[1]['sites'] ?? []) as List;
      _topVendors = (results[2]['items'] ?? results[2]['vendors'] ?? []) as List;
      setState(() => _refreshing = false);

      // Load per-site details in background (non-blocking)
      _loadSiteDetails(sites, dateFrom, dateTo);
    } catch (_) {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _loadSiteDetails(List sites, String dateFrom, String dateTo) async {
    setState(() => _detailsLoading = true);
    // Don't clear — old data stays visible until replaced

    for (final site in sites.where((s) => s.isConfigured)) {
      if (!mounted) return;

      // Load points for the site
      try {
        final points = await _pointService.fetchBySite(site.id);
        if (points.isNotEmpty && mounted) {
          _sitePoints[site.id] = points;
          setState(() {});
        }
      } catch (_) {}

      // Load sales for the site and aggregate per point
      try {
        final salesResp = await _api.get('/api/sync-sales.php', {
          'site_id': site.id.toString(),
        });
        final allSales = (salesResp['sales'] as List?) ?? [];

        // Filter by date range and aggregate per point_id
        final perPoint = <int, Map<String, num>>{};
        for (final s in allSales) {
          final saleDate = s['sale_date']?.toString() ?? '';
          // Only include sales within date range
          if (saleDate.compareTo(dateFrom) >= 0 && saleDate.compareTo('$dateTo 23:59:59') <= 0) {
            final pid = int.tryParse('${s['point_id'] ?? 0}') ?? 0;
            final amount = num.tryParse('${s['price'] ?? s['amount'] ?? 0}') ?? 0;
            perPoint.putIfAbsent(pid, () => {'total': 0, 'count': 0});
            perPoint[pid]!['total'] = (perPoint[pid]!['total'] ?? 0) + amount;
            perPoint[pid]!['count'] = (perPoint[pid]!['count'] ?? 0) + 1;
          }
        }

        if (mounted) {
          _pointRevenue[site.id] = perPoint;
          setState(() {});
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _detailsLoading = false);
  }

  void _prevMonth() {
    setState(() {
      if (_selectedMonth == 1) { _selectedMonth = 12; _selectedYear--; }
      else { _selectedMonth--; }
    });
    _load();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_selectedYear == now.year && _selectedMonth >= now.month) return;
    setState(() {
      if (_selectedMonth == 12) { _selectedMonth = 1; _selectedYear++; }
      else { _selectedMonth++; }
    });
    _load();
  }

  Future<void> _pickDateRange(BuildContext ctx) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: ctx,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _customFrom != null && _customTo != null
          ? DateTimeRange(start: _customFrom!, end: _customTo!)
          : DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customFrom = picked.start;
        _customTo = picked.end;
        _period = 'custom';
      });
      _load();
    }
  }

  static const _monthNamesFull = ['', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : const Color(0xFF1A1D21);
    final sub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final card = isDark ? AppTheme.darkCard : Colors.white;
    final div = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final sh = isDark ? <BoxShadow>[] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))];
    final sites = context.watch<SiteProvider>().sites;
    final now = DateTime.now();
    final isCurrentMonth = _selectedMonth == now.month && _selectedYear == now.year;

    final revenueTotal = _revenue?['total'] ?? 0;
    final revenueCount = _revenue?['count'] ?? 0;
    final avgBasket = _revenue?['avg_basket'] ?? 0;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(13)),
                    child: const Icon(Icons.bar_chart_rounded, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text('Rapports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: text)),
                  ),
                  if (_refreshing || _detailsLoading)
                    SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: sub),
                    ),
                ],
              ),
            ),

            // Period filters
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _periodChip("Aujourd'hui", 'today', card, text, sub, sh),
                    const SizedBox(width: 8),
                    _periodChip('Semaine', 'week', card, text, sub, sh),
                    const SizedBox(width: 8),
                    _periodChip('Mois', 'month', card, text, sub, sh),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _pickDateRange(context),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _period == 'custom' ? AppTheme.primary : card,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: _period == 'custom'
                              ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
                              : sh,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.date_range, size: 14, color: _period == 'custom' ? Colors.white : sub),
                            const SizedBox(width: 6),
                            Text(
                              _period == 'custom' && _customFrom != null
                                  ? '${_customFrom!.day}/${_customFrom!.month} - ${_customTo!.day}/${_customTo!.month}'
                                  : 'Personnalisé',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _period == 'custom' ? Colors.white : sub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Month selector (only in month mode)
            if (_period == 'month')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: text, size: 22),
                      onPressed: _prevMonth,
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(
                      '${_monthNamesFull[_selectedMonth]} $_selectedYear',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: text),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: isCurrentMonth ? sub.withValues(alpha: 0.3) : text, size: 22),
                      onPressed: isCurrentMonth ? null : _nextMonth,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

            // Body — always show content, numbers update in place
            Expanded(
              child: RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        children: [
                          // Revenue hero
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: const Color(0xFF059669).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
                            ),
                            child: Column(
                              children: [
                                Text('Revenu total', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
                                const SizedBox(height: 6),
                                Text(Fmt.currency(revenueTotal), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _heroStat('$revenueCount', 'Ventes', Icons.receipt_long),
                                    Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.2)),
                                    _heroStat(Fmt.currency(avgBasket), 'Panier moy.', Icons.shopping_basket),
                                    Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.2)),
                                    _heroStat('${sites.where((s) => s.isConfigured).length}', 'Sites', Icons.router),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Ventes par site
                          Text('Ventes par site', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: text)),
                          const SizedBox(height: 10),

                          if (_topSites.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(Icons.analytics_outlined, size: 36, color: sub.withValues(alpha: 0.4)),
                                  const SizedBox(height: 8),
                                  Text('Aucune donnée', style: TextStyle(color: sub, fontSize: 13)),
                                ],
                              ),
                            )
                          else
                            ...List.generate(_topSites.length.clamp(0, 30), (i) {
                              final s = _topSites[i];
                              final siteId = s['site_id'] ?? s['id'] ?? 0;
                              final name = s['site_name'] ?? s['name'] ?? '';
                              final rev = num.tryParse('${s['total'] ?? s['revenue'] ?? 0}') ?? 0;
                              final count = s['count'] ?? s['sales'] ?? 0;
                              final isExpanded = _expandedSites.contains(siteId);
                              final points = _sitePoints[siteId] ?? [];
                              final perPointRev = _pointRevenue[siteId] ?? {};
                              final hasPoints = points.isNotEmpty;
                              final colors = [AppTheme.accent, AppTheme.primary, AppTheme.info];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16), boxShadow: sh),
                                child: Column(
                                  children: [
                                    // Site row — always tappable to expand/collapse
                                    InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: hasPoints ? () {
                                        setState(() {
                                          if (isExpanded) _expandedSites.remove(siteId);
                                          else _expandedSites.add(siteId);
                                        });
                                      } : null,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 34, height: 34,
                                              decoration: BoxDecoration(
                                                color: i < 3 ? colors[i].withValues(alpha: 0.12) : (isDark ? AppTheme.darkBg : Colors.grey.shade100),
                                                shape: BoxShape.circle,
                                              ),
                                              alignment: Alignment.center,
                                              child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: i < 3 ? colors[i] : sub)),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: text), overflow: TextOverflow.ellipsis),
                                                  Row(
                                                    children: [
                                                      Text('$count ventes', style: TextStyle(fontSize: 11, color: sub)),
                                                      if (hasPoints) ...[
                                                        Text('  ·  ', style: TextStyle(fontSize: 11, color: sub)),
                                                        Icon(Icons.store_outlined, size: 12, color: sub),
                                                        const SizedBox(width: 2),
                                                        Text('${points.length} pts', style: TextStyle(fontSize: 11, color: sub)),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(Fmt.currency(rev), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.success)),
                                            if (hasPoints) ...[
                                              const SizedBox(width: 4),
                                              Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: sub),
                                            ] else if (_detailsLoading) ...[
                                              const SizedBox(width: 8),
                                              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: sub)),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Expanded: Points de vente with per-point revenue
                                    if (isExpanded && hasPoints) ...[
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Divider(height: 1, color: div),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.store, size: 14, color: AppTheme.primary),
                                            const SizedBox(width: 6),
                                            Text('Points de vente', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                                          ],
                                        ),
                                      ),
                                      ...points.map((point) {
                                        final pRev = perPointRev[point.id];
                                        final pTotal = pRev?['total'] ?? 0;
                                        final pCount = pRev?['count'] ?? 0;

                                        return Padding(
                                          padding: const EdgeInsets.fromLTRB(28, 0, 16, 10),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 6, height: 6,
                                                decoration: BoxDecoration(
                                                  color: point.isActive ? AppTheme.success : Colors.grey,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(point.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: text)),
                                                    if (pCount > 0)
                                                      Text('$pCount ventes', style: TextStyle(fontSize: 11, color: sub)),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                pTotal > 0 ? Fmt.currency(pTotal) : '-',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: pTotal > 0 ? AppTheme.success : sub,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ],
                                ),
                              );
                            }),

                          const SizedBox(height: 24),

                          // Top Vendeurs
                          if (_topVendors.isNotEmpty) ...[
                            Text('Top vendeurs', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: text)),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16), boxShadow: sh),
                              child: Column(
                                children: List.generate(_topVendors.length.clamp(0, 10), (i) {
                                  final v = _topVendors[i];
                                  final vName = v['site_name'] ?? v['name'] ?? v['vendor_name'] ?? '';
                                  final vRev = num.tryParse('${v['total'] ?? v['revenue'] ?? 0}') ?? 0;
                                  final vCount = v['count'] ?? v['sales'] ?? 0;
                                  const medalColors = [Color(0xFFFFD700), Color(0xFFC0C0C0), Color(0xFFCD7F32)];

                                  return Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: Row(
                                          children: [
                                            if (i < 3)
                                              Container(
                                                width: 30, height: 30,
                                                decoration: BoxDecoration(
                                                  color: medalColors[i].withValues(alpha: 0.15),
                                                  shape: BoxShape.circle,
                                                ),
                                                alignment: Alignment.center,
                                                child: Icon(Icons.emoji_events, size: 16, color: medalColors[i]),
                                              )
                                            else
                                              Container(
                                                width: 30, height: 30,
                                                decoration: BoxDecoration(
                                                  color: isDark ? AppTheme.darkBg : Colors.grey.shade100,
                                                  shape: BoxShape.circle,
                                                ),
                                                alignment: Alignment.center,
                                                child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: sub)),
                                              ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(vName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: text), overflow: TextOverflow.ellipsis),
                                                  Text('$vCount ventes', style: TextStyle(fontSize: 11, color: sub)),
                                                ],
                                              ),
                                            ),
                                            Text(Fmt.currency(vRev), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.success)),
                                          ],
                                        ),
                                      ),
                                      if (i < _topVendors.length.clamp(0, 10) - 1)
                                        Padding(padding: const EdgeInsets.only(left: 58), child: Divider(height: 1, color: div)),
                                    ],
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodChip(String label, String value, Color card, Color text, Color sub, List<BoxShadow> sh) {
    final selected = _period == value;
    return GestureDetector(
      onTap: () {
        if (_period != value) {
          setState(() => _period = value);
          _load();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
              : sh,
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : sub),
        ),
      ),
    );
  }

  Widget _heroStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
      ],
    );
  }
}
