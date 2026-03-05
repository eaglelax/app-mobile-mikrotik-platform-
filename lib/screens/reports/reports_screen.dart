import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/site_provider.dart';
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
                          ('year', 'Année'),
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
                            Fmt.currency(
                                _revenue?['today_revenue'] ??
                                    _revenue?['revenue'] ??
                                    0),
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.success),
                          ),
                          if (_revenue?['change'] != null)
                            Text(
                              '${_revenue!['change']}% vs période précédente',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sales mix
                  if (_salesMix?['profiles'] != null) ...[
                    const Text('Répartition des Ventes',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 10),
                    ...(_salesMix!['profiles'] as List).map((p) => Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            title: Text(p['name'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            subtitle: LinearProgressIndicator(
                              value: ((p['percentage'] ?? 0) / 100)
                                  .clamp(0.0, 1.0),
                              backgroundColor:
                                  AppTheme.primary.withValues(alpha: 0.1),
                              color: AppTheme.primary,
                            ),
                            trailing: Text(
                                '${p['percentage'] ?? 0}%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            dense: true,
                          ),
                        )),
                  ],

                  const SizedBox(height: 16),

                  // Top vendors
                  if (_topVendors?['vendors'] != null) ...[
                    const Text('Meilleurs Sites',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 10),
                    ...(_topVendors!['vendors'] as List)
                        .take(10)
                        .map((v) => Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      AppTheme.accent.withValues(alpha: 0.15),
                                  radius: 18,
                                  child: Text('${v['rank'] ?? ''}',
                                      style: const TextStyle(
                                          color: AppTheme.accent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                ),
                                title: Text(v['name'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                trailing: Text(
                                    Fmt.currency(v['revenue'] ?? 0),
                                    style: const TextStyle(
                                        color: AppTheme.success,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                                dense: true,
                              ),
                            )),
                  ],
                ],
              ),
            ),
    );
  }
}
