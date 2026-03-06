import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/kpi_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/site_selector.dart';

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
  Widget build(BuildContext context) {
    if (_site == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('KPI par site')),
        body: SiteSelector(onSelect: (s) {
          setState(() => _site = s);
          _load();
        }),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _site = null);
      },
      child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('KPI'),
            Text(_site!.nom,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Changer de site',
              onPressed: () => setState(() => _site = null)),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Error banner
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.danger, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: AppTheme.danger, fontSize: 13)),
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
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(e.value),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _period = e.key);
                              _load();
                            },
                            selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                          ),
                        );
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
                    value: '${(_activation?['activation_rate'] ?? 0).toStringAsFixed(1)}%',
                    subtitle:
                        'Vendus: ${_activation?['total_sold'] ?? 0} | Actifs: ${_activation?['total_activated'] ?? 0}',
                  ),

                  // Stock coverage (API returns list of items per profile)
                  Builder(builder: (_) {
                    final coverageItems =
                        _stockCoverage?['items'] as List? ?? [];
                    final totalStock = coverageItems.fold<int>(
                        0,
                        (sum, item) =>
                            sum +
                            ((item['available_stock'] ?? 0) as num).toInt());
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

                  // Stockouts (API returns list of sites with stockout info)
                  Builder(builder: (_) {
                    final stockoutItems =
                        _stockouts?['items'] as List? ?? [];
                    final lowStockProfiles = <String>[];
                    for (final item in stockoutItems) {
                      final profiles =
                          item['low_stock_profiles'] as List? ?? [];
                      for (final p in profiles) {
                        final name = p['profile_name'] ?? p['name'] ?? '';
                        if (name.isNotEmpty) lowStockProfiles.add(name);
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

                  // Sales mix (API returns {items: [...]} with profile_name, count, total, percentage)
                  Builder(builder: (_) {
                    final mixItems =
                        _salesMix?['items'] as List? ?? [];
                    if (mixItems.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Text('Répartition des ventes',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        ...mixItems.map<Widget>((item) {
                          final pct =
                              ((item['percent'] ?? item['percentage'] ?? 0) as num).toDouble();
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              title: Text(
                                  item['profile_name'] ??
                                      item['profile'] ??
                                      '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              subtitle: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct / 100,
                                  backgroundColor: Colors.grey.shade200,
                                  color: AppTheme.primary,
                                  minHeight: 6,
                                ),
                              ),
                              trailing: Text('${pct.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              dense: true,
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
