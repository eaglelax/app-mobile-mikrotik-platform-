import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/kpi_service.dart';
import '../../utils/formatters.dart';

class SiteReportScreen extends StatefulWidget {
  final Site site;
  const SiteReportScreen({super.key, required this.site});

  @override
  State<SiteReportScreen> createState() => _SiteReportScreenState();
}

class _SiteReportScreenState extends State<SiteReportScreen> {
  final _kpi = KpiService();
  String _period = 'today';
  bool _loading = true;

  Map<String, dynamic>? _revenue;
  Map<String, dynamic>? _salesMix;
  Map<String, dynamic>? _activation;

  final _periods = const {
    'today': "Aujourd'hui",
    '7d': '7 jours',
    '30d': '30 jours',
    '90d': '3 mois',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final siteIds = [widget.site.id];
      final results = await Future.wait([
        _kpi.fetchRevenue(period: _period, siteIds: siteIds),
        _kpi.fetchSalesMix(siteIds: siteIds),
        _kpi.fetchActivationRate(siteIds: siteIds),
      ]);
      if (mounted) {
        setState(() {
          _revenue = results[0];
          _salesMix = results[1];
          _activation = results[2];
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rapport'),
            Text(widget.site.nom,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
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
                            selectedColor:
                                AppTheme.primary.withValues(alpha: 0.2),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Revenue
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.payments_outlined,
                                  color: AppTheme.success),
                              const SizedBox(width: 8),
                              const Text('Chiffre d\'affaires',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(Fmt.currency(_revenue?['total'] ?? 0),
                              style: const TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                              '${_revenue?['count'] ?? 0} ventes | Moyenne: ${Fmt.currency(_revenue?['avg_basket'] ?? 0)}',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Activation
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.trending_up,
                                color: AppTheme.primary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Taux d\'activation',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600)),
                                Text(
                                    '${((_activation?['activation_rate'] ?? _activation?['rate'] ?? 0) as num).toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sales Mix
                  const Text('Répartition des ventes',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if ((_salesMix?['items'] ?? _salesMix?['mix']) != null)
                    ...((_salesMix!['items'] ?? _salesMix!['mix']) as List? ?? []).map<Widget>((item) {
                      final pct = ((item['percent'] ?? item['percentage'] ?? 0) as num).toDouble();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          title: Text(item['profile_name'] ?? item['profile'] ?? '',
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
                                  fontWeight: FontWeight.w700)),
                          dense: true,
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
