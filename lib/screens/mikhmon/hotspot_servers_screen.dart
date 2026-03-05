import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/mikhmon_service.dart';

class HotspotServersScreen extends StatefulWidget {
  final Site site;
  const HotspotServersScreen({super.key, required this.site});

  @override
  State<HotspotServersScreen> createState() => _HotspotServersScreenState();
}

class _HotspotServersScreenState extends State<HotspotServersScreen> {
  final _service = MikhmonService();
  List<Map<String, dynamic>> _servers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.fetchServers(widget.site.id);
      _servers = (data['servers'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Serveurs Hotspot')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _servers.isEmpty
              ? const Center(child: Text('Aucun serveur hotspot'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _servers.length,
                  itemBuilder: (ctx, i) {
                    final s = _servers[i];
                    final disabled =
                        s['disabled'] == 'true' || s['disabled'] == true;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(Icons.dns,
                            color: disabled ? Colors.grey : AppTheme.primary),
                        title: Text(s['name'] ?? '',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            'Interface: ${s['interface'] ?? '-'}\nProfil: ${s['profile'] ?? '-'}',
                            style: const TextStyle(fontSize: 12)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (disabled ? Colors.grey : AppTheme.success)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(disabled ? 'Désactivé' : 'Actif',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: disabled
                                      ? Colors.grey
                                      : AppTheme.success,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
