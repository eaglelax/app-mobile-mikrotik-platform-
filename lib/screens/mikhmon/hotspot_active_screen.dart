import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/mikhmon_service.dart';
import '../../utils/formatters.dart';

class HotspotActiveScreen extends StatefulWidget {
  final Site site;
  const HotspotActiveScreen({super.key, required this.site});

  @override
  State<HotspotActiveScreen> createState() => _HotspotActiveScreenState();
}

class _HotspotActiveScreenState extends State<HotspotActiveScreen> {
  final _service = MikhmonService();
  List<Map<String, dynamic>> _active = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.fetchActiveUsers(widget.site.id);
      _active = (data['active'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Connexions Actives (${_active.length})'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _active.isEmpty
              ? const Center(child: Text('Aucune connexion active'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _active.length,
                    itemBuilder: (ctx, i) {
                      final a = _active[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.wifi_tethering,
                                color: AppTheme.success, size: 20),
                          ),
                          title: Text(a['user'] ?? a['name'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                              'IP: ${a['address'] ?? '-'}  Uptime: ${a['uptime'] ?? '-'}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500)),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (a['bytes-in'] != null)
                                Text(
                                    '↓ ${Fmt.bytes(int.tryParse(a['bytes-in'].toString()) ?? 0)}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.primary)),
                              if (a['bytes-out'] != null)
                                Text(
                                    '↑ ${Fmt.bytes(int.tryParse(a['bytes-out'].toString()) ?? 0)}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.accent)),
                            ],
                          ),
                          dense: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
