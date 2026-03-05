import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/mikhmon_service.dart';

class DhcpLeasesScreen extends StatefulWidget {
  final Site site;
  const DhcpLeasesScreen({super.key, required this.site});

  @override
  State<DhcpLeasesScreen> createState() => _DhcpLeasesScreenState();
}

class _DhcpLeasesScreenState extends State<DhcpLeasesScreen> {
  final _service = MikhmonService();
  List<Map<String, dynamic>> _hosts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.fetchHosts(widget.site.id);
      _hosts = (data['hosts'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('DHCP Leases (${_hosts.length})'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _hosts.isEmpty
              ? const Center(child: Text('Aucun bail DHCP'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _hosts.length,
                  itemBuilder: (ctx, i) {
                    final h = _hosts[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        leading: const Icon(Icons.devices,
                            color: AppTheme.info, size: 22),
                        title: Text(
                            h['host-name'] ?? h['mac-address'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text(
                            'IP: ${h['address'] ?? '-'}  MAC: ${h['mac-address'] ?? '-'}',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500)),
                        dense: true,
                      ),
                    );
                  },
                ),
    );
  }
}
