import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/kpi_service.dart';
import '../../utils/formatters.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _kpi = KpiService();
  String _period = 'today';
  Map<String, dynamic>? _revenue;
  Map<String, dynamic>? _salesMix;
  Map<String, dynamic>? _topVendors;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _kpi.fetchRevenue(period: _period),
        _kpi.fetchSalesMix(),
        _kpi.fetchTopVendors(),
      ]);
      _revenue = results[0];
      _salesMix = results[1];
      _topVendors = results[2];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    // Revenue: {total, count, variation_pct, avg_basket, series}
    final revenueTotal = _revenue?['total'] ?? 0;
    final revenueChange = _revenue?['variation_pct'];
    final revenueCount = _revenue?['count'] ?? 0;
    final avgBasket = _revenue?['avg_basket'] ?? 0;

    // Sales mix: {items: [{profile_name, count, total, percent}]}
    final salesMixList = _salesMix?['items'] as List? ?? [];

    // Top vendors: {items: [{site_name, total, count}]}
    final topVendorsList = _topVendors?['items'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Rapports')),
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
                      children: [
                        for (final p in [
                          ('today', "Aujourd'hui"),
                          ('week', 'Semaine'),
                          ('month', 'Mois'),
                          ('year', 'Annee'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(p.$2),
                              selected: _period == p.$1,
                              onSelected: (_) {
                                setState(() => _period = p.$1);
                                _load();
                              },
                              selectedColor: AppTheme.primary,
                              labelStyle: TextStyle(
                                color: _period == p.$1
                                    ? Colors.white
                                    : null,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Revenue card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Revenu',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(
                            Fmt.currency(revenueTotal),
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.success),
                          ),
                          if (revenueChange != null)
                            Text(
                              '${revenueChange}% vs periode precedente',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                Text('$revenueCount',
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primary)),
                                const Text('Ventes',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                Text(Fmt.currency(avgBasket),
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.info)),
                                const Text('Panier moyen',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Sales mix
                  if (salesMixList.isNotEmpty) ...[
                    const Text('Repartition des Ventes',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 10),
                    ...salesMixList.map((p) => Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            title: Text(
                                p['profile_name'] ?? p['name'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            subtitle: LinearProgressIndicator(
                              value: ((p['percent'] ?? p['percentage'] ?? 0) / 100)
                                  .toDouble()
                                  .clamp(0.0, 1.0),
                              backgroundColor:
                                  AppTheme.primary.withValues(alpha: 0.1),
                              color: AppTheme.primary,
                            ),
                            trailing: Text(
                                '${p['percent'] ?? p['percentage'] ?? 0}%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            dense: true,
                          ),
                        )),
                  ],

                  const SizedBox(height: 16),

                  // Top vendors/sites
                  if (topVendorsList.isNotEmpty) ...[
                    const Text('Meilleurs Sites',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 10),
                    ...topVendorsList.take(10).indexed.map((entry) {
                      final (i, v) = entry;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppTheme.accent.withValues(alpha: 0.15),
                            radius: 18,
                            child: Text('${i + 1}',
                                style: const TextStyle(
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ),
                          title: Text(
                              v['site_name'] ?? v['name'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          trailing: Text(
                              Fmt.currency(
                                  num.tryParse('${v['total'] ?? v['revenue'] ?? 0}') ?? 0),
                              style: const TextStyle(
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
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
