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
  List<Map<String, dynamic>> _sales = [];
  bool _loading = false;

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
      _sales = (data['sales'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ventes'),
            Text(_site!.nom,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sales.isEmpty
              ? const Center(child: Text('Aucune vente'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _sales.length,
                  itemBuilder: (ctx, i) {
                    final s = _sales[i];
                    final isVoid = s['void'] == true || s['void'] == 1;
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
                          Fmt.currency(s['price'] ?? 0),
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
    );
  }
}
