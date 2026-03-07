import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/tunnel_service.dart';
import 'tunnel_form_screen.dart';

class TunnelsScreen extends StatefulWidget {
  const TunnelsScreen({super.key});

  @override
  State<TunnelsScreen> createState() => _TunnelsScreenState();
}

class _TunnelsScreenState extends State<TunnelsScreen> {
  final _service = TunnelService();
  List<Map<String, dynamic>> _tunnels = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _deleteTunnel(Map<String, dynamic> t) async {
    final name = t['tunnel_label'] ?? t['tunnel_name'] ?? 'ce tunnel';
    final tunnelId = t['id'] ?? t['tunnel_id'];
    if (tunnelId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le tunnel'),
        content: Text('Supprimer "$name" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final result = await _service.delete(int.parse(tunnelId.toString()));
      if (result['success'] == true) {
        _load();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Erreur'), backgroundColor: AppTheme.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.fetchAll();
      if (data['success'] == false) {
        _error = data['error']?.toString() ?? 'Erreur inconnue';
        _tunnels = [];
      } else {
        final peers = data['peers'] ?? data['tunnels'];
        _tunnels = (peers is List ? peers : []).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      _error = e.toString();
      _tunnels = [];
    }
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const TunnelFormScreen()),
          );
          if (created == true) _load();
        },
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500)),
                ))
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
                          onLongPress: () => _deleteTunnel(t),
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
