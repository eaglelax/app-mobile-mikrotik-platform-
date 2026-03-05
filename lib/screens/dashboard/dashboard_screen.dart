import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/site_provider.dart';
import '../../services/kpi_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/stat_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _kpiService = KpiService();
  Map<String, dynamic>? _revenue;
  Map<String, dynamic>? _activation;
  Map<String, dynamic>? _stockCoverage;
  Map<String, dynamic>? _topSites;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadKpis();
  }

  Future<void> _loadKpis() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _kpiService.fetchRevenue(),
        _kpiService.fetchActivationRate(),
        _kpiService.fetchStockCoverage(),
        _kpiService.fetchTopSites(),
      ]);
      if (mounted) {
        setState(() {
          _revenue = results[0];
          _activation = results[1];
          _stockCoverage = results[2];
          _topSites = results[3];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sites = context.watch<SiteProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard'),
            Text('Bonjour, ${auth.user?.name ?? ''}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              sites.fetchSites();
              _loadKpis();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await sites.fetchSites();
          await _loadKpis();
        },
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // KPI Cards
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.3,
                    children: [
                      StatCard(
                        title: 'Revenu Aujourd\'hui',
                        value: Fmt.currency(
                            _revenue?['today_revenue'] ?? 0, 'FCFA'),
                        icon: Icons.payments_outlined,
                        color: AppTheme.success,
                        subtitle: _revenue?['change'] != null
                            ? '${_revenue!['change']}% vs hier'
                            : null,
                      ),
                      StatCard(
                        title: 'Taux Activation',
                        value: Fmt.percent(
                            _activation?['activation_rate'] ?? 0),
                        icon: Icons.trending_up,
                        color: AppTheme.primary,
                      ),
                      StatCard(
                        title: 'Couverture Stock',
                        value:
                            '${_stockCoverage?['coverage_days'] ?? 0} jours',
                        icon: Icons.inventory_2_outlined,
                        color: AppTheme.warning,
                      ),
                      StatCard(
                        title: 'Sites Actifs',
                        value: '${sites.configuredSites.length}',
                        icon: Icons.router_outlined,
                        color: AppTheme.info,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Top sites
                  if (_topSites?['sites'] != null) ...[
                    const Text('Meilleurs Sites',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    ...(_topSites!['sites'] as List).take(5).map((s) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppTheme.primary.withValues(alpha: 0.15),
                              child: Text(
                                '${(s['rank'] ?? 0)}',
                                style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(s['name'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${s['sold'] ?? 0} ventes',
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13)),
                            trailing: Text(
                              Fmt.currency(s['revenue'] ?? 0),
                              style: const TextStyle(
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        )),
                  ],

                  const SizedBox(height: 16),

                  // Router health overview
                  const Text('État des Routeurs',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ...sites.sites.map((site) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            Icons.circle,
                            size: 12,
                            color: site.routerStatus == 'online'
                                ? AppTheme.success
                                : site.routerStatus == 'degraded'
                                    ? AppTheme.warning
                                    : AppTheme.danger,
                          ),
                          title: Text(site.nom,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(site.routerIp,
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 12)),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                  '${site.activeUsers ?? 0} actifs',
                                  style: const TextStyle(fontSize: 13)),
                              Text(
                                  '${site.unsoldVouchers ?? 0} stock',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
      ),
    );
  }
}
