import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/tunnel_service.dart';

class TunnelsScreen extends StatefulWidget {
  const TunnelsScreen({super.key});

  @override
  State<TunnelsScreen> createState() => _TunnelsScreenState();
}

class _TunnelsScreenState extends State<TunnelsScreen> {
  final _service = TunnelService();
  List<Map<String, dynamic>> _tunnels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.fetchAll();
      _tunnels =
          (data['peers'] ?? data['tunnels'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tunnels VPN'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tunnels.isEmpty
              ? const Center(child: Text('Aucun tunnel VPN'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _tunnels.length,
                    itemBuilder: (ctx, i) {
                      final t = _tunnels[i];
                      final status = t['status'] ?? 'unknown';
                      final isActive = status == 'active';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            Icons.vpn_key,
                            color: isActive ? AppTheme.success : Colors.grey,
                          ),
                          title: Text(
                              t['tunnel_label'] ?? t['tunnel_name'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (t['vpn_ip'] != null)
                                Text('IP: ${t['vpn_ip']}',
                                    style: const TextStyle(fontSize: 12)),
                              if (t['site_name'] != null)
                                Text('Site: ${t['site_name']}',
                                    style: const TextStyle(fontSize: 12)),
                              if (t['forwarded_api_port'] != null)
                                Text(
                                    'Ports: API=${t['forwarded_api_port']} WinBox=${t['forwarded_winbox_port'] ?? '-'}',
                                    style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isActive
                                      ? AppTheme.success
                                      : Colors.grey)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isActive ? 'Actif' : status,
                              style: TextStyle(
                                  color: isActive
                                      ? AppTheme.success
                                      : Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
