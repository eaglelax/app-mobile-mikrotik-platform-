import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/api_client.dart';
import '../../utils/formatters.dart';
import '../../widgets/site_selector.dart';

class SalesScreen extends StatefulWidget {
  final Site? site;
  const SalesScreen({super.key, this.site});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _api = ApiClient();
  Site? _site;
  List<Map<String, dynamic>> _allSales = [];
  List<Map<String, dynamic>> _sales = [];
  bool _loading = false;
  String _period = 'today';

  @override
  void initState() {
    super.initState();
    _site = widget.site;
    if (_site != null) _load();
  }

  Future<void> _load() async {
    if (_site == null) return;
    setState(() => _loading = true);
    try {
      final data = await _api.get('/api/sync-sales.php', {
        'site_id': _site!.id.toString(),
      });
      _allSales = (data['sales'] as List? ?? []).cast<Map<String, dynamic>>();
      _applyPeriodFilter();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _applyPeriodFilter() {
    if (_period == 'all') {
      _sales = _allSales;
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _sales = _allSales.where((s) {
      final dateStr = s['sale_date']?.toString() ?? '';
      final date = DateTime.tryParse(dateStr);
      if (date == null) return false;

      return switch (_period) {
        'today' => date.year == today.year && date.month == today.month && date.day == today.day,
        'week' => date.isAfter(today.subtract(const Duration(days: 7))),
        'month' => date.year == today.year && date.month == today.month,
        _ => true,
      };
    }).toList();
  }

  num _toNum(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;

  int get _totalRevenue {
    int total = 0;
    for (final s in _sales) {
      if (s['void'] == true || s['void'] == 1 || s['void'] == 't') continue;
      total += (_toNum(s['price']) - _toNum(s['discount'])).toInt();
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (_site == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ventes')),
        body: SiteSelector(onSelect: (s) {
          setState(() => _site = s);
          _load();
        }),
      );
    }

    return PopScope(
      canPop: widget.site != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() { _site = null; _allSales = []; _sales = []; });
      },
      child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ventes'),
            Text(_site!.nom,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // Period filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                for (final f in [
                  ('today', "Aujourd'hui"),
                  ('week', '7 jours'),
                  ('month', 'Ce mois'),
                  ('all', 'Tout'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f.$2),
                      selected: _period == f.$1,
                      onSelected: (_) {
                        setState(() {
                          _period = f.$1;
                          _applyPeriodFilter();
                        });
                      },
                      selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
          ),

          // Stats row
          if (!_loading && _sales.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('${_sales.length} ventes',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  const Spacer(),
                  Text(Fmt.currency(_totalRevenue),
                      style: const TextStyle(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ],
              ),
            ),

          const SizedBox(height: 4),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _sales.isEmpty
                    ? const Center(child: Text('Aucune vente'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _sales.length,
                        itemBuilder: (ctx, i) {
                          final s = _sales[i];
                          final isVoid = s['void'] == true || s['void'] == 1 || s['void'] == 't';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 4),
                            child: ListTile(
                              leading: Icon(Icons.receipt,
                                  color: isVoid ? Colors.grey : AppTheme.success,
                                  size: 22),
                              title: Text(s['username'] ?? s['profile_name'] ?? '',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      decoration: isVoid
                                          ? TextDecoration.lineThrough
                                          : null)),
                              subtitle: Text(
                                  '${s['profile_name'] ?? '-'}  ${s['sale_date'] ?? ''}',
                                  style: const TextStyle(fontSize: 12)),
                              trailing: Text(
                                Fmt.currency(_toNum(s['price'])),
                                style: TextStyle(
                                    color: isVoid ? Colors.grey : AppTheme.success,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
                              ),
                              dense: true,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    ),
    );
  }
}
