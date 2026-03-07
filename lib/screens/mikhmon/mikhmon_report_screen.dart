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
    setState(() => _loading = true);
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
            const Text('Rapport Mikhmon'),
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

                  // Revenue summary
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.payments_outlined,
                              size: 40, color: AppTheme.success),
                          const SizedBox(height: 8),
                          Text(
                            Fmt.currency(_data?['total_revenue'] ??
                                _data?['revenue'] ??
                                0),
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${_data?['total_sales'] ?? _data?['count'] ?? 0} ventes',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sales list
                  const Text('Détail des ventes',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),

                  if (_data?['sales'] != null)
                    ...(_data!['sales'] as List? ?? [])
                        .take(50)
                        .map<Widget>((s) {
                      final isVoid = s['void'] == true || s['void'] == 1;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          leading: Icon(
                            isVoid ? Icons.cancel : Icons.receipt,
                            color: isVoid ? Colors.grey : AppTheme.primary,
                            size: 20,
                          ),
                          title: Text(s['profile_name'] ?? '',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  decoration: isVoid
                                      ? TextDecoration.lineThrough
                                      : null)),
                          subtitle: Text(s['sale_date'] ?? '',
                              style: const TextStyle(fontSize: 12)),
                          trailing: Text(
                            Fmt.currency(s['price'] ?? 0),
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isVoid ? Colors.grey : AppTheme.success),
                          ),
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
