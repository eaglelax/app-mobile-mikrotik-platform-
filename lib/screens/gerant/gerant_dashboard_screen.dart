import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/mikhmon_service.dart';
import '../../utils/formatters.dart';

class GerantDashboardScreen extends StatefulWidget {
  const GerantDashboardScreen({super.key});

  @override
  State<GerantDashboardScreen> createState() => _GerantDashboardScreenState();
}

class _GerantDashboardScreenState extends State<GerantDashboardScreen> {
  final _mikhmon = MikhmonService();
  final _api = ApiClient();
  Map<String, dynamic>? _stats;
  List<dynamic> _recentSales = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int get _siteId =>
      context.read<AuthProvider>().user?.siteId ?? 0;

  int get _pointId =>
      context.read<AuthProvider>().user?.pointId ?? 0;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final siteId = _siteId;
      if (siteId == 0) {
        _error = 'Aucun site associe';
        setState(() => _loading = false);
        return;
      }

      final results = await Future.wait([
        _mikhmon.fetchDashboard(siteId),
        _api.get('/api/sync-sales.php', {
          'site_id': siteId.toString(),
        }),
      ]);

      _stats = results[0];

      // Filter sales by point_id
      final allSales = (results[1]['sales'] as List?) ?? [];
      if (_pointId > 0) {
        _recentSales = allSales
            .where((s) =>
                s['point_id'] != null &&
                int.tryParse(s['point_id'].toString()) == _pointId)
            .take(20)
            .toList();
      } else {
        _recentSales = allSales.take(20).toList();
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mon Point de Vente'),
            Text(user?.name ?? '',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      FilledButton(
                          onPressed: _load, child: const Text('Reessayer')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Today stats
                      Row(
                        children: [
                          _statCard(
                            'Ventes du jour',
                            Fmt.currency(
                                _stats?['today_revenue'] ?? 0),
                            AppTheme.success,
                            Icons.monetization_on,
                          ),
                          const SizedBox(width: 10),
                          _statCard(
                            'Utilisateurs actifs',
                            '${_stats?['active_users'] ?? 0}',
                            AppTheme.info,
                            Icons.people,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _statCard(
                            'Total utilisateurs',
                            '${_stats?['total_users'] ?? 0}',
                            AppTheme.primary,
                            Icons.group,
                          ),
                          const SizedBox(width: 10),
                          _statCard(
                            'Ventes du mois',
                            Fmt.currency(
                                _stats?['month_revenue'] ?? 0),
                            AppTheme.accent,
                            Icons.calendar_month,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Recent sales
                      const Text('Ventes recentes',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 10),
                      if (_recentSales.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Aucune vente recente'),
                          ),
                        )
                      else
                        ..._recentSales.map((s) => Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                dense: true,
                                title: Text(
                                  s['profile'] ?? s['profile_name'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                ),
                                subtitle: Text(
                                  s['sale_date'] ?? '',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Text(
                                  Fmt.currency(num.tryParse(
                                          '${s['price'] ?? s['amount'] ?? 0}') ??
                                      0),
                                  style: const TextStyle(
                                      color: AppTheme.success,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13),
                                ),
                              ),
                            )),
                    ],
                  ),
                ),
    );
  }

  Widget _statCard(
      String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color)),
              Text(label,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
