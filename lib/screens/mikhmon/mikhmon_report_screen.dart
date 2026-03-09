import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/api_client.dart';
import '../../utils/formatters.dart';

class MikhmonReportScreen extends StatefulWidget {
  final Site site;
  const MikhmonReportScreen({super.key, required this.site});

  @override
  State<MikhmonReportScreen> createState() => _MikhmonReportScreenState();
}

class _MikhmonReportScreenState extends State<MikhmonReportScreen> {
  final _api = ApiClient();
  bool _loading = true;
  Map<String, dynamic>? _data;
  String _period = 'today';
  String? _error;

  final _periods = const {
    'today': "Aujourd'hui",
    '7d': '7 jours',
    '30d': '30 jours',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.get('/api/sync-sales.php', {
        'site_id': widget.site.id.toString(),
      });
      final allSales = (data['sales'] as List? ?? []).cast<Map<String, dynamic>>();
      final now = DateTime.now();
      final filtered = allSales.where((s) {
        final dateStr = s['sale_date']?.toString() ?? '';
        final date = DateTime.tryParse(dateStr);
        if (date == null) return false;
        return switch (_period) {
          'today' => date.year == now.year && date.month == now.month && date.day == now.day,
          '7d' => now.difference(date).inDays < 7,
          '30d' => now.difference(date).inDays < 30,
          _ => true,
        };
      }).toList();
      num totalRevenue = 0;
      for (final s in filtered) {
        totalRevenue += (s['price'] is num ? s['price'] as num : num.tryParse('${s['price']}') ?? 0);
      }
      _data = {
        'sales': filtered,
        'total_revenue': totalRevenue,
        'total_sales': filtered.length,
      };
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA);
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1D21);
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE8EAF0);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Custom header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: textPrimary,
                    ),
                    splashRadius: 22,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rapport Mikhmon',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.site.nom,
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : _error != null
                      ? _buildError(textSecondary)
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppTheme.primary,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            children: [
                              // ── Period filter chips ──
                              _buildPeriodChips(cardBg, borderColor, textSecondary),
                              const SizedBox(height: 20),

                              // ── Revenue summary card ──
                              _buildRevenueCard(cardBg, borderColor, isDark, textSecondary),
                              const SizedBox(height: 24),

                              // ── Sales list header ──
                              Text(
                                'Détail des ventes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // ── Sales list ──
                              if (_data?['sales'] != null)
                                ...(_data!['sales'] as List? ?? [])
                                    .take(50)
                                    .map<Widget>((s) => _buildSaleRow(
                                          s,
                                          cardBg,
                                          borderColor,
                                          isDark,
                                          textPrimary,
                                          textSecondary,
                                        )),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error state ──
  Widget _buildError(Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 32,
                color: AppTheme.danger,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Erreur: $_error',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Period filter chips ──
  Widget _buildPeriodChips(
      Color cardBg, Color borderColor, Color textSecondary) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _periods.entries.map((e) {
          final selected = e.key == _period;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _period = e.key);
                _load();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary : cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppTheme.primary : borderColor,
                    width: 1.2,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? Colors.white : textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Revenue summary card ──
  Widget _buildRevenueCard(
      Color cardBg, Color borderColor, bool isDark, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.payments_outlined,
              size: 28,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            Fmt.currency(
                _data?['total_revenue'] ?? _data?['revenue'] ?? 0),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_data?['total_sales'] ?? _data?['count'] ?? 0} ventes',
            style: TextStyle(fontSize: 14, color: textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Single sale row ──
  Widget _buildSaleRow(
    Map<String, dynamic> s,
    Color cardBg,
    Color borderColor,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isVoid = s['void'] == true || s['void'] == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isVoid
                  ? Colors.grey.withValues(alpha: 0.1)
                  : AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isVoid ? Icons.cancel : Icons.receipt,
              color: isVoid ? Colors.grey : AppTheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s['profile_name'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isVoid ? Colors.grey : textPrimary,
                    decoration:
                        isVoid ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s['sale_date'] ?? '',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          Text(
            Fmt.currency(s['price'] ?? 0),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: isVoid ? Colors.grey : AppTheme.success,
            ),
          ),
        ],
      ),
    );
  }
}
