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
        _error = 'Aucun site associé';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().user;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // Custom header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bonjour, ${user?.name ?? 'Gérant'}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Mon Point de Vente',
                          style: TextStyle(fontSize: 13, color: subColor),
                        ),
                      ],
                    ),
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      onPressed: _load,
                      icon: Icon(Icons.refresh, color: subColor),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Content
            Expanded(
              child: _error != null && _stats == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: subColor)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Réessayer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Revenue hero card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.monetization_on, color: Colors.white, size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      "Ventes du jour",
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  Fmt.currency(_stats?['today_revenue'] ?? 0),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Mini stats row
                                Row(
                                  children: [
                                    _heroMiniStat('Actifs', '${_stats?['active_users'] ?? 0}', Icons.people),
                                    const SizedBox(width: 16),
                                    _heroMiniStat('Total', '${_stats?['total_users'] ?? 0}', Icons.group),
                                    const SizedBox(width: 16),
                                    _heroMiniStat('Mois', Fmt.currency(_stats?['month_revenue'] ?? 0), Icons.calendar_month),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Recent sales header
                          Row(
                            children: [
                              Text(
                                'Ventes récentes',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: textColor,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_recentSales.length} ventes',
                                style: TextStyle(fontSize: 12, color: subColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          if (_recentSales.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_long, size: 40, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text('Aucune vente récente', style: TextStyle(color: subColor)),
                                ],
                              ),
                            )
                          else
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: _recentSales.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final s = entry.value;
                                  final isLast = i == _recentSales.length - 1;
                                  return Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: AppTheme.success.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Icon(Icons.receipt, size: 18, color: AppTheme.success),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    s['profile'] ?? s['profile_name'] ?? '',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 14,
                                                      color: textColor,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    s['sale_date'] ?? '',
                                                    style: TextStyle(fontSize: 12, color: subColor),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              Fmt.currency(num.tryParse(
                                                      '${s['price'] ?? s['amount'] ?? 0}') ??
                                                  0),
                                              style: const TextStyle(
                                                color: AppTheme.success,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isLast)
                                        Divider(
                                          height: 1,
                                          indent: 64,
                                          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                                        ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroMiniStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
