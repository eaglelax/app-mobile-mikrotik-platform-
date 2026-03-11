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
  String? _error;
  String _period = 'today';

  // Data
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _byProfile = [];
  List<Map<String, dynamic>> _byPoint = [];
  List<Map<String, dynamic>> _sales = [];

  final _periods = const {
    'today': "Aujourd'hui",
    'week': 'Semaine',
    'month': 'Ce mois',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.get('/api/report-sales.php', {
        'site_id': widget.site.id.toString(),
        'period': _period,
      });
      if (data['success'] == true) {
        _summary = (data['summary'] as Map<String, dynamic>?) ?? {};
        _byProfile = (data['by_profile'] as List? ?? []).cast<Map<String, dynamic>>();
        _byPoint = (data['by_point'] as List? ?? []).cast<Map<String, dynamic>>();
        _sales = (data['sales'] as List? ?? []).cast<Map<String, dynamic>>();
      } else {
        _error = data['error']?.toString() ?? 'Erreur inconnue';
      }
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

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: textPrimary),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rapport', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
                        Text(widget.site.nom, style: TextStyle(fontSize: 13, color: textSecondary)),
                      ],
                    ),
                  ),
                  if (_loading)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    GestureDetector(
                      onTap: _load,
                      child: Icon(Icons.refresh, size: 22, color: textSecondary),
                    ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _loading && _sales.isEmpty
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _error != null
                      ? _buildError(textSecondary)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            children: [
                              // Period chips
                              _buildPeriodChips(cardBg, isDark, textSecondary),
                              const SizedBox(height: 16),

                              // Summary cards
                              _buildSummaryRow(cardBg, isDark),
                              const SizedBox(height: 20),

                              // By Profile
                              if (_byProfile.isNotEmpty) ...[
                                _sectionTitle('Repartition par profil', textPrimary),
                                const SizedBox(height: 10),
                                ..._byProfile.map((p) => _buildProfileCard(p, cardBg, isDark, textPrimary, textSecondary)),
                                const SizedBox(height: 20),
                              ],

                              // By Point de vente
                              if (_byPoint.isNotEmpty) ...[
                                _sectionTitle('Par point de vente', textPrimary),
                                const SizedBox(height: 10),
                                ..._byPoint.map((p) => _buildPointCard(p, cardBg, isDark, textPrimary, textSecondary)),
                                const SizedBox(height: 20),
                              ],

                              // Sales list
                              _sectionTitle('Detail des ventes (${_sales.length})', textPrimary),
                              const SizedBox(height: 10),
                              if (_sales.isEmpty)
                                _buildEmpty(textSecondary)
                              else
                                ..._sales.take(100).map((s) => _buildSaleRow(s, cardBg, isDark, textPrimary, textSecondary)),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, Color color) {
    return Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color));
  }

  // ── Period chips ──
  Widget _buildPeriodChips(Color cardBg, bool isDark, Color textSecondary) {
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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary : cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppTheme.primary : (isDark ? AppTheme.darkBorder : const Color(0xFFE8EAF0)),
                    width: 1.2,
                  ),
                  boxShadow: selected ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))] : null,
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

  // ── Summary cards ──
  Widget _buildSummaryRow(Color cardBg, bool isDark) {
    final revenue = _summary['total_revenue'] ?? 0;
    final count = _summary['total_sales'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.payments_outlined, color: AppTheme.success, size: 20),
                ),
                const SizedBox(height: 10),
                Text(Fmt.currency(revenue), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.success)),
                const SizedBox(height: 2),
                Text('Revenu total', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.receipt_long, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(height: 10),
                Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1A1D21))),
                const SizedBox(height: 2),
                Text('Ventes', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Profile card ──
  Widget _buildProfileCard(Map<String, dynamic> p, Color cardBg, bool isDark, Color textPrimary, Color textSecondary) {
    final total = _summary['total_revenue'] ?? 1;
    final profileTotal = (p['total'] is num ? (p['total'] as num).toDouble() : 0.0);
    final pct = total > 0 ? (profileTotal / total * 100) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(p['profile'] ?? '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p['count'] ?? 0} ventes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    color: AppTheme.primary,
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.currency(profileTotal), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
              Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, color: textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Point de vente card ──
  Widget _buildPointCard(Map<String, dynamic> p, Color cardBg, bool isDark, Color textPrimary, Color textSecondary) {
    final pointName = p['point_name'] ?? 'Non assigne';
    final count = p['count'] ?? 0;
    final total = (p['total'] is num ? (p['total'] as num).toDouble() : 0.0);
    final profiles = (p['profiles'] as List? ?? []).cast<Map<String, dynamic>>();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: AppTheme.accent, width: 3)),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.store, color: AppTheme.accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pointName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
                    Text('$count vente${count > 1 ? 's' : ''}', style: TextStyle(fontSize: 12, color: textSecondary)),
                  ],
                ),
              ),
              Text(Fmt.currency(total), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.success)),
            ],
          ),

          // Profile breakdown
          if (profiles.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            const SizedBox(height: 8),
            ...profiles.map((pr) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    Icon(Icons.circle, size: 6, color: AppTheme.primary.withValues(alpha: 0.5)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(pr['profile'] ?? '-', style: TextStyle(fontSize: 12, color: textSecondary))),
                    Text('x${pr['count'] ?? 0}', style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 12),
                    Text(Fmt.currency(pr['total'] ?? 0), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ── Sale row ──
  Widget _buildSaleRow(Map<String, dynamic> s, Color cardBg, bool isDark, Color textPrimary, Color textSecondary) {
    final isVoid = s['void'] == true || s['void'] == 1;
    final profile = s['profile_name'] ?? s['profile'] ?? '';
    final pointName = s['point_name'];
    final price = s['price'] is num ? s['price'] : (num.tryParse('${s['price']}') ?? 0);
    final date = s['date_fmt'] ?? s['sale_date'] ?? '';
    final time = s['sale_time'] ?? '';
    final username = s['username'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isVoid ? Colors.grey.withValues(alpha: 0.1) : AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14,
                  color: isVoid ? Colors.grey : AppTheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.isNotEmpty ? profile : username,
                  style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13,
                    color: isVoid ? Colors.grey : textPrimary,
                    decoration: isVoid ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('$date${time.isNotEmpty ? ' $time' : ''}', style: TextStyle(fontSize: 11, color: textSecondary)),
                    if (pointName != null) ...[
                      Text(' · ', style: TextStyle(fontSize: 11, color: textSecondary)),
                      Flexible(child: Text(pointName.toString(), style: TextStyle(fontSize: 11, color: AppTheme.accent), overflow: TextOverflow.ellipsis)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            Fmt.currency(price),
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isVoid ? Colors.grey : AppTheme.success),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Aucune vente pour cette periode', style: TextStyle(fontSize: 14, color: textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline, size: 32, color: AppTheme.danger),
            ),
            const SizedBox(height: 16),
            Text('Erreur: $_error', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: textSecondary)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
