import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/site_provider.dart';
import '../../services/kpi_service.dart';
import '../../utils/formatters.dart';
import '../notifications/notifications_screen.dart';
import '../tickets/ticket_batches_screen.dart';
import '../flash_sale/flash_sale_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _kpiService = KpiService();
  Map<String, dynamic>? _todayRevenue;
  Map<String, dynamic>? _monthRevenue;
  Map<String, dynamic>? _topSites;
  bool _loading = true;
  String? _error;
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _loadKpis();
    // Auto-refresh every 60 seconds
    _autoRefresh = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) _loadKpis();
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
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
    if (_loading == false) {
      // Silent refresh — don't show spinner
    } else {
      setState(() => _loading = true);
    }

    final today = _today();
    final monthStart = _monthStart();
    final errors = <String>[];

    final results = await Future.wait([
      _kpiService
          .fetchRevenue(dateFrom: today, dateTo: today)
          .catchError((e) { errors.add('$e'); return <String, dynamic>{}; }),
      _kpiService
          .fetchRevenue(dateFrom: monthStart, dateTo: today)
          .catchError((e) { errors.add('$e'); return <String, dynamic>{}; }),
      _kpiService
          .fetchTopSites()
          .catchError((e) { errors.add('$e'); return <String, dynamic>{}; }),
    ]);

    if (mounted) {
      setState(() {
        _todayRevenue = results[0];
        _monthRevenue = results[1];
        _topSites = results[2];
        _error = errors.isNotEmpty ? errors.first : null;
        _loading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      context.read<SiteProvider>().fetchSites(),
      _loadKpis(),
      context.read<NotificationProvider>().refreshUnreadCount(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sites = context.watch<SiteProvider>();
    final notifs = context.watch<NotificationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final todayTotal = _todayRevenue?['total'] ?? 0;
    final todayChange = _todayRevenue?['variation_pct'];
    final monthTotal = _monthRevenue?['total'] ?? 0;
    final monthCount = _monthRevenue?['count'] ?? 0;
    final topSitesList = _topSites?['items'] as List? ?? [];

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _onRefresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  // ─── Header ───
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 21,
                            backgroundColor: AppTheme.primary,
                            child: Text(
                              (auth.user?.name ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bonjour,',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                                  ),
                                ),
                                Text(
                                  auth.user?.name ?? '',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Notification bell
                          Stack(
                            children: [
                              IconButton(
                                icon: Icon(
                                  notifs.unreadCount > 0
                                      ? Icons.notifications_active_rounded
                                      : Icons.notifications_outlined,
                                  size: 26,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const NotificationsScreen(),
                                    ),
                                  );
                                },
                              ),
                              if (notifs.unreadCount > 0)
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.danger,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                    child: Text(
                                      notifs.unreadCount > 99 ? '99+' : '${notifs.unreadCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─── Error ───
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cloud_off_rounded, color: AppTheme.danger, size: 18),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Glissez vers le bas pour actualiser',
                                style: TextStyle(fontSize: 13, color: AppTheme.danger),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // ─── Revenue Card ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Label + variation
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_rounded,
                                  color: Colors.white70, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                "Revenu du jour",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              if (todayChange != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        (todayChange as num) >= 0
                                            ? Icons.arrow_upward_rounded
                                            : Icons.arrow_downward_rounded,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${todayChange}%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Big amount
                          Text(
                            Fmt.currency(todayTotal, 'FCFA'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Bottom stats row
                          Row(
                            children: [
                              _miniStat(Icons.calendar_month_rounded, 'Mois', Fmt.currency(monthTotal)),
                              const SizedBox(width: 16),
                              _miniStat(Icons.receipt_long_rounded, 'Ventes', '$monthCount'),
                              const SizedBox(width: 16),
                              _miniStat(Icons.store_rounded, 'Sites', '${sites.sites.length}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ─── Quick Actions ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TicketBatchesScreen())),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.confirmation_number, color: Color(0xFF6366F1), size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Generer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1A1D21))),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FlashSaleScreen())),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.flash_on, color: Color(0xFFEF4444), size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Vente Flash', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1A1D21))),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── Top 5 Sites ───
                  if (topSitesList.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Top 5',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1A1D21),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(
                      topSitesList.length > 5 ? 5 : topSitesList.length,
                      (index) => _buildSiteCard(topSitesList[index], index, isDark, isTop: true),
                    ),
                  ],

                  // ─── All other sites ───
                  if (topSitesList.length > 5) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(color: isDark ? AppTheme.darkBorder : const Color(0xFFE5E7EB)),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Tous les sites',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1A1D21),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(
                      topSitesList.length - 5,
                      (i) => _buildSiteCard(topSitesList[i + 5], i + 5, isDark, isTop: false),
                    ),
                  ],

                  // ─── Empty state ───
                  if (_error == null && topSitesList.isEmpty && todayTotal == 0 && monthCount == 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Column(
                        children: [
                          Icon(Icons.bar_chart_rounded, size: 52, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Aucune donnee',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Synchronisez vos sites pour commencer.',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 30),
                ],
              ),
      ),
    );
  }

  Widget _buildSiteCard(dynamic s, int index, bool isDark, {required bool isTop}) {
    final name = s['site_name'] ?? s['name'] ?? '';
    final count = s['count'] ?? s['sold'] ?? 0;
    final total = num.tryParse('${s['total'] ?? s['revenue'] ?? 0}') ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isTop && index == 0
              ? Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 1.5)
              : null,
          boxShadow: isDark ? null : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isTop && index == 0
                    ? const Color(0xFF10B981)
                    : isTop && index == 1
                        ? const Color(0xFF3B82F6)
                        : isTop && index == 2
                            ? const Color(0xFFF59E0B)
                            : isDark
                                ? AppTheme.darkSurface
                                : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: isTop && index < 3
                  ? const Icon(Icons.emoji_events_rounded, size: 18, color: Colors.white)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            // Site info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF1A1D21),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$count ventes',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            // Amount
            Text(
              Fmt.currency(total),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isTop && index == 0 ? const Color(0xFF10B981) : AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
