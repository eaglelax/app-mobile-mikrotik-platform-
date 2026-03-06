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

  final _periods = const {
    'today': "Aujourd'hui",
    '7d': '7 jours',
    '30d': '30 jours',
    '90d': '3 mois',
  };

  Future<void> _load() async {
    if (_site == null) return;
    setState(() => _loading = true);
    try {
      final siteIds = [_site!.id];
      final results = await Future.wait([
        _kpi.fetchRevenue(period: _period, siteIds: siteIds),
        _kpi.fetchActivationRate(siteIds: siteIds),
        _kpi.fetchStockCoverage(siteIds: siteIds),
        _kpi.fetchStockouts(siteIds: siteIds),
        _kpi.fetchSalesMix(siteIds: siteIds),
      ]);
      if (mounted) {
        setState(() {
          _revenue = results[0];
          _activation = results[1];
          _stockCoverage = results[2];
          _stockouts = results[3];
          _salesMix = results[4];
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
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

    return Scaffold(
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
                        '${_revenue?['count'] ?? 0} ventes | Moy: ${Fmt.currency(_revenue?['average'] ?? 0)}',
                  ),

                  // Activation rate
                  _KpiCard(
                    title: 'Taux d\'activation',
                    icon: Icons.trending_up,
                    color: AppTheme.primary,
                    value: '${(_activation?['rate'] ?? 0).toStringAsFixed(1)}%',
                    subtitle:
                        'Médiane: ${_activation?['median_time'] ?? '-'}',
                  ),

                  // Stock coverage
                  _KpiCard(
                    title: 'Couverture de stock',
                    icon: Icons.inventory_2_outlined,
                    color: AppTheme.warning,
                    value: '${_stockCoverage?['days'] ?? '-'} jours',
                    subtitle:
                        'Stock total: ${_stockCoverage?['total_stock'] ?? 0}',
                  ),

                  // Stockouts
                  _KpiCard(
                    title: 'Ruptures de stock',
                    icon: Icons.warning_amber,
                    color: AppTheme.danger,
                    value: '${_stockouts?['count'] ?? 0}',
                    subtitle: _stockouts?['profiles'] != null
                        ? ((_stockouts!['profiles'] as List?)
                                ?.map((p) => p['name'])
                                .take(3)
                                .join(', ') ??
                            '')
                        : '',
                  ),

                  // Sales mix
                  if (_salesMix?['mix'] != null) ...[
                    const SizedBox(height: 16),
                    const Text('Répartition des ventes',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    ...(_salesMix!['mix'] as List? ?? []).map<Widget>((item) {
                      final pct = (item['percentage'] ?? 0).toDouble();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          title: Text(item['profile'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
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
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                          dense: true,
                        ),
                      );
                    }),
                  ],
                ],
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
