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
  Map<String, dynamic>? _todayRevenue;
  Map<String, dynamic>? _monthRevenue;
  Map<String, dynamic>? _activation;
  Map<String, dynamic>? _topSites;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadKpis();
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _monthStart() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
  }

  Future<void> _loadKpis() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final today = _today();
    final monthStart = _monthStart();
    final errors = <String>[];

    // Each call is independent so partial data still displays
    final results = await Future.wait([
      _kpiService
          .fetchRevenue(dateFrom: today, dateTo: today)
          .catchError((e) { errors.add('Revenu: $e'); return <String, dynamic>{}; }),
      _kpiService
          .fetchRevenue(dateFrom: monthStart, dateTo: today)
          .catchError((e) { errors.add('Ventes: $e'); return <String, dynamic>{}; }),
      _kpiService
          .fetchActivationRate()
          .catchError((e) { errors.add('Activation: $e'); return <String, dynamic>{}; }),
      _kpiService
          .fetchTopSites()
          .catchError((e) { errors.add('Top sites: $e'); return <String, dynamic>{}; }),
    ]);

    if (mounted) {
      setState(() {
        _todayRevenue = results[0];
        _monthRevenue = results[1];
        _activation = results[2];
        _topSites = results[3];
        _error = errors.isNotEmpty ? errors.join('\n') : null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sites = context.watch<SiteProvider>();

    final todayTotal = _todayRevenue?['total'] ?? 0;
    final todayChange = _todayRevenue?['variation_pct'];
    final activationRate = _activation?['activation_rate'] ?? 0;
    final monthCount = _monthRevenue?['count'] ?? 0;
    final topSitesList = _topSites?['items'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard'),
            Text('Bonjour, ${auth.user?.name ?? ''}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
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
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: AppTheme.danger, fontSize: 13),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 18),
                            onPressed: _loadKpis,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                  // Site loading error
                  if (sites.error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber,
                              color: AppTheme.warning, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sites: ${sites.error}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // KPI Cards
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.15,
                    children: [
                      StatCard(
                        title: 'Revenu Aujourd\'hui',
                        value: Fmt.currency(todayTotal, 'FCFA'),
                        icon: Icons.payments_outlined,
                        color: AppTheme.success,
                        subtitle: todayChange != null
                            ? '${todayChange}% vs hier'
                            : null,
                      ),
                      StatCard(
                        title: 'Taux Activation',
                        value: Fmt.percent(activationRate),
                        icon: Icons.trending_up,
                        color: AppTheme.primary,
                      ),
                      StatCard(
                        title: 'Ventes ce mois',
                        value: '$monthCount',
                        icon: Icons.inventory_2_outlined,
                        color: AppTheme.warning,
                      ),
                      StatCard(
                        title: 'Sites Actifs',
                        value: '${sites.sites.length}',
                        icon: Icons.router_outlined,
                        color: AppTheme.info,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Top sites
                  if (topSitesList.isNotEmpty) ...[
                    const Text('Meilleurs Sites',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    ...topSitesList.take(5).indexed.map((entry) {
                      final (i, s) = entry;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppTheme.primary.withValues(alpha: 0.15),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                              s['site_name'] ?? s['name'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${s['count'] ?? s['sold'] ?? 0} ventes',
                              style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13)),
                          trailing: Text(
                            Fmt.currency(num.tryParse('${s['total'] ?? s['revenue'] ?? 0}') ?? 0),
                            style: const TextStyle(
                                color: AppTheme.success,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 16),

                  // Router health overview
                  if (sites.sites.isNotEmpty) ...[
                    const Text('Etat des Routeurs',
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

                  // Empty state
                  if (_error == null &&
                      sites.sites.isEmpty &&
                      topSitesList.isEmpty &&
                      todayTotal == 0 &&
                      monthCount == 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.dashboard_outlined,
                              size: 64, color: Colors.grey.shade600),
                          const SizedBox(height: 16),
                          Text('Aucune donnee pour le moment',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600)),
                          const SizedBox(height: 8),
                          Text(
                              'Ajoutez des sites et synchronisez les ventes pour voir les statistiques.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
